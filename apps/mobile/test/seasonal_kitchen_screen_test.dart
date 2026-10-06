import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:siti_counter/data/region_pack_repository.dart';
import 'package:siti_counter/main.dart';
import 'package:siti_counter/onboarding/onboarding_state.dart';
import 'package:siti_counter/screens/seasonal_kitchen_screen.dart';

RegionPack createTestRegionPack() {
  const manifest = RegionPackManifest(
    id: 'nepal-bagmati',
    version: '1.0.0',
    name: 'Nepal (Bagmati / Kathmandu Valley)',
    country: 'Nepal',
    countryCode: 'NP',
    region: 'Bagmati',
    status: 'beta',
    elevationMeters: 1400,
    defaultLanguage: 'ne',
    calendar: 'bikram-sambat',
    seasonSystem: 'six-ritus',
  );

  final seasonality = RegionSeasonality(
    regionId: 'nepal-bagmati',
    ritus: const [
      RituSeason(
        id: 'sharad',
        name: 'शरद (Sharad)',
        monthsBS: ['Ashwin', 'Kartik'],
        monthsGregorian: ['September', 'October'],
        signatureProduce: ['फूल गोभी', 'मूला', 'पालुङ्गो'],
      ),
      RituSeason(
        id: 'hemanta',
        name: 'हेमन्त (Hemanta)',
        monthsBS: ['Mangsir', 'Poush'],
        monthsGregorian: ['November', 'December'],
        signatureProduce: ['गुन्द्रुक', 'गाँजर', 'तरुल'],
      ),
    ],
  );

  final ingredients = [
    const RegionIngredient(
      id: 'cauliflower',
      nameEn: 'Cauliflower',
      nameNe: 'काउली (फूल गोभी)',
      aliases: ['kauli', 'gobi'],
      category: 'vegetables',
      standardUnit: 'kg',
      marketPackageGrams: 1000,
      storageDays: 5,
      allergens: [],
      availability: {
        'sharad': 'peak',
        'hemanta': 'in_season',
      },
    ),
    const RegionIngredient(
      id: 'potato',
      nameEn: 'Potato',
      nameNe: 'आलु',
      aliases: ['alu'],
      category: 'vegetables',
      standardUnit: 'pau',
      marketPackageGrams: 250,
      storageDays: 21,
      allergens: [],
      availability: {
        'sharad': 'available',
        'hemanta': 'peak',
      },
    ),
    const RegionIngredient(
      id: 'jimbu',
      nameEn: 'Jimbu Herb',
      nameNe: 'जिम्बु',
      aliases: ['himalayan aromatic'],
      category: 'herbs',
      standardUnit: 'g',
      marketPackageGrams: 50,
      storageDays: 180,
      allergens: [],
      availability: {
        'sharad': 'peak',
        'hemanta': 'available',
      },
    ),
  ];

  final recipes = [
    const RegionRecipe(
      id: 'aloo-kauli-tarkari',
      titleEn: 'Aloo Kauli Tarkari',
      titleNe: 'आलु काउलीको तरकारी',
      category: 'curry',
      cuisine: 'pan-nepali',
      dietary: ['vegetarian'],
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 4,
      difficulty: 'easy',
      pressureCooker: RecipeWhistleProfile(
        enabled: true,
        recommendedWhistles: 2,
        altitudeWhistleOffsetKathmandu: 1,
        heatLevel: 'medium',
        releaseType: 'quick',
      ),
      ingredients: [
        RecipeIngredientItem(ingredientId: 'cauliflower', quantity: 1, unit: 'kg'),
        RecipeIngredientItem(ingredientId: 'potato', quantity: 2, unit: 'pau'),
      ],
      seasonality: ['sharad', 'hemanta'],
      tags: ['everyday', 'dal-bhat'],
    ),
    const RegionRecipe(
      id: 'kalo-dal-jimbu',
      titleEn: 'Kalo Dal with Jimbu',
      titleNe: 'जिम्बु झानेको कालो दाल',
      category: 'dal',
      cuisine: 'pan-nepali',
      dietary: ['vegetarian', 'gluten-free'],
      prepTimeMinutes: 5,
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
      ingredients: [
        RecipeIngredientItem(ingredientId: 'jimbu', quantity: 5, unit: 'g'),
      ],
      seasonality: ['all_year'],
      tags: ['dal'],
    ),
  ];

  const preservations = [
    PreservationSuggestion(
      id: 'gundruk-fermentation',
      titleEn: 'Gundruk Fermentation',
      titleNe: 'गुन्द्रुक बनाउने मौसम (किण्वन)',
      descriptionEn: 'Ferment fresh mustard greens for winter use.',
      descriptionNe: 'ताजा रायोको साग भाँडोमा खाँदी किण्वन गराउने उत्तम समय।',
      targetSeason: 'sharad',
      primaryIngredients: ['cauliflower'],
      method: 'Lactic acid fermentation & sun-drying',
    ),
  ];

  return RegionPack(
    manifest: manifest,
    seasonality: seasonality,
    ingredients: ingredients,
    recipes: recipes,
    festivals: const [],
    preservationSuggestions: preservations,
  );
}

