import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/sync/api_session.dart';
import 'package:siti_counter/sync/sync_repository.dart';

/// Stands in for [SyncRepository] with an in-memory key/value map.
class _FakeRepo implements SyncRepository {
  final Map<String, String> state = {};

  @override
  Future<String?> getSyncState(String key) async => state[key];

  @override
  Future<void> setSyncState(String key, String value) async {
    if (value.isEmpty) {
      state.remove(key);
    } else {
      state[key] = value;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// Scripts the API responses, including the transport failure that no status code can express.
class _FakeApi {
  _FakeApi({required this.mode, this.offline = false});

  /// 'ok' | 'unauthorized' | 'server-error' | 'throttled' | 'offline'
  String mode;

  /// Paths to answer with 401 while leaving others healthy.
  ///
  /// Scoped because the realistic case is a rejected refresh token while guest auth still
  /// works. A server that 401s everything cannot mint a guest household either, which is a
  /// different situation and correctly ends unauthenticated.
  Set<String> rejectPaths = const {};

  /// Throws instead of answering, standing in for no connectivity.
  final bool offline;

  final List<String> paths = [];

  Map<String, dynamic> _body(String path) {
    if (path == '/v1/auth/refresh') {
      return {
        'tokens': {
          'accessToken': 'fresh-access',
          'refreshToken': 'fresh-refresh',
          'expiresIn': 900,
        },
        'user': {'householdId': 'hh-real'},
      };
    }
    return {
      'tokens': {
        'accessToken': 'guest-access',
        'refreshToken': 'guest-refresh',
        'expiresIn': 900,
      },
      'user': {'householdId': 'hh-guest'},
    };
  }

  Future<ApiPostResult> call(
    String baseUrl,
    String path,
    Map<String, dynamic> body,
  ) async {
    paths.add(path);
    if (offline) throw Exception('network unreachable');
    if (rejectPaths.contains(path)) return const ApiPostResult(401);
    switch (mode) {
      case 'unauthorized':
        return const ApiPostResult(401);
      case 'server-error':
        return const ApiPostResult(503);
      case 'throttled':
        return const ApiPostResult(429);
      default:
        return ApiPostResult(200, _body(path));
    }
  }
}

void main() {
  late DateTime now;

  setUp(() => now = DateTime.utc(2026, 10, 6, 12));

  ApiSession sessionWith(_FakeRepo repo, _FakeApi api) => ApiSession(
    repository: repo,
    apiBaseUrl: 'https://api.test',
    clock: () => now,
    transport: api.call,
  );

  /// A real account whose access token has expired and whose refresh token is still good,
  /// which is what a launch more than fifteen minutes after the last one looks like.
  _FakeRepo signedIn() {
    final r = _FakeRepo();
    r.state['access_token'] = 'stale-access';
    r.state['access_expires_at'] =
        now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch.toString();
    r.state['refresh_token'] = 'real-refresh';
    r.state['session_household_id'] = 'hh-real';
    return r;
  }

  group('token expiry is actually tracked', () {
    test('a token inside its lifetime is accepted', () async {
      final repo = _FakeRepo();
      repo.state['access_token'] = 'good-access';
      repo.state['access_expires_at'] =
          now.add(const Duration(minutes: 10)).millisecondsSinceEpoch.toString();
      repo.state['session_household_id'] = 'hh-real';
      final api = _FakeApi(mode: 'ok');

      final s = sessionWith(repo, api);

      expect(await s.restore(), isTrue);
      expect(s.state, ApiSessionState.authenticated);
      // The API sends expiresIn: 900 and the client used to ignore it, so an expired token
      // looked valid and no refresh ever happened.
      expect(api.paths, isEmpty);
    });

    test('a token inside the renewal margin counts as expired', () async {
      final repo = _FakeRepo();
      repo.state['access_token'] = 'almost-expired';
      repo.state['access_expires_at'] =
          now.add(const Duration(seconds: 30)).millisecondsSinceEpoch.toString();
      repo.state['session_household_id'] = 'hh-real';
      repo.state['refresh_token'] = 'real-refresh';
      final api = _FakeApi(mode: 'ok');

      final s = sessionWith(repo, api);
      expect(s.isAuthenticated, isFalse);
      await s.restore();
      expect(api.paths, contains('/v1/auth/refresh'));
      expect(s.state, ApiSessionState.authenticated);
    });

    test('a token with no recorded expiry is treated as expired', () async {
      final repo = _FakeRepo();
      repo.state['access_token'] = 'legacy-access';
      repo.state['refresh_token'] = 'real-refresh';
      repo.state['session_household_id'] = 'hh-real';
      final api = _FakeApi(mode: 'ok');

      final s = sessionWith(repo, api);
      expect(s.isAuthenticated, isFalse);
      expect(await s.restore(), isTrue);
      expect(s.state, ApiSessionState.authenticated);
    });

    test('the expiry from a refresh is persisted for the next launch', () async {
      final repo = signedIn();
      final api = _FakeApi(mode: 'ok');
      final s = sessionWith(repo, api);

      await s.restore();

      expect(api.paths, contains('/v1/auth/refresh'));
      expect(s.accessToken, 'fresh-access');
      // Persisted, so the next launch knows the token's lifetime without asking.
      await tester0Pump();
      expect(
        repo.state['access_expires_at'],
        now.add(const Duration(seconds: 900)).millisecondsSinceEpoch.toString(),
      );
    });
  });

  group('offline no longer destroys the account', () {
    test('an unreachable API keeps the household and the refresh token', () async {
      final repo = signedIn();
      final api = _FakeApi(mode: 'ok', offline: true);
      final s = sessionWith(repo, api);

      await s.restore();

      // The bug: this fell through to authenticateAsGuest(), replacing the real household with
      // a new empty one and overwriting the refresh token. Opening the app on a train was
      // enough to orphan the account permanently, because the token needed to get back was
      // the one that got overwritten.
      expect(api.paths, isNot(contains('/v1/auth/guest')));
      expect(s.cachedHouseholdId, 'hh-real');
      expect(repo.state['session_household_id'], 'hh-real');
      expect(repo.state['refresh_token'], 'real-refresh');
    });

    test('reports itself offline rather than as an empty household', () async {
      final s = sessionWith(signedIn(), _FakeApi(mode: 'ok', offline: true));

      await s.restore();

      expect(s.state, ApiSessionState.offline);
      expect(s.isOffline, isTrue);
      expect(s.cachedHouseholdId, 'hh-real');
      expect(s.isAuthenticated, isFalse, reason: 'no usable token, and it says so');
    });

    test('a whole-API outage still leaves the account intact', () async {
      final repo = signedIn();
      final api = _FakeApi(mode: 'server-error');
      final s = sessionWith(repo, api);

      await s.restore();

      // A 503 must not sign everyone out during an outage.
      expect(s.state, ApiSessionState.offline);
      expect(repo.state['refresh_token'], 'real-refresh');
      expect(api.paths, isNot(contains('/v1/auth/guest')));
    });

    test('rate limiting is treated as unavailable', () async {
      final s = sessionWith(signedIn(), _FakeApi(mode: 'throttled'));
      await s.restore();
      expect(s.state, ApiSessionState.offline);
    });

    test('the real account is recovered once the network returns', () async {
      final repo = signedIn();

      final offline = sessionWith(repo, _FakeApi(mode: 'ok', offline: true));
      await offline.restore();
      expect(offline.state, ApiSessionState.offline);

      final back = sessionWith(repo, _FakeApi(mode: 'ok'));
      expect(await back.restore(), isTrue);
      expect(back.state, ApiSessionState.authenticated);
      expect(back.householdId, 'hh-real');
      expect(back.accessToken, 'fresh-access');
    });
  });

  group('genuinely rejected credentials', () {
    test('a 401 clears the dead session and falls back to guest', () async {
      final repo = signedIn();
      final api = _FakeApi(mode: 'ok')..rejectPaths = {'/v1/auth/refresh'};
      final s = sessionWith(repo, api);

      await s.restore();

      // A rejected refresh token really is finished, so guest is the right answer here.
      expect(api.paths, contains('/v1/auth/guest'));
      expect(s.state, ApiSessionState.guest);
      expect(s.householdId, 'hh-guest');
      expect(repo.state['refresh_token'], 'guest-refresh');
    });
  });

  group('no credentials at all', () {
    test('mints a guest household', () async {
      final s = sessionWith(_FakeRepo(), _FakeApi(mode: 'ok'));

      expect(await s.restore(), isTrue);
      expect(s.state, ApiSessionState.guest);
      expect(s.householdId, 'hh-guest');
      expect(s.isOffline, isFalse);
    });

    test('is unauthenticated when even the guest call fails', () async {
      final s = sessionWith(_FakeRepo(), _FakeApi(mode: 'ok', offline: true));

      expect(await s.restore(), isFalse);
      expect(s.state, ApiSessionState.unauthenticated);
      // There was no session to be offline about, so claiming to be offline would mislead.
      expect(s.isOffline, isFalse);
    });
  });

  group('ensureFresh before a sync', () {
    test('renews an expired token rather than sending it', () async {
      final repo = signedIn();
      final api = _FakeApi(mode: 'ok');
      final s = sessionWith(repo, api);

      expect(s.isAuthenticated, isFalse);
      expect(await s.ensureFresh(), isTrue);
      expect(api.paths, ['/v1/auth/refresh']);
      expect(s.state, ApiSessionState.authenticated);
    });

    test('does nothing when the token is still good', () async {
      final repo = _FakeRepo();
      repo.state['access_token'] = 'good-access';
      repo.state['access_expires_at'] =
          now.add(const Duration(minutes: 10)).millisecondsSinceEpoch.toString();
      repo.state['session_household_id'] = 'hh-real';
      repo.state['refresh_token'] = 'real-refresh';
      final api = _FakeApi(mode: 'ok');
      final s = sessionWith(repo, api);

      expect(await s.ensureFresh(), isTrue);
      expect(api.paths, isEmpty);
    });

    test('falls back to offline when the refresh cannot be verified', () async {
      final api = _FakeApi(mode: 'ok', offline: true);
      final s = sessionWith(signedIn(), api);

      expect(await s.ensureFresh(), isFalse);
      expect(s.state, ApiSessionState.offline);
      expect(s.cachedHouseholdId, 'hh-real');
    });

    test('does not mint a guest when it cannot verify', () async {
      final api = _FakeApi(mode: 'ok', offline: true);
      final s = sessionWith(signedIn(), api);

      await s.ensureFresh();
      expect(api.paths, isNot(contains('/v1/auth/guest')));
    });
  });

  group('sign-out', () {
    test('clear resets the state so offline is no longer claimed', () async {
      final s = sessionWith(signedIn(), _FakeApi(mode: 'ok', offline: true));
      await s.restore();
      expect(s.isOffline, isTrue);

      await s.clear();

      expect(s.state, ApiSessionState.unauthenticated);
      expect(s.isOffline, isFalse);
      expect(s.cachedHouseholdId, isNull);
      expect(s.isAccessTokenExpired, isTrue);
    });
  });
}

/// Lets the fire-and-forget persistence inside `unawaitedPersist` finish.
///
/// That write is deliberately not awaited by the session, so the test has to yield before
/// reading the repository.
Future<void> tester0Pump() => Future<void>.delayed(Duration.zero);