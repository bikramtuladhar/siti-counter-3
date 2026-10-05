import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:siti_counter/onboarding/language_toggle.dart';
import 'package:siti_counter/onboarding/onboarding_state.dart';
import 'package:siti_counter/onboarding/setup_wizard_screen.dart';
import 'package:siti_counter/onboarding/welcome_tour_screen.dart';

void main() {
  group('OnboardingPreferences', () {
    test('defaults to a single LPG stove', () {
      final prefs = OnboardingPreferences();
      expect(prefs.stoveTypes, ['lpg_gas']);
      expect(prefs.primaryStoveType, 'lpg_gas');
    });

    test('toggling adds then removes a stove', () {
      final prefs = OnboardingPreferences();

      prefs.toggleStoveType('induction');
      expect(prefs.stoveTypes, ['lpg_gas', 'induction']);

      prefs.toggleStoveType('lpg_gas');
      expect(prefs.stoveTypes, ['induction']);
    });

    test('primary stove is the first selected, with an LPG fallback', () {
      expect(
        OnboardingPreferences(stoveTypes: ['biomass_wood', 'induction']).primaryStoveType,
        'biomass_wood',
      );
      // An empty selection must still resolve to something usable.
      expect(OnboardingPreferences(stoveTypes: []).primaryStoveType, 'lpg_gas');
    });

    test('isNepali reflects the language code', () {
      expect(OnboardingPreferences(language: 'ne').isNepali, isTrue);
      expect(OnboardingPreferences(language: 'en').isNepali, isFalse);
    });
  });

  group('SetupWizardScreen — "What do you cook on?" is multi-select', () {
    Future<void> pumpStoveStep(WidgetTester tester, OnboardingPreferences prefs) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SetupWizardScreen(
            initialPrefs: prefs,
            onComplete: (_) {},
            onBack: () {},
          ),
        ),
      );
      // Step 0 is region, step 1 language, step 2 stove.
      await tester.tap(find.text(prefs.isNepali ? 'अगाडि बढ्नुहोस्' : 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(prefs.isNepali ? 'अगाडि बढ्नुहोस्' : 'Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('a second stove can be added without clearing the first', (tester) async {
      final prefs = OnboardingPreferences(language: 'en');
      await pumpStoveStep(tester, prefs);

      expect(prefs.stoveTypes, ['lpg_gas']);

      await tester.tap(find.byKey(const Key('check_option_induction')));
      await tester.pumpAndSettle();

      expect(prefs.stoveTypes, containsAll(<String>['lpg_gas', 'induction']));
      expect(prefs.stoveTypes.length, 2);
    });

    testWidgets('tapping a selected stove deselects it', (tester) async {
      final prefs = OnboardingPreferences(language: 'en', stoveTypes: ['lpg_gas', 'induction']);
      await pumpStoveStep(tester, prefs);

      await tester.tap(find.byKey(const Key('check_option_induction')));
      await tester.pumpAndSettle();

      expect(prefs.stoveTypes, ['lpg_gas']);
    });

    testWidgets('shows how many stoves are selected', (tester) async {
      final prefs = OnboardingPreferences(language: 'en');
      await pumpStoveStep(tester, prefs);

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('check_option_biomass_wood')));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
    });
  });

  group('SetupWizardScreen — language switcher', () {
    testWidgets('switching to English updates the question text', (tester) async {
      final prefs = OnboardingPreferences(language: 'ne');
      await tester.pumpWidget(
        MaterialApp(
          home: SetupWizardScreen(
            initialPrefs: prefs,
            onComplete: (_) {},
            onBack: () {},
          ),
        ),
      );

      await tester.tap(find.text('अगाडि बढ्नुहोस्'));
      await tester.pumpAndSettle();

      // Nepali by default.
      expect(find.text('कुन भाषा मन पराउनुहुन्छ?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('language_toggle_en')));
      await tester.pumpAndSettle();

      expect(prefs.language, 'en');
      expect(find.text('What language do you prefer?'), findsOneWidget);
    });
  });

  group('WelcomeTourScreen — language switcher', () {
    testWidgets('tour content switches language from the header toggle', (tester) async {
      bool preferNepali = true;
      bool? reported;

      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeTourScreen(
            preferNepali: true,
            onLanguageChanged: (value) {
              preferNepali = value;
              reported = value;
            },
            onFinish: () {},
          ),
        ),
      );

      expect(find.text('Skip'), findsNothing);
      expect(find.text('सिधै सुरु गर्नुहोस्'), findsOneWidget);

      await tester.tap(find.byKey(const Key('language_toggle_en')));
      await tester.pumpAndSettle();

      expect(reported, isFalse);
      expect(preferNepali, isFalse);
      // The tour body and the skip affordance both re-render in English.
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Never Miss or Miscount a Whistle'), findsOneWidget);
    });

    testWidgets('tapping the already-active language is a no-op', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeTourScreen(
            preferNepali: true,
            onLanguageChanged: (_) => calls++,
            onFinish: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('language_toggle_ne')));
      await tester.pumpAndSettle();

      expect(calls, 0);
    });
  });

  group('LanguageToggle', () {
    testWidgets('marks the active language as selected for screen readers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LanguageToggle(language: 'ne', onChanged: (_) {}),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(const Key('language_toggle_ne'))).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(
        tester.getSemantics(find.byKey(const Key('language_toggle_en'))).hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );
      handle.dispose();
    });
  });
}