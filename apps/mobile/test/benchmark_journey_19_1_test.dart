import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:siti_counter/groceries/market_mode_screen.dart';
import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/planner/planner_repository.dart';
import 'package:siti_counter/screens/active_cooking_session_screen.dart';
import 'package:siti_counter/screens/seasonal_kitchen_screen.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

RegionPack createBenchmarkRegionPack() {
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
        signatureProduce: ['काउली', 'मूला', 'पालुङ्गो'],
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
      id: 'tomato',
      nameEn: 'Tomato',
      nameNe: 'गोलभेंडा',
      aliases: ['tamatar'],
      category: 'vegetables',
      standardUnit: 'pau',
      marketPackageGrams: 250,
      storageDays: 7,
      allergens: [],
      availability: {
        'sharad': 'peak',
        'hemanta': 'available',
      },
    ),
  ];

  final recipes = [
    const RegionRecipe(
      id: 'aloo-gobi-tarkari',
      titleEn: 'Potato & Cauliflower Curry (Aloo Gobi)',
      titleNe: 'आलु काउलीको तरकारी',
      category: 'tarkari',
      cuisine: 'pan-nepali',
      dietary: ['vegetarian', 'gluten-free'],
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 4,
      difficulty: 'easy',
      pressureCooker: RecipeWhistleProfile(
        enabled: true,
        recommendedWhistles: 1,
        altitudeWhistleOffsetKathmandu: 1,
        heatLevel: 'medium',
        releaseType: 'natural',
      ),
      ingredients: [
        RecipeIngredientItem(ingredientId: 'cauliflower', quantity: 1000, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'potato', quantity: 500, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'tomato', quantity: 500, unit: 'g'),
      ],
      seasonality: ['sharad', 'hemanta'],
      tags: ['everyday', 'dal-bhat', 'seasonal'],
    ),
  ];

  return RegionPack(
    manifest: manifest,
    seasonality: seasonality,
    ingredients: ingredients,
    recipes: recipes,
    festivals: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late RegionPack pack;

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Benchmark User Journey 19.1 - Kathmandu Seasonal Dinner (P0 Gate)', () {
    testWidgets(
        'completes full loop 100% offline: seasonal produce -> planner -> grocery -> market mode -> cooking session -> batch yield',
        (tester) async {
      setPhoneSize(tester);

      final db = (await tester.runAsync(() async {
        final d = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await WeeklyPlannerRepository.createTables(d);
        return d;
      }))!;
      final plannerRepo = WeeklyPlannerRepository(db);
      addTearDown(() async {
        await tester.runAsync(() => db.close());
      });

      pack = createBenchmarkRegionPack();

      // =======================================================================
      // STEP 1: Home Screen displays seasonal Bagmati produce (cauliflower, potato, tomato)
      // =======================================================================
      final alooGobi = pack.recipes.firstWhere((r) => r.id == 'aloo-gobi-tarkari');
      expect(alooGobi.titleEn, contains('Aloo Gobi'));
      expect(alooGobi.titleNe, equals('आलु काउलीको तरकारी'));

      RegionRecipe? selectedRecipe;

      // Render SeasonalKitchenScreen with Bagmati pack in Sharad ritu
      await tester.pumpWidget(
        MaterialApp(
          home: SeasonalKitchenScreen(
            initialPack: pack,
            initialRituId: 'sharad',
            currentLanguage: 'ne',
            onRecipeSelected: (recipe) => selectedRecipe = recipe,
          ),
        ),
      );
      await settle(tester);

      // Seasonal produce rendered on home screen
      expect(find.text('सिजनल भान्सा'), findsOneWidget);
      expect(find.text('काउली (फूल गोभी)'), findsOneWidget);
      expect(find.text('Cauliflower'), findsOneWidget);

      // User taps 'रेसिपी हेर्नुहोस्' (See Recipes) for cauliflower
      final seeRecipesButtons = find.text('रेसिपी हेर्नुहोस्');
      expect(seeRecipesButtons, findsWidgets);
      await tester.tap(seeRecipesButtons.first);
      await settle(tester);

      // Related recipes sheet opens with Aloo Gobi
      expect(find.text('सम्बन्धित परिकारहरू'), findsOneWidget);
      expect(find.text('आलु काउलीको तरकारी'), findsWidgets);

      // Tap on Aloo Gobi
      await tester.tap(find.text('आलु काउलीको तरकारी').last);
      await settle(tester);
      expect(selectedRecipe?.id, equals('aloo-gobi-tarkari'));

      // =======================================================================
      // STEP 2: Add Aloo Gobi to Thursday Dinner in Planner
      // =======================================================================
      final thursday = DateTime(2026, 10, 8); // Thursday
      const slotId = 'dinner';

      final plannedMeal = PlannedMeal(
        id: 'thursday_dinner_aloo_gobi',
        dateIso: '${thursday.year}-${thursday.month.toString().padLeft(2, '0')}-${thursday.day.toString().padLeft(2, '0')}',
        slotId: slotId,
        recipeId: alooGobi.id,
        recipeTitleEn: alooGobi.titleEn,
        recipeTitleNe: alooGobi.titleNe,
        servings: 4,
        isSeasonal: true,
        dietaryBadges: alooGobi.dietary,
      );

      // Persist planned meal strictly offline in SQLite
      await tester.runAsync(() => plannerRepo.savePlannedMeal(plannedMeal));

      final weekMeals = (await tester.runAsync(() => plannerRepo.getPlannedMealsForWeek(DateTime(2026, 10, 5))))!;
      expect(weekMeals.length, equals(1));
      expect(weekMeals.first.recipeId, equals('aloo-gobi-tarkari'));
      expect(weekMeals.first.servings, equals(4));

      // =======================================================================
      // STEP 3: Grocery List Generation with Wet Market Stall Grouping
      // =======================================================================
      final mealInputs = weekMeals.map((m) {
        return GroceryPlanMealInput(
          recipeId: m.recipeId,
          servings: m.servings,
          recipeTitleEn: m.recipeTitleEn,
          recipeTitleNe: m.recipeTitleNe,
          dateIso: m.dateIso,
          slotId: m.slotId,
        );
      }).toList();

      final groceryResult = generateGroceryListFromRegion(
        meals: mealInputs,
        recipes: pack.recipes,
        ingredients: pack.ingredients,
        pantryAvailableGrams: {}, // Empty pantry at start
      );

      expect(groceryResult.totalItems, equals(3));

      // Verify cauliflower: 1 kg, potato: 2 pau (500 g), tomato: 2 pau (500 g)
      final cauliflowerItem =
          groceryResult.items.firstWhere((i) => i.ingredientId == 'cauliflower');
      final potatoItem = groceryResult.items.firstWhere((i) => i.ingredientId == 'potato');
      final tomatoItem = groceryResult.items.firstWhere((i) => i.ingredientId == 'tomato');

      expect(cauliflowerItem.stall, equals(MarketStall.vegetables));
      expect(cauliflowerItem.vendorUnitLabelEn, equals('1 kg'));
      expect(potatoItem.stall, equals(MarketStall.vegetables));
      expect(potatoItem.vendorUnitLabelEn, equals('2 pau (500 g)'));
      expect(tomatoItem.stall, equals(MarketStall.vegetables));
      expect(tomatoItem.vendorUnitLabelEn, equals('2 pau (500 g)'));

      // =======================================================================
      // STEP 4: Market Mode Checklist at Haat Bazaar -> Shifts Items to Pantry
      // =======================================================================
      await tester.pumpWidget(
        MaterialApp(
          home: MarketModeScreen(
            groceryResult: groceryResult,
            repository: plannerRepo,
            currentLanguage: 'ne',
          ),
        ),
      );
      await settle(tester);

      expect(find.text('MARKET'), findsOneWidget);
      expect(find.text('बजार मोड (चेकलिस्ट)'), findsOneWidget);

      // Check off cauliflower at wet market
      final cauliflowerTile = find.byKey(const Key('market_item_cauliflower'));
      expect(cauliflowerTile, findsOneWidget);
      await tester.tap(cauliflowerTile);
      await settle(tester);

      // Check off potato at wet market
      final potatoTile = find.byKey(const Key('market_item_potato'));
      expect(potatoTile, findsOneWidget);
      await tester.tap(potatoTile);
      await settle(tester);

      // Check off tomato at wet market
      final tomatoTile = find.byKey(const Key('market_item_tomato'));
      expect(tomatoTile, findsOneWidget);
      await tester.tap(tomatoTile);
      await settle(tester);

      // Verify items were persisted to SQLite pantry items table
      final updatedPantry = (await tester.runAsync(() => plannerRepo.getPantryItems()))!;
      expect(updatedPantry.containsKey('cauliflower'), isTrue);
      expect(updatedPantry['cauliflower'], equals(1000.0));
      expect(updatedPantry.containsKey('potato'), isTrue);
      expect(updatedPantry['potato'], equals(500.0));
      expect(updatedPantry.containsKey('tomato'), isTrue);
      expect(updatedPantry['tomato'], equals(500.0));

      // =======================================================================
      // STEP 5: Thursday Cooking Alert fires -> Siti Counter Whistle Detection
      // =======================================================================
      // Target whistles for Kathmandu (1400m):
      // 1 recommended base + 1 altitude offset = 2 whistles
      final baseWhistles = alooGobi.pressureCooker.recommendedWhistles;
      final altitudeOffset = alooGobi.pressureCooker.altitudeWhistleOffsetKathmandu;
      final targetWhistles = baseWhistles + altitudeOffset;
      expect(targetWhistles, equals(2));

      bool sessionFinished = false;
      int cookedBatchServings = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveCookingSessionScreen(
            recipe: alooGobi,
            targetWhistles: targetWhistles,
            currentLanguage: 'ne',
            initialWhistles: 0,
            onSessionComplete: () {
              sessionFinished = true;
              cookedBatchServings = alooGobi.servings;
            },
          ),
        ),
      );
      await settle(tester);

      // Verify active cooking screen rendered with recipe title and 2 whistle target
      expect(find.text('आलु काउलीको तरकारी'), findsOneWidget);
      expect(find.text('२'), findsWidgets); // Target whistles in Devanagari

      // Simulate First Whistle (+1 increment)
      final plusBtn = find.text('+१ सिट्ठी (+1 Siti)');
      expect(plusBtn, findsOneWidget);
      await tester.tap(plusBtn);
      await settle(tester);

      // Dial displays 1 whistle
      expect(find.text('१'), findsWidgets);
      expect(sessionFinished, isFalse);

      // Simulate Second Whistle -> Target whistles reached!
      await tester.tap(plusBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Whistle target reached! Alarm triggers
      expect(find.textContaining('सिट्ठी पुग्यो! आगो बन्द गर्नुहोस्'), findsOneWidget);

      // =======================================================================
      // STEP 6: Meal Finishes -> Logs Batch Yield
      // =======================================================================
      // Stop the alarm
      final stopAlarmBtn = find.text('अलार्म बन्द');
      expect(stopAlarmBtn, findsOneWidget);
      await tester.tap(stopAlarmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Finish cooking
      final finishBtn = find.text('खाना तयार भयो');
      await tester.ensureVisible(finishBtn);
      await tester.tap(finishBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Session completes successfully and yields 4 servings
      expect(sessionFinished, isTrue);
      expect(cookedBatchServings, equals(4));

      // =======================================================================
      // STEP 7: 100% Executed Offline
      // =======================================================================
      // Verify final meal state and pantry retention in SQLite:
      final finalMeals = (await tester.runAsync(() => plannerRepo.getPlannedMealsForWeek(DateTime(2026, 10, 5))))!;
      expect(finalMeals.length, equals(1));
      final finalPantry = (await tester.runAsync(() => plannerRepo.getPantryItems()))!;
      expect(finalPantry.length, equals(3));
    });
  });
}
