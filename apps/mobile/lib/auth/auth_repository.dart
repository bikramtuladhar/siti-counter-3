import 'dart:async';
import 'auth_state.dart';
import 'token_storage.dart';

/// Repository managing user identity, anonymous guest sessions,
/// authentication tokens, and progressive guest-to-account data migration.
class AuthRepository {
  final SecureTokenStorage tokenStorage;
  final StreamController<AuthStatus> _statusController =
      StreamController<AuthStatus>.broadcast();

  AuthUser? _currentUser;
  AuthStatus _status = AuthStatus.unauthenticated;

  AuthRepository({
    SecureTokenStorage? tokenStorage,
  }) : tokenStorage = tokenStorage ?? InMemoryTokenStorage();

  AuthStatus get status => _status;
  AuthUser? get currentUser => _currentUser;
  Stream<AuthStatus> get statusStream => _statusController.stream;

  /// Initializes or restores an anonymous guest session.
  Future<AuthSession> initializeGuestSession({
    String? deviceId,
    String? regionPackId,
  }) async {
    final devId = deviceId ?? 'dev_${DateTime.now().millisecondsSinceEpoch}';
    final user = AuthUser(
      id: 'usr_guest_$devId',
      email: null,
      name: 'Guest Cook',
      isAnonymous: true,
      householdId: 'hh_guest_$devId',
      createdAt: DateTime.now(),
    );

    const accessToken = 'atk_guest_session';
    const refreshToken = 'rtk_guest_session';

    await tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    _currentUser = user;
    _status = AuthStatus.guest;
    _statusController.add(_status);

    return AuthSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: 900,
    );
  }

  /// Upgrades an active guest account to authenticated user with non-destructive merge.
  Future<AuthUser> upgradeGuestAccount({
    required String email,
    required String provider, // 'google' | 'magic_link'
    String? name,
  }) async {
    final priorGuestHouseholdId = _currentUser?.householdId;
    final cleanEmail = email.toLowerCase().trim();

    final authenticatedUser = AuthUser(
      id: 'usr_${cleanEmail.replaceAll('@', '_')}',
      email: cleanEmail,
      name: name ?? cleanEmail.split('@')[0],
      isAnonymous: false,
      // Retain or link the guest household so zero recipe/meal data is lost
      householdId: priorGuestHouseholdId ?? 'hh_${cleanEmail.replaceAll('@', '_')}',
      createdAt: DateTime.now(),
    );

    final newAccessToken = 'atk_auth_${authenticatedUser.id}';
    final newRefreshToken = 'rtk_auth_${authenticatedUser.id}';

    await tokenStorage.saveTokens(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );

    _currentUser = authenticatedUser;
    _status = AuthStatus.authenticated;
    _statusController.add(_status);

    return authenticatedUser;
  }

  /// Refreshes the short-lived access token using rotating refresh token.
  Future<bool> refreshTokens() async {
    final currentRefreshToken = await tokenStorage.getRefreshToken();
    if (currentRefreshToken == null) {
      _status = AuthStatus.unauthenticated;
      _statusController.add(_status);
      return false;
    }

    // Issue rotated tokens
    final rotatedAccessToken = 'atk_rotated_${DateTime.now().millisecondsSinceEpoch}';
    final rotatedRefreshToken = 'rtk_rotated_${DateTime.now().millisecondsSinceEpoch}';

    await tokenStorage.saveTokens(
      accessToken: rotatedAccessToken,
      refreshToken: rotatedRefreshToken,
    );

    return true;
  }

  Future<void> signOut() async {
    await tokenStorage.clearTokens();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _statusController.add(_status);
  }

  void dispose() {
    _statusController.close();
  }
}
