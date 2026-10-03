import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:siti_counter/screens/recipe_detail_screen.dart';

RegionRecipe createTestRecipe() {
  return const RegionRecipe(
    id: 'kalo-dal-jimbu',
    titleEn: 'Kalo Daal with Jimbu',
    titleNe: 'जिम्बु झानेको कालो दाल',
    category: 'dal',
    cuisine: 'pan-nepali',
    dietary: ['vegetarian', 'gluten-free'],
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
    elevationBand: RecipeElevationBand(
      testedElevationMeters: 1400,
      boilingPointCelsius: 95.3,
      waterMultiplier: 1.15,
    ),
    ingredients: [
      RecipeIngredientItem(ingredientId: 'kalo_dal', quantity: 200, unit: 'g'),
      RecipeIngredientItem(ingredientId: 'jimbu', quantity: 5, unit: 'g'),
      RecipeIngredientItem(ingredientId: 'ghee', quantity: 2, unit: 'tbsp'),
    ],
    steps: [
      RecipeStepItem(
        stepNumber: 1,
        instructionEn: 'Wash dal thoroughly and add to pressure cooker with water and turmeric.',
        instructionNe: 'दाल सफासँग पखालेर प्रेसर कुकरमा पानी र बेसार हाल्नुहोस्।',
        timerMinutes: 2,
        whistles: null,
      ),
      RecipeStepItem(
        stepNumber: 2,
        instructionEn: 'Secure lid and cook for 4 whistles at Kathmandu altitude.',
        instructionNe: 'ढक्कन लगाएर काठमाडौँको उचाइअनुसार ४ सिट्ठी लगाउनुहोस्।',
        timerMinutes: 12,
        whistles: 4,
      ),
    ],
    seasonality: ['sharad', 'hemanta'],
    tags: ['dal', 'pressure-cooker'],
    rating: 4.9,
    caloriesPerServing: 240,
    costEstimateNpr: 70,
  );
}

