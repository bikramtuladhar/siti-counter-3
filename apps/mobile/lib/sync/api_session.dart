import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'sync_repository.dart';

/// Default API origin for local development.
///
/// iOS simulators and the Android emulator reach the host differently: the emulator maps
/// the host loopback to 10.0.2.2. Override with
/// `--dart-define=API_BASE_URL=http://<host>:<port>` when targeting a real device.
const String kDefaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8787',
);

/// Resolves the API origin for the current platform.
///
/// Not const because it branches on the platform: the Android emulator reaches the host
/// loopback at 10.0.2.2, while the iOS simulator uses 127.0.0.1.
String defaultApiBaseUrl() {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;
  if (Platform.isAndroid) return 'http://10.0.2.2:8787';
  return 'http://127.0.0.1:8787';
}

/// Performs an HTTP POST against the API.
///
/// Injectable because the whole point of this class is distinguishing three outcomes —
/// success, rejected credentials, and an unreachable server — and that cannot be tested
/// through Flutter's `HttpClient`, which answers every request with a 400 during `flutter
/// test`. Tests that could only produce "rejected" would have made the offline path
/// untestable, which is how the original bug survived.
typedef ApiTransport = Future<ApiPostResult> Function(
  String baseUrl,
  String path,
  Map<String, dynamic> body,
);

/// The outcome of one HTTP POST.
class ApiPostResult {
  /// HTTP status code, or null when the request never got a response.
  final int? statusCode;

  /// Decoded body, when there was one.
  final Map<String, dynamic>? body;

  const ApiPostResult(this.statusCode, [this.body]);

  bool get isOk => statusCode != null && statusCode! < 400;

  /// The server answered and rejected the request: 4xx, except rate limiting.
  ///
  /// 5xx is deliberately excluded. A server having a bad day must not look like a user's
  /// credentials being revoked, or an outage signs everyone out.
  bool get isUnauthorized {
    final code = statusCode;
    return code != null && code >= 400 && code < 500 && code != 429;
  }

  /// No usable response: offline, DNS failure, timeout, server error, or rate limited.
  bool get isUnavailable => !isOk && !isUnauthorized;
}


enum ApiSessionState {
  /// [ApiSession.restore] has not run yet.
  unknown,

  /// A live access token is held.
  authenticated,

  /// Credentials exist on disk but could not be verified because the API was unreachable.
  ///
  /// The household is kept and no guest session is minted. This is the state that stops an
  /// offline launch from silently replacing a real account with a new empty household.
  offline,

  /// A guest household, minted because no real credentials exist.
  guest,

  /// No usable credentials.
  unauthenticated,
}

/// Holds the API session (access token + household) and keeps it persisted across launches.
///
/// Guest auth is used until a real account exists: `POST /v1/auth/guest` mints a household
/// and a token scoped to exactly that household, which is what the sync and display feed
/// endpoints authorize against. The refresh token is stored so a relaunch can silently
/// renew rather than orphaning the previous household's cached data.
class ApiSession {
  final SyncRepository repository;
  final String apiBaseUrl;

  String? _accessToken;
  String? _refreshToken;
  String? _householdId;

  /// When the access token stops being usable, as epoch milliseconds.
  ///
  /// The API has always sent `expiresIn` and the client never read it, so `isAuthenticated`
  /// only checked that a token was non-empty. A token from yesterday satisfied that. It is
  /// tracked now so `restore` can actually renew what its documentation always claimed to.
  int? _accessExpiresAtMs;

  final DateTime Function() _clock;
  final ApiTransport _transport;

  /// Renew slightly before the real deadline so a request is not issued with a token that
  /// expires in flight.
  static const Duration _refreshMargin = Duration(seconds: 60);

  ApiSessionState _state = ApiSessionState.unknown;

  /// What the app currently believes about its credentials.
  ApiSessionState get state => _state;

  /// True when credentials exist on disk but the API could not be reached.
  ///
  /// The app is running from local cache in this state and should say so, rather than
  /// presenting an empty household as though that were the real state.
  bool get isOffline => _state == ApiSessionState.offline;

  /// The household from the last successful session, valid in every state.
  ///
  /// Kept even when offline so cached household-scoped data stays addressable.
  String? get cachedHouseholdId => _householdId;

  ApiSession({
    required this.repository,
    String? apiBaseUrl,
    DateTime Function()? clock,
    ApiTransport? transport,
  }) : apiBaseUrl = apiBaseUrl ?? defaultApiBaseUrl(),
       _clock = clock ?? DateTime.now,
       _transport = transport ?? httpTransport;

