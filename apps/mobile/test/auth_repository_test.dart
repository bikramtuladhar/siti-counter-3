import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/auth/auth_repository.dart';
import 'package:siti_counter/auth/auth_state.dart';
import 'package:siti_counter/auth/token_storage.dart';

void main() {
  group('AuthRepository', () {
    late InMemoryTokenStorage tokenStorage;
    late AuthRepository repo;

    setUp(() {
      tokenStorage = InMemoryTokenStorage();
      repo = AuthRepository(tokenStorage: tokenStorage);
    });

    tearDown(() {
      repo.dispose();
    });

    test('initializes guest session and stores tokens', () async {
      expect(repo.status, equals(AuthStatus.unauthenticated));

      await repo.initializeGuestSession(deviceId: 'pixel7_dev');

      expect(repo.status, equals(AuthStatus.guest));
      expect(repo.currentUser?.isAnonymous, isTrue);
      expect(repo.currentUser?.householdId, contains('hh_guest_pixel7_dev'));

      final accessToken = await tokenStorage.getAccessToken();
      expect(accessToken, isNotNull);
    });

    test('upgrades guest to authenticated account with non-destructive data retention', () async {
      await repo.initializeGuestSession(deviceId: 'pixel7_dev');
      final guestHouseholdId = repo.currentUser!.householdId;

      final user = await repo.upgradeGuestAccount(
        email: 'bikram@example.com',
        provider: 'google',
        name: 'Bikram Tuladhar',
      );

      expect(repo.status, equals(AuthStatus.authenticated));
      expect(user.isAnonymous, isFalse);
      expect(user.email, equals('bikram@example.com'));
      expect(user.name, equals('Bikram Tuladhar'));
      // Household ID is preserved so existing recipes/meal plans are not lost
      expect(user.householdId, equals(guestHouseholdId));
    });

    test('rotates refresh tokens on refresh', () async {
      await repo.initializeGuestSession(deviceId: 'pixel7_dev');
      final originalRefresh = await tokenStorage.getRefreshToken();

      final refreshed = await repo.refreshTokens();
      expect(refreshed, isTrue);

      final newRefresh = await tokenStorage.getRefreshToken();
      expect(newRefresh, isNot(equals(originalRefresh)));
    });

    test('signs out and clears secure tokens', () async {
      await repo.initializeGuestSession(deviceId: 'pixel7_dev');
      await repo.signOut();

      expect(repo.status, equals(AuthStatus.unauthenticated));
      expect(repo.currentUser, isNull);
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });
  });
}
