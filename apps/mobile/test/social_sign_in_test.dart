import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:siti_counter/onboarding/kitchen_ready_screen.dart';
import 'package:siti_counter/onboarding/onboarding_state.dart';
import 'package:siti_counter/settings/household_profile_publisher.dart';
import 'package:siti_counter/settings/social_auth_service.dart';
import 'package:siti_counter/settings/social_sign_in_sheet.dart';

/// Fake provider that returns a canned token, standing in for a platform SDK.
class FakeProvider implements SocialAuthProvider {
  bool available;
  String token;
  int calls = 0;

  FakeProvider({this.available = true, this.token = 'fake-token'});

  @override
  bool isAvailable() => available;

  @override
  Future<String> requestToken() async {
    calls++;
    return token;
  }
}

void main() {
  group('SocialAuthProvider wiring', () {
    test('only available providers are offered', () {
      final service = SocialSignInService(
        providers: {
          SocialProvider.google: FakeProvider(available: true),
          SocialProvider.apple: FakeProvider(available: false),
          SocialProvider.facebook: FakeProvider(available: false),
        },
      );

      expect(service.availableProviders, [SocialProvider.google]);
      expect(service.isAvailable(SocialProvider.apple), isFalse);
    });

    test('no providers means sign-in is unavailable rather than broken', () {
      final service = SocialSignInService();
      expect(service.availableProviders, isEmpty);
    });

    test('each provider posts to its own endpoint', () {
      // Google must not use the legacy route, which trusts a client-supplied email.
      expect(
        SocialSignInService.endpointFor(SocialProvider.google),
        '/v1/auth/google/verified',
      );
      expect(
        SocialSignInService.endpointFor(SocialProvider.apple),
        '/v1/auth/apple',
      );
      expect(
        SocialSignInService.endpointFor(SocialProvider.facebook),
        '/v1/auth/facebook',
      );
    });

    test('signing in with an unavailable provider throws', () async {
      final service = SocialSignInService(
        providers: {SocialProvider.google: FakeProvider(available: false)},
      );

      expect(
        () => service.signIn(SocialProvider.google),
        throwsA(isA<SocialAuthUnavailable>()),
      );
    });
  });

  group('SocialSignInSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required SocialSignInService service,
      void Function(SocialSignInResult)? onResult,
      VoidCallback? onGuest,
      bool preferNepali = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialSignInSheet(
              signInService: service,
              preferNepali: preferNepali,
              onSignedIn: onResult,
              onContinueAsGuest: onGuest,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers a button per available provider', (tester) async {
      await pumpSheet(
        tester,
        service: SocialSignInService(
          providers: {
            SocialProvider.google: FakeProvider(),
            SocialProvider.apple: FakeProvider(),
          },
        ),
      );

      expect(find.byKey(const Key('sign_in_google')), findsOneWidget);
      expect(find.byKey(const Key('sign_in_apple')), findsOneWidget);
      expect(find.byKey(const Key('sign_in_facebook')), findsNothing);
    });

    testWidgets('always offers the guest path so cooking is never gated',
        (tester) async {
      var guestTapped = false;
      await pumpSheet(
        tester,
        service: SocialSignInService(),
        onGuest: () => guestTapped = true,
      );

      expect(find.byKey(const Key('continue_as_guest_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('continue_as_guest_button')));
      await tester.pumpAndSettle();
      expect(guestTapped, isTrue);
    });

    testWidgets('explains when no provider is configured', (tester) async {
      await pumpSheet(tester, service: SocialSignInService());

      expect(find.byKey(const Key('sign_in_notice')), findsOneWidget);
      expect(find.textContaining('not available'), findsOneWidget);
      expect(find.byKey(const Key('sign_in_google')), findsNothing);
    });

    testWidgets('shows an error when the provider is unavailable at tap time',
        (tester) async {
      final provider = FakeProvider(available: true, token: '');
      await pumpSheet(
        tester,
        service: SocialSignInService(
          providers: {SocialProvider.google: provider},
        ),
      );

      await tester.tap(find.byKey(const Key('sign_in_google')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sign_in_error')), findsOneWidget);
      expect(provider.calls, 1);
    });

    testWidgets('renders Nepali copy when asked', (tester) async {
      await pumpSheet(
        tester,
        service: SocialSignInService(),
        preferNepali: true,
      );

      expect(find.text('खाता बनाउनुहोस्'), findsOneWidget);
      expect(find.text('अहिले अतिथि रूपमा जारी राख्नुहोस्'), findsOneWidget);
    });
  });

  group('KitchenReadyScreen account offer', () {
    testWidgets('shows the account entry point when sign-in is wired', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KitchenReadyScreen(
            prefs: OnboardingPreferences(language: 'en'),
            onStartCooking: () {},
            onCreateAccount: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offer_account_button')), findsOneWidget);
      expect(
        find.text('Create an account to keep my setup'),
        findsOneWidget,
      );
    });

    testWidgets('hides the entry point when no sign-in service exists',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KitchenReadyScreen(
            prefs: OnboardingPreferences(language: 'en'),
            onStartCooking: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offer_account_button')), findsNothing);
      // The guest CTA must still be there.
      expect(find.byType(ElevatedButton), findsWidgets);
    });
  });

  group('Household profile payload for merge', () {
    test('includes every configured answer', () {
      final payload = HouseholdProfilePublisher.buildProfilePayload(
        regionPackId: 'nepal-terai',
        language: 'ne',
        stoveTypes: ['lpg_gas', 'biomass_wood'],
        elevationMeters: 150,
        dietaryRules: ['strict_vegetarian'],
        mealSlots: ['breakfast', 'dinner'],
        cookingRhythm: 'daily',
        fastingDays: ['ekadashi'],
        unitSystem: 'metric_traditional',
      );

      expect(payload['regionPackId'], 'nepal-terai');
      expect(payload['language'], 'ne');
      expect(payload['stoveTypes'], ['lpg_gas', 'biomass_wood']);
      // The primary stove is derived so the server need not know about multi-select.
      expect(payload['primaryStoveType'], 'lpg_gas');
      expect(payload['elevationMeters'], 150);
      expect(payload['dietaryRules'], ['strict_vegetarian']);
      expect(payload['mealSlots'], ['breakfast', 'dinner']);
      expect(payload['cookingRhythm'], 'daily');
      expect(payload['fastingDays'], ['ekadashi']);
      expect(payload['unitSystem'], 'metric_traditional');
    });

    test('falls back to LPG when no stove was chosen', () {
      final payload = HouseholdProfilePublisher.buildProfilePayload(
        regionPackId: 'nepal-bagmati',
        language: 'en',
        stoveTypes: const [],
        elevationMeters: 1400,
        dietaryRules: const [],
        mealSlots: const [],
        cookingRhythm: 'most_days',
        fastingDays: const [],
        unitSystem: 'metric',
      );

      expect(payload['primaryStoveType'], 'lpg_gas');
      expect(payload['stoveTypes'], isEmpty);
    });

    test('member payload carries allergens, which merge must not drop', () {
      final payload = HouseholdProfilePublisher.buildMemberPayload(
        id: 'm1',
        name: 'Aayush',
        role: 'Child',
        allergies: ['peanut', 'mustard'],
      );

      expect(payload['allergies'], ['peanut', 'mustard']);
      expect(payload['role'], 'Child');
    });

    test('a member with no allergens sends an empty list, not a missing key', () {
      final payload = HouseholdProfilePublisher.buildMemberPayload(
        id: 'm2',
        name: 'B',
        role: 'Adult',
      );

      // The sync resolver treats an allergen difference as a prompt-user conflict, so an
      // absent key and an empty list must not be conflated.
      expect(payload.containsKey('allergies'), isTrue);
      expect(payload['allergies'], isEmpty);
    });
  });
}