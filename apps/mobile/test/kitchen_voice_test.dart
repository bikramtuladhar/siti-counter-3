import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/audio/kitchen_voice_controller.dart';
import 'package:siti_counter/screens/active_cooking_session_screen.dart';
import 'package:siti_counter/widgets/kitchen_voice_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleRecipe = RegionRecipe(
    id: 'dal_bhat',
    titleEn: 'Masyaura Dal',
    titleNe: 'मस्यौरा दाल',
    category: 'Lentils & Pulses',
    cuisine: 'Nepali',
    dietary: const ['Vegetarian'],
    prepTimeMinutes: 15,
    cookTimeMinutes: 25,
    servings: 4,
    difficulty: 'Easy',
    ingredients: const [
      RecipeIngredientItem(ingredientId: 'musuro_dal', quantity: 200, unit: 'g'),
      RecipeIngredientItem(ingredientId: 'onion', quantity: 100, unit: 'g'),
    ],
    pressureCooker: const RecipeWhistleProfile(
      enabled: true,
      recommendedWhistles: 3,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'medium',
      releaseType: 'natural',
    ),
    seasonality: const ['all_year'],
    tags: const ['dal', 'lentils'],
    steps: const [
      RecipeStepItem(
        stepNumber: 1,
        instructionEn: 'Wash and soak lentils for 10 minutes.',
        instructionNe: 'दाल पखाल्नुहोस् र १० मिनेट भिजाउनुहोस्।',
      ),
      RecipeStepItem(
        stepNumber: 2,
        instructionEn: 'Add lentils and water to pressure cooker.',
        instructionNe: 'दाल र पानी प्रेसर कुकरमा राख्नुहोस्।',
      ),
      RecipeStepItem(
        stepNumber: 3,
        instructionEn: 'Cook for 3 whistles on medium flame.',
        instructionNe: 'मध्यम आगोमा ३ सिट्ठी लगाउनुहोस्।',
      ),
    ],
  );

  group('KitchenVoiceController Unit Tests', () {
    test('dispatches next step and previous step callbacks', () {
      var nextCount = 0;
      var prevCount = 0;

      final controller = KitchenVoiceController(
        onNextStep: () => nextCount++,
        onPreviousStep: () => prevCount++,
      );

      controller.processUtterance('Next step');
      expect(nextCount, equals(1));
      expect(controller.state, equals(VoiceControllerState.recognized));

      controller.processUtterance('अघिल्लो चरण');
      expect(prevCount, equals(1));
    });

    test('dispatches timer and whistle query callbacks', () {
      var timerDuration = 0;
      var whistleQueried = false;

      final controller = KitchenVoiceController(
        onSetTimer: (mins) => timerDuration = mins,
        onQueryWhistles: () {
          whistleQueried = true;
          return '2 whistles left';
        },
      );

      controller.processUtterance('Set timer for 8 minutes');
      expect(timerDuration, equals(8));

      controller.processUtterance('कति सिट्ठी बाँकी छ?');
      expect(whistleQueried, isTrue);
    });

    test('dispatches grocery addition callback', () {
      String? addedGrocery;
      final controller = KitchenVoiceController(
        onAddGrocery: (item) => addedGrocery = item,
      );

      controller.processUtterance('Add turmeric to grocery list');
      expect(addedGrocery, equals('turmeric'));
    });

    test('sets error state for unknown speech', () {
      final controller = KitchenVoiceController();
      controller.processUtterance('play popular music');
      expect(controller.state, equals(VoiceControllerState.error));
      expect(controller.lastCommand?.intent, equals(KitchenVoiceIntent.unknown));
    });
  });

  group('KitchenVoiceBar Widget Tests', () {
    testWidgets('renders voice bar with mic button and status', (tester) async {
      final controller = KitchenVoiceController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: KitchenVoiceBar(
              controller: controller,
              currentLanguage: 'en',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('kitchen_voice_mic_button')), findsOneWidget);
      expect(find.text('Hands-Free Kitchen Voice'), findsOneWidget);
    });

    testWidgets('opens voice sheet on tap and executes command from chip', (tester) async {
      var nextStepCalled = false;
      final controller = KitchenVoiceController(
        onNextStep: () => nextStepCalled = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: KitchenVoiceBar(
              controller: controller,
              currentLanguage: 'en',
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap mic button to open sheet
      await tester.tap(find.byKey(const Key('kitchen_voice_mic_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('100% on-device'), findsOneWidget);
      expect(find.text('Next step'), findsOneWidget);

      // Tap "Next step" quick chip
      await tester.tap(find.text('Next step'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(nextStepCalled, isTrue);
    });

    testWidgets('executes text fallback command on submission', (tester) async {
      var timerMinutes = 0;
      final controller = KitchenVoiceController(
        onSetTimer: (mins) => timerMinutes = mins,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: KitchenVoiceBar(
              controller: controller,
              currentLanguage: 'en',
            ),
          ),
        ),
      );
      await tester.pump();

      // Open sheet
      await tester.tap(find.byKey(const Key('kitchen_voice_mic_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter command in text fallback field
      await tester.enterText(
        find.byKey(const Key('kitchen_voice_text_fallback_field')),
        'Set timer for 12 minutes',
      );
      await tester.tap(find.byKey(const Key('kitchen_voice_send_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(timerMinutes, equals(12));
    });
  });

  group('ActiveCookingSessionScreen Hands-Free Voice Integration Tests', () {
    testWidgets('voice commands control active cooking steps and timer', (tester) async {
      final voiceController = KitchenVoiceController();

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveCookingSessionScreen(
            recipe: sampleRecipe,
            targetWhistles: 3,
            currentLanguage: 'en',
            voiceController: voiceController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial step is step 1
      expect(find.text('Active Step 1'), findsOneWidget);

      // Advance step via voice controller
      voiceController.processUtterance('Next step');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Active Step 2'), findsOneWidget);

      // Query whistles via voice controller
      voiceController.processUtterance('How many siti left?');
      await tester.pumpAndSettle();

      expect(find.textContaining('whistles counted'), findsOneWidget);

      // Set timer via voice
      voiceController.processUtterance('Set timer for 5 minutes');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Timer card should now appear
      expect(find.text('Active Kitchen Timer'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);

      // Pause timer
      voiceController.processUtterance('Pause timer');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Go back step
      voiceController.processUtterance('Previous step');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Active Step 1'), findsOneWidget);
    });
  });
}
