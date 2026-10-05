import 'dart:io';

// ignore: import_of_legacy_library_into_null_safe
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'social_auth_service.dart';

/// Real SDK-backed [SocialAuthProvider] implementations.
///
/// A provider reports itself unavailable unless its SDK is present on this platform *and*
/// the deployment supplies the client id the API verifies against. Without that pairing the
/// button stays hidden: showing a sign-in button that the server will reject, or that
/// cannot complete, is worse than not offering it.
///
/// Client ids are supplied as `--dart-define` values so no secret is compiled into a
/// committed file:
///
/// ```
/// flutter run \
///   --dart-define=GOOGLE_CLIENT_ID=...apps.googleusercontent.com \
///   --dart-define=APPLE_CLIENT_ID=com.siticounter.app \
///   --dart-define=FACEBOOK_APP_ID=1234567890
/// ```
class SocialProviderRegistry {
  /// Public OAuth client ids, not secrets.
  ///
  /// An OAuth client id is embedded in the shipped binary either way, so defaulting it here
  /// makes Google sign-in work without a build flag while still allowing a per-build
  /// override for a different environment. The *secret* stays on the server and is never
  /// shipped.
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '228915460049-54cpjsd261jreom9cji2ql9v0jbolger.apps.googleusercontent.com',
  );

  static const String appleClientId = String.fromEnvironment(
    'APPLE_CLIENT_ID',
    defaultValue: 'com.siticounter.sitiCounter',
  );

  static const String facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');

  /// Builds a provider only when it is fully configured, so an unconfigured build never
  /// offers the option.
  ///

  static SocialAuthProvider? google() {
    if (googleClientId.isEmpty) return null;
    return _GoogleProvider(clientId: googleClientId);
  }

  static SocialAuthProvider? apple() {
    // Apple needs the Sign in with Apple capability on iOS; without it the request throws
    // at runtime, so only offer it on platforms where it can work.
    if (appleClientId.isEmpty) return null;
    if (Platform.isIOS || Platform.isMacOS) return _AppleProvider();
    return null;
  }

  static SocialAuthProvider? facebook() {
    if (facebookAppId.isEmpty) return null;
    return _FacebookProvider(appId: facebookAppId);
  }

  /// Every provider that is configured, keyed for [SocialSignInService].
  static Map<SocialProvider, SocialAuthProvider> configured() {
    final providers = <SocialProvider, SocialAuthProvider>{};

    // Named to avoid shadowing the static methods of the same name.
    final googleProvider = google();
    if (googleProvider != null) providers[SocialProvider.google] = googleProvider;

    final appleProvider = apple();
    if (appleProvider != null) providers[SocialProvider.apple] = appleProvider;

    final facebookProvider = facebook();
    if (facebookProvider != null) {
      providers[SocialProvider.facebook] = facebookProvider;
    }

    return providers;
  }
}

class _GoogleProvider implements SocialAuthProvider {
  final String clientId;
  final GoogleSignIn _client = GoogleSignIn.instance;

  _GoogleProvider({required this.clientId});

  @override
  bool isAvailable() => clientId.isNotEmpty;

  @override
  Future<String> requestToken() async {
    // Attempt silent sign-in first so a returning user is not prompted again.
    // Try a silent sign-in first so a returning user is not prompted again; fall back to
    // the interactive flow when no cached credential is usable.
    GoogleSignInAccount? account;
    try {
      account = await _client.attemptLightweightAuthentication();
    } catch (_) {
      account = null;
    }
    account ??= await _client.authenticate();

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw SocialAuthUnavailable(
        SocialProvider.google,
        'Google did not return an ID token.',
      );
    }
    return idToken;
  }
}

class _AppleProvider implements SocialAuthProvider {
  @override
  bool isAvailable() =>
      Platform.isIOS || Platform.isMacOS;

  @override
  Future<String> requestToken() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );

    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      throw SocialAuthUnavailable(
        SocialProvider.apple,
        'Apple did not return an identity token.',
      );
    }
    return token;
  }
}

/// Facebook sign-in.
///
/// The 7.x SDK reads its App ID from AndroidManifest / Info.plist rather than taking it in
/// code, so the dart-define here is the switch that says "this deployment has Facebook
/// wired up" and matches the id the API validates the token against. If the native config is
/// missing while the define is present, `login()` fails and the message is surfaced rather
/// than swallowed.
class _FacebookProvider implements SocialAuthProvider {
  final String appId;

  _FacebookProvider({required this.appId});

  @override
  bool isAvailable() => appId.isNotEmpty;

  @override
  Future<String> requestToken() async {
    final LoginResult result;
    try {
      result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );
    } catch (e) {
      throw SocialAuthUnavailable(SocialProvider.facebook, e.toString());
    }

    if (result.status != LoginStatus.success) {
      throw SocialAuthUnavailable(
        SocialProvider.facebook,
        result.message ?? 'Facebook sign-in did not complete.',
      );
    }

    final token = result.accessToken?.tokenString;
    if (token == null || token.isEmpty) {
      throw SocialAuthUnavailable(
        SocialProvider.facebook,
        'Facebook did not return an access token.',
      );
    }
    return token;
  }
}