  String? get accessToken => _accessToken;
  String? get householdId => _householdId;
  /// Whether the stored access token is present and still within its lifetime.
  ///
  /// A token with no recorded expiry counts as expired. Tokens issued before this was tracked
  /// have no expiry stored, and treating them as valid would let exactly the staleness this
  /// fixes persist through an upgrade. The first restore after updating therefore renews, or
  /// falls into the offline state, which is the safe direction.
  bool get isAuthenticated {
    final token = _accessToken;
    if (token == null || token.isEmpty) return false;
    return !isAccessTokenExpired;
  }

  bool get isAccessTokenExpired {
    final expiry = _accessExpiresAtMs;
    if (expiry == null) return true;
    return _clock().millisecondsSinceEpoch >= expiry - _refreshMargin.inMilliseconds;
  }

  /// Supply this to `SyncEngine` / `CompanionWidgetService` so they authorize requests.
  String? Function() get accessTokenProvider => () => _accessToken;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kHouseholdId = 'session_household_id';
  static const _kDeviceId = 'device_id';
  static const _kAccessExpiresAt = 'access_expires_at';

  /// Stable per-install device id, so repeat guest auth calls return the same household.
  ///
  /// Overridable with `--dart-define=DEVICE_ID=...` so a local dev build can share a
  /// household with a seeded demo dataset.
  Future<String> _deviceId() async {
    const override = String.fromEnvironment('DEVICE_ID');
    if (override.isNotEmpty) return override;

    final stored = await repository.getSyncState(_kDeviceId);
    if (stored != null && stored.isNotEmpty) return stored;

    final random = Random.secure();
    final generated = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    await repository.setSyncState(_kDeviceId, generated);
    return generated;
  }

  /// Restores a persisted session, renewing it if the access token has expired.
  ///
  /// Returns true when a usable access token is available afterwards. Never throws: a
  /// network failure simply leaves the app unauthenticated and running from cache.
  bool _loaded = false;

  /// Reads persisted credentials into memory, once.
  ///
  /// Split out of [restore] so [ensureFresh] is safe to call on a fresh object: it is a
  /// before-sync API, and making it silently return false because nobody had restored yet
  /// would be a trap.
  Future<void> _loadOnce() async {
    if (_loaded) return;
    _loaded = true;
    _accessToken = await repository.getSyncState(_kAccessToken);
    _refreshToken = await repository.getSyncState(_kRefreshToken);
    _householdId = await repository.getSyncState(_kHouseholdId);
    final expiry = await repository.getSyncState(_kAccessExpiresAt);
    _accessExpiresAtMs = expiry == null ? null : int.tryParse(expiry);
  }

  Future<bool> restore() async {
    await _loadOnce();

    if (isAuthenticated && _householdId != null) {
      _state = ApiSessionState.authenticated;
      return true;
    }

    if (_refreshToken != null) {
      final result = await _refresh();
      if (result == _AuthOutcome.ok) {
        _state = ApiSessionState.authenticated;
        return true;
      }

      if (result == _AuthOutcome.unavailable) {
        // The API could not be reached. Keep the household and the refresh token untouched
        // and run from cache.
        //
        // This used to fall through to authenticateAsGuest(), which minted a brand new
        // household and overwrote the stored one. Opening the app on a train was therefore
        // enough to orphan a real account permanently: the refresh token was replaced, so
        // there was no way back into it even once back online.
        _state = _householdId != null
            ? ApiSessionState.offline
            : ApiSessionState.unauthenticated;
        return _state == ApiSessionState.offline;
      }

      // unauthorized: the refresh token is genuinely dead, so the stored session is finished
      // and a guest household is the correct outcome.
      await clear();
    }

    return authenticateAsGuest();
  }

  /// Renews the access token if it has expired or is about to.
  ///
  /// Safe to call before a sync pass so an expired token is not used to authorise a request
  /// that will come back 401. Returns true when a usable token is held afterwards.
  Future<bool> ensureFresh() async {
    await _loadOnce();
    if (isAuthenticated && _householdId != null) return true;
    if (_refreshToken == null) return isAuthenticated;

    final outcome = await _refresh();
    if (outcome == _AuthOutcome.ok) {
      _state = ApiSessionState.authenticated;
      return true;
    }
    if (outcome == _AuthOutcome.unavailable) {
      if (_state != ApiSessionState.offline && _householdId != null) {
        _state = ApiSessionState.offline;
      }
      return false;
    }

    // Rejected: the refresh token is finished.
    await clear();
    return authenticateAsGuest();
  }

