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

  ApiSession({required this.repository, String? apiBaseUrl})
    : apiBaseUrl = apiBaseUrl ?? defaultApiBaseUrl();

  String? get accessToken => _accessToken;
  String? get householdId => _householdId;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  /// Supply this to `SyncEngine` / `CompanionWidgetService` so they authorize requests.
  String? Function() get accessTokenProvider => () => _accessToken;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kHouseholdId = 'session_household_id';
  static const _kDeviceId = 'device_id';

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
  Future<bool> restore() async {
    _accessToken = await repository.getSyncState(_kAccessToken);
    _refreshToken = await repository.getSyncState(_kRefreshToken);
    _householdId = await repository.getSyncState(_kHouseholdId);

    if (isAuthenticated && _householdId != null) return true;

    // No usable access token: try to renew, otherwise mint a guest session.
    if (_refreshToken != null && await _refresh()) return true;
    return authenticateAsGuest();
  }

  /// Mints (or re-mints) a guest session for this install.
  Future<bool> authenticateAsGuest() async {
    try {
      final response = await _post('/v1/auth/guest', {'deviceId': await _deviceId()});
      if (response == null) return false;
      return _absorbAuthResponse(response);
    } catch (_) {
      return false;
    }
  }

  /// Exchanges the refresh token for a new access token.
  Future<bool> _refresh() async {
    try {
      final response = await _post('/v1/auth/refresh', {
        'refreshToken': _refreshToken,
      });
      if (response == null) return false;
      return _absorbAuthResponse(response);
    } catch (_) {
      return false;
    }
  }

  bool _absorbAuthResponse(Map<String, dynamic> body) {
    final tokens = body['tokens'];
    final user = body['user'];
    if (tokens is! Map || user is! Map) return false;

    final access = tokens['accessToken'];
    final refresh = tokens['refreshToken'];
    final household = user['householdId'];
    if (access is! String || household is! String) return false;

    _accessToken = access;
    _refreshToken = refresh is String ? refresh : _refreshToken;
    _householdId = household;

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
  }

  /// Clears the stored session, e.g. on sign-out.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _householdId = null;
    await repository.setSyncState(_kAccessToken, '');
    await repository.setSyncState(_kRefreshToken, '');
    await repository.setSyncState(_kHouseholdId, '');
  }

  /// POSTs JSON and returns the decoded body, or null on any transport/HTTP failure.
  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$apiBaseUrl$path'));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(body));

      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}