void main() {
  testWidgets('RecipeDetailScreen renders hero info, meta tags, and altitude advisory',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = createTestRecipe();

    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipe,
          currentLanguage: 'ne',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and subtitle
    expect(find.text('जिम्बु झानेको कालो दाल'), findsWidgets);
    expect(find.text('Kalo Daal with Jimbu'), findsOneWidget);

    // Verify meta tags
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('३० मिनेट'), findsOneWidget); // 10 prep + 20 cook
    expect(find.text('४ सिट्ठी'), findsWidgets); // 3 base + 1 altitude

    // Verify Kathmandu altitude advisory
    expect(find.text('काठमाडौँ उचाइ सल्लाह (१,४०० मिटर):'), findsOneWidget);
    expect(find.textContaining('९५.३°C'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen dynamically scales ingredients with servings selector',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = createTestRecipe();

    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipe,
          currentLanguage: 'en',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial 4 servings: 200 g kalo dal
    expect(find.text('4'), findsOneWidget);
    expect(find.text('200 g'), findsOneWidget);
    expect(find.text('NPR 280'), findsOneWidget); // 70 * 4

    // Increment servings from 4 to 6 (tap '+' twice)
    final plusButton = find.byIcon(Icons.add_rounded);
    await tester.tap(plusButton);
    await tester.pump();
    await tester.tap(plusButton);
    await tester.pumpAndSettle();

    // Servings is now 6
    expect(find.text('6'), findsOneWidget);

    // Scaled dal quantity is now 300 g (200 * 6 / 4)
    expect(find.text('300 g'), findsOneWidget);

    // Total cost scaled to 70 * 6 = NPR 420
    expect(find.text('NPR 420'), findsOneWidget);

    // Decrement back to 5
    final minusButton = find.byIcon(Icons.remove_rounded);
    await tester.tap(minusButton);
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.text('250 g'), findsOneWidget);
    expect(find.text('NPR 350'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen cooktop selector updates heat guidance & whistle count',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = createTestRecipe();

    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipe,
          currentLanguage: 'ne',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially LPG Gas
    expect(find.text('ताप मार्गदर्शन: मध्यम नीलो आगो'), findsOneWidget);

    // Switch to Induction
    final inductionChip = find.text('इन्डक्सन (Induction)');
    await tester.tap(inductionChip);
    await tester.pumpAndSettle();

    expect(find.text('ताप मार्गदर्शन: १०००–१२०० वाट (मन्द ८०० वाट)'), findsOneWidget);

    // Switch to Electric Coil (adds +1 whistle)
    final electricChip = find.text('हटर/क्वाइल (Electric)');
    await tester.tap(electricChip);
    await tester.pumpAndSettle();

    expect(find.text('ताप मार्गदर्शन: मध्यम-कडा (स्तर ४)'), findsOneWidget);
    // Whistles increased to 5 (3 base + 1 alt + 1 electric coil)
    expect(find.text('५ सिट्ठी'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen triggers start cooking callback with target whistles',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = createTestRecipe();
    int? startedWhistles;
    CooktopType? startedCooktop;

    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipe,
          currentLanguage: 'ne',
          onStartCooking: (r, whistles, cooktop) {
            startedWhistles = whistles;
            startedCooktop = cooktop;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final startButton = find.text('सिट्ठी काउन्टर सुरु गर्नुहोस्');
    expect(startButton, findsOneWidget);

    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump();

    expect(startedWhistles, equals(4)); // 3 base + 1 altitude
    expect(startedCooktop, equals(CooktopType.lpgGas));
  });

  testWidgets('RecipeDetailScreen "Add all to grocery list" triggers callback & feedback',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = createTestRecipe();
    int? groceryServings;

    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipe,
          currentLanguage: 'ne',
          onAddAllToGrocery: (r, servings) {
            groceryServings = servings;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addAllButton = find.text('सबै सामग्री सूचीमा थप्नुहोस्');
    expect(addAllButton, findsOneWidget);

    await tester.ensureVisible(addAllButton);
    await tester.tap(addAllButton);
    await tester.pump();

    expect(groceryServings, equals(4));
    expect(find.text('सबै सामग्री किराना सूचीमा थपियो'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen "What to buy" converts recipe portion to market units and shows surplus advice',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const recipeWithTomato = RegionRecipe(
      id: 'aloo-tama-bodi',
      titleEn: 'Aloo Tama Bodi',
      titleNe: 'आलु तामा बोडी',
      category: 'curry',
      cuisine: 'newari',
      dietary: ['vegetarian', 'vegan'],
      prepTimeMinutes: 15,
      cookTimeMinutes: 25,
      servings: 4,
      difficulty: 'medium',
      pressureCooker: RecipeWhistleProfile(
        enabled: true,
        recommendedWhistles: 3,
        altitudeWhistleOffsetKathmandu: 1,
        heatLevel: 'medium',
        releaseType: 'natural',
      ),
      ingredients: [
        RecipeIngredientItem(ingredientId: 'tomato', quantity: 750, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'potato', quantity: 400, unit: 'g'),
      ],
      steps: [
        RecipeStepItem(
          stepNumber: 1,
          instructionEn: 'Fry spices and cook vegetables.',
          instructionNe: 'मसला भुट्नुहोस् र तरकारी पकाउनुहोस्।',
        ),
      ],
      seasonality: ['sharad'],
      tags: ['curry'],
      rating: 4.8,
      caloriesPerServing: 260,
      costEstimateNpr: 120,
    );

    const tomatoIngredient = RegionIngredient(
      id: 'tomato',
      nameEn: 'Tomato',
      nameNe: 'गोलभेडा',
      aliases: ['golbheda', 'tamatar'],
      category: 'vegetables',
      standardUnit: 'kg',
      marketPackageGrams: 1000,
      storageDays: 7,
      allergens: [],
      availability: {'sharad': 'peak'},
    );

    const potatoIngredient = RegionIngredient(
      id: 'potato',
      nameEn: 'Potato',
      nameNe: 'आलु',
      aliases: ['aloo', 'alu'],
      category: 'vegetables',
      standardUnit: 'pau',
      marketPackageGrams: 250,
      storageDays: 21,
      allergens: [],
      availability: {'sharad': 'peak'},
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipeWithTomato,
          currentLanguage: 'ne',
          ingredientsCatalog: [tomatoIngredient, potatoIngredient],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "What to Buy" section title
    expect(find.text('के किन्ने (बजारको नाप र बचत)'), findsOneWidget);

    // Tomato required is 750g, vendor unit is 1 kg (4 pau) in Nepali
    expect(find.text('१ के.जी. (४ पाउ)'), findsOneWidget);

    // Potato required is 400g, 2 packages of 250g = 500g = 2 pau (500g)
    expect(find.text('२ पाउ (५०० ग्राम)'), findsOneWidget);

    // 750g tomato into 1000g leaves 250g surplus -> expect tomato achar advice
    expect(
      find.textContaining('पोलेको गोलभेडाको ताजा अचार बनाउन उत्तम'),
      findsOneWidget,
    );

    // Check initial status: 2 to buy, 0 in pantry
    expect(find.text('२ किन्नुपर्ने'), findsOneWidget);
    expect(find.text('० घरमै छ'), findsOneWidget);

    // Tap "सबै छ" quick action
    final allInPantryButton = find.text('सबै छ');
    await tester.ensureVisible(allInPantryButton);
    await tester.tap(allInPantryButton);
    await tester.pumpAndSettle();

    // Now 0 to buy, 2 in pantry
    expect(find.text('० किन्नुपर्ने'), findsOneWidget);
    expect(find.text('२ घरमै छ'), findsOneWidget);
    expect(find.text('आवश्यक छैन'), findsNWidgets(2));

    // Tap "सबै किन्ने" quick action to reset
    final buyAllButton = find.text('सबै किन्ने');
    await tester.ensureVisible(buyAllButton);
    await tester.tap(buyAllButton);
    await tester.pumpAndSettle();

    expect(find.text('२ किन्नुपर्ने'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen "Add purchasable to grocery list" sends only needed items',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = createTestRecipe();
    List<IngredientPurchasePlan>? purchasableList;

    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipe,
          currentLanguage: 'ne',
          // kalo_dal is already in pantry
          initialPantry: const {'kalo_dal': true},
          onAddPurchasableToGrocery: (items) {
            purchasableList = items;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addPurchasableButton = find.text('किन्नुपर्ने सामग्री किराना सूचीमा थप्नुहोस्');
    expect(addPurchasableButton, findsOneWidget);

    await tester.ensureVisible(addPurchasableButton);
    await tester.tap(addPurchasableButton);
    await tester.pump();

    // kalo_dal is in pantry, so only jimbu and ghee should be in purchasableList (2 items)
    expect(purchasableList, isNotNull);
    expect(purchasableList!.length, equals(2));
    expect(purchasableList!.any((p) => p.ingredientId == 'kalo_dal'), isFalse);
    expect(find.text('२ वटा किन्ने सामग्री किराना सूचीमा थपियो'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen displays safety alert card when severe allergen is present',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = createTestRecipe(); // Contains ghee (hidden dairy)

    await tester.pumpWidget(
      MaterialApp(
        home: RecipeDetailScreen(
          recipe: recipe,
          currentLanguage: 'ne',
          memberAllergies: const [
            MemberAllergyProfile(
              allergen: AllergenCatalog.milk,
              severity: AllergySeverity.severe,
              memberName: 'अनिश',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify safety alert card is rendered
    expect(find.byKey(const Key('safety_alert_card')), findsOneWidget);
    expect(find.text('🚨 एलर्जी वा आहार प्रतिबन्ध चेतावनी'), findsOneWidget);
    expect(find.textContaining('ghee contains dairy for अनिश'), findsOneWidget);
    expect(find.textContaining('💡 सुरक्षित विकल्प:'), findsOneWidget);
  });
}