  /// Mints (or re-mints) a guest session for this install.
  ///
  /// Only correct when no real credentials exist. Calling this while a stored refresh token
  /// merely could not be verified destroys the account it belongs to.
  Future<bool> authenticateAsGuest() async {
    final result = await _post('/v1/auth/guest', {'deviceId': await _deviceId()});
    if (result.outcome != _AuthOutcome.ok || result.body == null) {
      _state = ApiSessionState.unauthenticated;
      return false;
    }
    final absorbed = _absorbAuthResponse(result.body!);
    _state = absorbed ? ApiSessionState.guest : ApiSessionState.unauthenticated;
    return absorbed;
  }

  /// Exchanges the refresh token for a new access token.
  ///
  /// Returns the outcome rather than a bool, because the caller must be able to tell a dead
  /// token from an unreachable server.
  Future<_AuthOutcome> _refresh() async {
    final result = await _post('/v1/auth/refresh', {'refreshToken': _refreshToken});
    if (result.outcome != _AuthOutcome.ok || result.body == null) return result.outcome;
    return _absorbAuthResponse(result.body!) ? _AuthOutcome.ok : _AuthOutcome.unauthorized;
  }

  bool _absorbAuthResponse(Map<String, dynamic> body) {
    final tokens = body['tokens'];
    final user = body['user'];
    if (tokens is! Map || user is! Map) return false;

    final access = tokens['accessToken'];
    final refresh = tokens['refreshToken'];
    final household = user['householdId'];
    final expiresIn = tokens['expiresIn'];
    if (access is! String || household is! String) return false;

    _accessToken = access;
    _refreshToken = refresh is String ? refresh : _refreshToken;
    _householdId = household;
    // Recorded when the server provides it. If it does not, the token is treated as expired so
    // the next call renews rather than trusting an unbounded lifetime.
    _accessExpiresAtMs = expiresIn is num
        ? _clock().add(Duration(seconds: expiresIn.toInt())).millisecondsSinceEpoch
        : null;

    // Fire-and-forget persistence: the in-memory session is already valid, and a failed
    // write only costs a re-auth next launch.
    unawaitedPersist();
    return true;
  }

  void unawaitedPersist() {
    repository.setSyncState(_kAccessToken, _accessToken!).catchError((_) {});
    if (_refreshToken != null) {
      repository.setSyncState(_kRefreshToken, _refreshToken!).catchError((_) {});
    }
    repository.setSyncState(_kHouseholdId, _householdId!).catchError((_) {});
    // An unknown expiry is persisted as empty, which reads back as expired.
    repository
        .setSyncState(_kAccessExpiresAt, _accessExpiresAtMs?.toString() ?? '')
        .catchError((_) {});
  }

  /// Clears the stored session, e.g. on sign-out.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _householdId = null;
    _accessExpiresAtMs = null;
    _loaded = true;
    _state = ApiSessionState.unauthenticated;
    await repository.setSyncState(_kAccessToken, '');
    await repository.setSyncState(_kRefreshToken, '');
    await repository.setSyncState(_kHouseholdId, '');
    await repository.setSyncState(_kAccessExpiresAt, '');
  }

  /// POSTs JSON through the injected transport.
  ///
  /// Collapsing "the server said no" and "we could not reach the server" into one result is
  /// what allowed an offline launch to be treated as a rejected token. The distinction is the
  /// whole point: one is permanent and warrants clearing credentials, the other is transient
  /// and must not.
  Future<_PostResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final result = await _transport(apiBaseUrl, path, body);
      if (result.isOk) {
        return _PostResult(_AuthOutcome.ok, result.body);
      }
      return _PostResult(
        result.isUnauthorized ? _AuthOutcome.unauthorized : _AuthOutcome.unavailable,
      );
    } catch (_) {
      return const _PostResult(_AuthOutcome.unavailable);
    }
  }

  /// Default transport, using `dart:io`.
  static Future<ApiPostResult> httpTransport(
    String baseUrl,
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl$path'));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(body));

      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      final status = response.statusCode;
      if (status >= 400) return ApiPostResult(status);
      return ApiPostResult(status, jsonDecode(text) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }
}

/// Why an auth call ended the way it did.
enum _AuthOutcome {
  /// The call succeeded.
  ok,

  /// The server rejected the credentials. Permanent: the stored session is finished.
  unauthorized,

  /// The server could not be reached, or is unwell. Transient: keep the stored session.
  unavailable,
}

/// Result of an HTTP POST, carrying the outcome rather than only a body.
class _PostResult {
  final _AuthOutcome outcome;
  final Map<String, dynamic>? body;

  const _PostResult(this.outcome, [this.body]);
}
