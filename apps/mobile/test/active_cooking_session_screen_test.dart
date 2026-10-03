import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:siti_counter/screens/active_cooking_session_screen.dart';
import 'package:siti_counter/screens/recipe_detail_screen.dart' show CooktopType;

void main() {
  testWidgets('ActiveCookingSessionScreen renders 2-meter glanceable counter, step guide, and wake lock badge',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const testRecipe = RegionRecipe(
      id: 'masyaura-tarkari',
      titleEn: 'Masyaura Curry',
      titleNe: 'मस्यौरा र आलुको रसदार तरकारी',
      category: 'curry',
      cuisine: 'pan-nepali',
      dietary: ['vegetarian'],
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      servings: 4,
      difficulty: 'easy',
      pressureCooker: RecipeWhistleProfile(
        enabled: true,
        recommendedWhistles: 3,
        altitudeWhistleOffsetKathmandu: 1,
        heatLevel: 'medium',
        releaseType: 'natural',
      ),
      ingredients: [],
      steps: [
        RecipeStepItem(
          stepNumber: 1,
          instructionEn: 'Saute onions and spices, then add potatoes and fried masyaura.',
          instructionNe: 'प्याज र मसला भुटेर आलु र तारेको मस्यौरा हाल्नुहोस्।',
        ),
        RecipeStepItem(
          stepNumber: 2,
          instructionEn: 'Add hot water, seal pressure cooker, and cook for 4 whistles at medium flame.',
          instructionNe: 'तातो पानी हालेर कुकरको ढक्कन लगाई मध्यम आगोमा ४ सिट्ठी लगाउनुहोस्।',
          whistles: 4,
        ),
      ],
      seasonality: ['sharad'],
      tags: ['curry'],
      rating: 4.8,
      caloriesPerServing: 280,
      costEstimateNpr: 150,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ActiveCookingSessionScreen(
          recipe: testRecipe,
          targetWhistles: 4,
          cooktop: CooktopType.induction,
          currentLanguage: 'ne',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and wake lock badge
    expect(find.text('मस्यौरा र आलुको रसदार तरकारी'), findsOneWidget);
    expect(find.text('स्क्रिन अन'), findsOneWidget);

    // Verify 2-meter glanceable counter display in Devanagari: '०' / '४'
    expect(find.text('०'), findsOneWidget);
    expect(find.text('४'), findsWidgets);
    expect(find.text('सिट्ठी (SITI)'), findsOneWidget);
    expect(find.text('४ सिट्ठी बाँकी'), findsOneWidget);

    // Verify custom painter is present
    expect(find.byType(CustomPaint), findsWidgets);

    // Verify tactile buttons
    expect(find.text('+१ सिट्ठी (+1 Siti)'), findsOneWidget);
    expect(find.text('-१'), findsOneWidget);

    // Verify active step card & Induction heat guidance
    final stepFinder = find.text('सक्रिय चरण १');
    await tester.ensureVisible(stepFinder);
    expect(stepFinder, findsOneWidget);
    expect(find.text('प्याज र मसला भुटेर आलु र तारेको मस्यौरा हाल्नुहोस्।'), findsOneWidget);
    expect(find.text('ताप मार्गदर्शन (इन्डक्सन (Induction))'), findsOneWidget);
    expect(find.textContaining('१०००–१२०० वाट'), findsOneWidget);
  });

  testWidgets('ActiveCookingSessionScreen increments whistles and triggers alarm at target',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ActiveCookingSessionScreen(
          targetWhistles: 3,
          currentLanguage: 'en',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plusButton = find.text('+1 Whistle');
    final minusButton = find.text('-1');

    // Initially 0 whistles
    expect(find.text('0'), findsOneWidget);
    expect(find.text('3 whistles remaining'), findsOneWidget);

    // Increment to 1
    await tester.tap(plusButton);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2 whistles remaining'), findsOneWidget);

    // Decrement back to 0
    await tester.tap(minusButton);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);

    // Increment to 3 (target)
    await tester.tap(plusButton);
    await tester.pumpAndSettle();
    await tester.tap(plusButton);
    await tester.pumpAndSettle();
    await tester.tap(plusButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Now target reached!
    expect(find.text('3'), findsNWidgets(2)); // current and target
    expect(find.text('✓ Target Reached!'), findsOneWidget);

    // Alarm banner is displayed
    expect(find.text('🔔 Target Reached! Turn off heat'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    // Tap Stop to silence alarm
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    // Alarm banner disappears
    expect(find.text('🔔 Target Reached! Turn off heat'), findsNothing);
  });

  testWidgets('ActiveCookingSessionScreen step pagination and reset counter works',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const multiStepRecipe = RegionRecipe(
      id: 'kheer',
      titleEn: 'Nepali Kheer',
      titleNe: 'नेपाली खीर',
      category: 'dessert',
      cuisine: 'pan-nepali',
      dietary: ['vegetarian'],
      prepTimeMinutes: 5,
      cookTimeMinutes: 30,
      servings: 4,
      difficulty: 'easy',
      pressureCooker: RecipeWhistleProfile(
        enabled: true,
        recommendedWhistles: 2,
        altitudeWhistleOffsetKathmandu: 0,
        heatLevel: 'low',
        releaseType: 'natural',
      ),
      ingredients: [],
      steps: [
        RecipeStepItem(
          stepNumber: 1,
          instructionEn: 'Boil full cream milk.',
          instructionNe: 'बाक्लो दूध उमाल्नुहोस्।',
        ),
        RecipeStepItem(
          stepNumber: 2,
          instructionEn: 'Add soaked taichin rice.',
          instructionNe: 'भिजाएको ताइचिन चामल हाल्नुहोस्।',
        ),
      ],
      seasonality: ['sharad'],
      tags: ['dessert'],
      rating: 4.9,
      caloriesPerServing: 320,
      costEstimateNpr: 180,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ActiveCookingSessionScreen(
          recipe: multiStepRecipe,
          targetWhistles: 2,
          currentLanguage: 'ne',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1
    expect(find.text('बाक्लो दूध उमाल्नुहोस्।'), findsOneWidget);

    // Navigate to Next Step
    final nextButton = find.text('पछिल्लो चरण');
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Step 2
    expect(find.text('भिजाएको ताइचिन चामल हाल्नुहोस्।'), findsOneWidget);

    // Navigate back to Previous Step
    final prevButton = find.text('अघिल्लो');
    await tester.ensureVisible(prevButton);
    await tester.tap(prevButton);
    await tester.pumpAndSettle();

    expect(find.text('बाक्लो दूध उमाल्नुहोस्।'), findsOneWidget);

    // Increment whistle count and reset
    final plusButton = find.text('+१ सिट्ठी (+1 Siti)');
    await tester.tap(plusButton);
    await tester.pumpAndSettle();
    expect(find.text('१'), findsOneWidget);

    final resetButton = find.text('सिट्ठी रिसेट');
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('०'), findsOneWidget);
  });
}