void main() {
  testWidgets('SeasonalKitchenScreen renders header with season, region, and ingredients',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pack = createTestRegionPack();

    await tester.pumpWidget(
      MaterialApp(
        home: SeasonalKitchenScreen(
          initialPack: pack,
          currentLanguage: 'ne',
          initialRituId: 'sharad',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify screen title
    expect(find.text('सिजनल भान्सा'), findsOneWidget);

    // Verify Header details
    expect(find.textContaining('शरद (Sharad) · Ashwin-Kartik · बागमती'), findsOneWidget);
    expect(find.text('Nepal (Bagmati / Kathmandu Valley)'), findsOneWidget);

    // Verify signature produce tag
    expect(find.text('फूल गोभी'), findsOneWidget);

    // Verify ingredients rendered
    expect(find.text('काउली (फूल गोभी)'), findsOneWidget);
    expect(find.text('Cauliflower'), findsOneWidget);
    expect(find.text('आलु'), findsOneWidget);
    expect(find.text('Potato'), findsOneWidget);

    // Verify availability badges
    expect(find.text('उत्कृष्ट सिजन (Peak)'), findsWidgets);
    expect(find.text('उपलब्ध (Available)'), findsOneWidget);

    // Verify recipe count
    expect(find.text('१ परिकारमा प्रयोग'), findsWidgets);
  });

  testWidgets('SeasonalKitchenScreen category filter filters list', (tester) async {
    final pack = createTestRegionPack();

    await tester.pumpWidget(
      MaterialApp(
        home: SeasonalKitchenScreen(
          initialPack: pack,
          currentLanguage: 'en',
          initialRituId: 'sharad',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The recommendations section sits above the ingredients, so scroll down to reach the
    // filter chips rather than assuming they are built.
    await tester.scrollUntilVisible(
      find.text('Spices & Herbs'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // In English, all ingredients are visible initially (3 items)
    expect(find.text('3 items'), findsOneWidget);

    // Filter to Spices & Herbs
    final spicesChip = find.text('Spices & Herbs');
    expect(spicesChip, findsOneWidget);
    await tester.tap(spicesChip);
    await tester.pumpAndSettle();

    // Only Jimbu Herb should be present
    expect(find.text('1 items'), findsOneWidget);
    expect(find.text('Jimbu Herb'), findsOneWidget);
    expect(find.text('Cauliflower'), findsNothing);
  });

  testWidgets('SeasonalKitchenScreen "See recipes" opens bottom sheet with matching recipes',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pack = createTestRegionPack();

    await tester.pumpWidget(
      MaterialApp(
        home: SeasonalKitchenScreen(
          initialPack: pack,
          currentLanguage: 'ne',
          initialRituId: 'sharad',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find "See recipes" button for Cauliflower
    final seeRecipesButtons = find.text('रेसिपी हेर्नुहोस्');
    expect(seeRecipesButtons, findsWidgets);

    await tester.tap(seeRecipesButtons.first);
    await tester.pumpAndSettle();

    // Bottom sheet should open showing matching recipe
    expect(find.text('सम्बन्धित परिकारहरू'), findsOneWidget);
    expect(find.text('आलु काउलीको तरकारी'), findsOneWidget);
    expect(find.text('Aloo Kauli Tarkari'), findsOneWidget);
    expect(find.text('२ सिट्ठी'), findsOneWidget);
  });

  testWidgets('SeasonalKitchenScreen "Add to list" adds item and shows SnackBar with Undo',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pack = createTestRegionPack();
    RegionIngredient? addedIngredient;

    await tester.pumpWidget(
      MaterialApp(
        home: SeasonalKitchenScreen(
          initialPack: pack,
          currentLanguage: 'ne',
          initialRituId: 'sharad',
          onAddToGroceryList: (ing) {
            addedIngredient = ing;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addButtons = find.text('सूचीमा थप्नुहोस्');
    expect(addButtons, findsWidgets);

    // Tap first add button (Cauliflower)
    await tester.tap(addButtons.first);
    await tester.pump();

    // Verify callback
    expect(addedIngredient, isNotNull);
    expect(addedIngredient!.id, equals('cauliflower'));

    // Verify SnackBar
    expect(find.text('थपियो: काउली (फूल गोभी) किराना सूचीमा'), findsOneWidget);
    expect(find.text('हटाउनुहोस्'), findsOneWidget);

    // Verify button transitioned to "In List" state
    expect(find.text('सूचीमा थपियो'), findsOneWidget);

    // Tap undo
    await tester.tap(find.text('हटाउनुहोस्'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Reverts to add state
    expect(find.text('सूचीमा थप्नुहोस्'), findsWidgets);
  });

  testWidgets('SeasonalKitchenScreen preservation card opens technique dialog',
      (tester) async {
    final pack = createTestRegionPack();

    await tester.pumpWidget(
      MaterialApp(
        home: SeasonalKitchenScreen(
          initialPack: pack,
          currentLanguage: 'ne',
          initialRituId: 'sharad',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify preservation section title
    expect(find.text('परम्परागत संरक्षण र अचार सिफारिस'), findsOneWidget);

    // Tap preservation card
    final gundrukCard = find.text('गुन्द्रुक बनाउने मौसम (किण्वन)');
    expect(gundrukCard, findsOneWidget);

    await tester.ensureVisible(gundrukCard);
    await tester.tap(gundrukCard);
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('विधि (Method):'), findsOneWidget);
    expect(find.text('Lactic acid fermentation & sun-drying'), findsOneWidget);
    expect(find.text('बन्द गर्नुहोस्'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('बन्द गर्नुहोस्'));
    await tester.pumpAndSettle();
    expect(find.text('विधि (Method):'), findsNothing);
  });

  testWidgets('KitchenHomeScreen switches to Discover tab and displays SeasonalKitchenScreen',
      (tester) async {
    final pack = createTestRegionPack();
    RegionPackRepository().setPack(pack);

    await tester.pumpWidget(
      MaterialApp(
        home: KitchenHomeScreen(
          preferences: OnboardingPreferences(),
          onResetOnboarding: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially in Kitchen tab (Whistle counter hero card)
    expect(find.text('सिट्ठी संख्या'), findsOneWidget);
    expect(find.text('खोज्नुहोस्'), findsOneWidget);

    // Switch to Discover tab
    await tester.tap(find.text('खोज्नुहोस्'));
    await tester.pumpAndSettle();

    // Now in SeasonalKitchenScreen
    expect(find.text('सिजनल भान्सा'), findsOneWidget);
  });
}
