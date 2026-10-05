import 'package:flutter_test/flutter_test.dart';

import 'package:siti_counter/settings/social_auth_service.dart';
import 'package:siti_counter/settings/social_provider_registry.dart';

/// Guards the Google provider wiring.
///
/// The bug these cover is not hypothetical: the provider was shipped without ever calling
/// `GoogleSignIn.instance.initialize`, so every Android sign-in died with
/// `clientConfigurationError: serverClientId must be provided on Android` while the button
/// rendered perfectly. Availability is therefore tested against the same values the provider
/// initialises with.
void main() {
  group('SocialProviderRegistry — Google', () {
    test('a server client id is configured by default', () {
      // Empty here would hide the button entirely, which is the other failure mode.
      expect(SocialProviderRegistry.googleClientId, isNotEmpty);
      expect(
        SocialProviderRegistry.googleClientId,
        contains('apps.googleusercontent.com'),
      );
    });

    test('the provider is offered when a server client id is present', () {
      final provider = SocialProviderRegistry.google();

      expect(provider, isNotNull);
      expect(provider!.isAvailable(), isTrue);
    });

    test('the Android client id is optional', () {
      // Google resolves it from the package name plus the registered fingerprint, so it must
      // not be required for the provider to be available.
      expect(SocialProviderRegistry.androidClientId, isEmpty);
      expect(SocialProviderRegistry.google()!.isAvailable(), isTrue);
    });

    test('is registered for the configured provider', () {
      final configured = SocialProviderRegistry.configured();

      expect(configured.containsKey(SocialProvider.google), isTrue);
    });
  });

  group('SocialProviderRegistry — other providers', () {
    test('Facebook has no default, so its button stays hidden until configured', () {
      expect(SocialProviderRegistry.facebookAppId, isEmpty);
      expect(SocialProviderRegistry.facebook(), isNull);
      expect(
        SocialProviderRegistry.configured().containsKey(SocialProvider.facebook),
        isFalse,
      );
    });

    test('Apple defaults to the real bundle id', () {
      // Must match the iOS bundle identifier, since Apple sets it as the token audience.
      expect(SocialProviderRegistry.appleClientId, 'com.siticounter.sitiCounter');
    });
  });

  group('Availability drives the sign-in sheet', () {
    test('an unconfigured provider is not offered', () {
      final service = SocialSignInService(
        providers: SocialProviderRegistry.configured(),
      );

      expect(service.isAvailable(SocialProvider.google), isTrue);
      expect(service.isAvailable(SocialProvider.facebook), isFalse);
      expect(service.availableProviders, contains(SocialProvider.google));
    });

    test('Google routes to the token-verified endpoint, not the legacy one', () {
      // The legacy route trusts a client-supplied email.
      expect(
        SocialSignInService.endpointFor(SocialProvider.google),
        '/v1/auth/google/verified',
      );
    });
  });
}
