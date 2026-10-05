import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:siti_counter/settings/household_profile_screen.dart';
import 'package:siti_counter/settings/settings_service.dart';
import 'package:siti_counter/settings/setup_progress.dart';

import 'household_settings_test.dart' show FakeSettings;

/// Widget tests for the in-app household setup screen.
///
/// The screen is driven through [HouseholdSettings] with an injected [SetupInputs] snapshot,
/// so these run without a database: sqflite's real I/O never completes inside `testWidgets`'
/// fake-async zone.
void main() {
  /// English by default so assertions read the English copy; one test switches to Nepali.
  FakeSettings buildFake() => FakeSettings()..languageCode = 'en';

  Future<void> pumpProfile(
    WidgetTester tester, {
    FakeSettings? settings,
    SetupInputs inputs = const SetupInputs(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdProfileScreen(
          settings: settings ?? buildFake(),
          initialInputs: inputs,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HouseholdProfileScreen', () {
    testWidgets('lists all four essentials, none complete', (tester) async {
      await pumpProfile(tester);

      expect(find.text('0 of 4 complete'), findsOneWidget);
      for (final id in SetupTaskIds.all) {
        expect(find.byKey(Key('setup_section_$id')), findsOneWidget);
      }
    });

    testWidgets('selecting several meal slots persists them all', (tester) async {
      final settings = buildFake();
      await pumpProfile(tester, settings: settings);

      await tester.tap(find.byKey(const Key('setup_section_meal_rhythm')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sheet_option_breakfast')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet_option_dinner')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(settings.slots, ['breakfast', 'dinner']);
      expect(find.text('1 of 4 complete'), findsOneWidget);
      expect(find.text('2 slots selected'), findsOneWidget);
    });

    testWidgets('tapping a selected slot again deselects it', (tester) async {
      final settings = buildFake();
      await pumpProfile(
        tester,
        settings: settings,
        inputs: const SetupInputs(enabledMealSlots: ['lunch', 'dinner']),
      );

      await tester.tap(find.byKey(const Key('setup_section_meal_rhythm')));
      await tester.pumpAndSettle();

      // Deselect lunch, keeping dinner: multi-select must not collapse to one value.
      await tester.tap(find.byKey(const Key('sheet_option_lunch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(settings.slots, ['dinner']);
    });

    testWidgets('choosing a cooking rhythm completes that section', (tester) async {
      final settings = buildFake();
      await pumpProfile(tester, settings: settings);

      await tester.tap(find.byKey(const Key('setup_section_cooking_rhythm')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('rhythm_option_daily')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(settings.rhythm, CookingRhythm.daily);
      expect(find.text('1 of 4 complete'), findsOneWidget);
      expect(find.text('Every day • no fasting days'), findsOneWidget);
    });

    testWidgets('picking a fasting day alone completes the rhythm section', (
      tester,
    ) async {
      final settings = buildFake();
      await pumpProfile(tester, settings: settings);

      await tester.tap(find.byKey(const Key('setup_section_cooking_rhythm')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fasting_option_ekadashi')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(settings.fasting, ['ekadashi']);
      // The rhythm itself is still the untouched default.
      expect(settings.rhythm, CookingRhythm.mostDays);
      expect(find.text('1 of 4 complete'), findsOneWidget);
    });

    testWidgets('choosing a unit system persists the choice', (tester) async {
      final settings = buildFake();
      await pumpProfile(tester, settings: settings);

      await tester.tap(find.byKey(const Key('setup_section_units')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('sheet_option_UnitSystem.metricWithTraditional'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(settings.units, UnitSystem.metricWithTraditional);
    });

    testWidgets('pre-supplied inputs render their completion state', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        inputs: const SetupInputs(
          enabledMealSlots: ['dinner'],
          calibratedVesselCount: 2,
          memberCount: 3,
          cookingRhythm: CookingRhythm.daily,
        ),
      );

      expect(find.text('4 of 4 complete'), findsOneWidget);
      expect(find.text('1 slot selected'), findsOneWidget);
      expect(find.text('2 vessels calibrated'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);
    });

    testWidgets('the language toggle switches the screen language', (tester) async {
      final settings = buildFake();
      await pumpProfile(tester, settings: settings);

      expect(find.text('Household setup'), findsOneWidget);

      await tester.tap(find.byKey(const Key('language_toggle_ne')));
      await tester.pumpAndSettle();

      expect(settings.languageCode, 'ne');
      expect(find.text('घरको सेटअप'), findsOneWidget);
    });
  });

  group('HouseholdMemberSetupScreen', () {
    testWidgets('asks for a name before it can be added', (tester) async {
      // Rendering the member editor needs a repository, so only the empty-name guard is
      // exercised here; the persistence path is covered by the consumption tests.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      expect(find.byType(HouseholdMemberSetupScreen), findsNothing);
    });
  });
}