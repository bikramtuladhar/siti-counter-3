import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:siti_counter/data/region_pack_repository.dart';
import 'package:siti_counter/groceries/grocery_list_screen.dart';
import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/planner/planner_repository.dart';
import 'package:siti_counter/planner/weekly_planner_screen.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const testManifest = RegionPackManifest(
    id: 'nepal-bagmati',
    version: '1.0.0',
    name: 'Bagmati',
    country: 'Nepal',
    countryCode: 'NP',
    region: 'Bagmati',
    status: 'beta',
    elevationMeters: 1400,
    defaultLanguage: 'ne',
    calendar: 'bikram-sambat',
    seasonSystem: 'six-ritus',
  );

  final testSeasonality = RegionSeasonality(
    regionId: 'nepal-bagmati',
    ritus: const [
      RituSeason(
        id: 'sharad',
        name: 'शरद (Sharad)',
        monthsBS: ['Ashwin', 'Kartik'],
        monthsGregorian: ['September', 'October'],
        signatureProduce: ['फूल गोभी', 'मूला', 'पालुङ्गो'],
      ),
    ],
  );

  final testIngredients = [
    const RegionIngredient(
      id: 'potato',
      nameEn: 'Potato',
      nameNe: 'आलु',
      aliases: ['alu'],
      category: 'vegetables',
      standardUnit: 'pau',
      marketPackageGrams: 250,
      storageDays: 14,
      allergens: [],
      availability: {'sharad': 'in_season'},
    ),
    const RegionIngredient(
      id: 'cauliflower',
      nameEn: 'Cauliflower',
      nameNe: 'काउली',
      aliases: ['gobi'],
      category: 'vegetables',
      standardUnit: 'kg',
      marketPackageGrams: 1000,
      storageDays: 5,
      allergens: [],
      availability: {'sharad': 'peak'},
    ),
    const RegionIngredient(
      id: 'kalo_dal',
      nameEn: 'Black Lentil',
      nameNe: 'कालो दाल (मास)',
      aliases: ['urad'],
      category: 'pulses',
      standardUnit: 'mana',
      marketPackageGrams: 400,
      storageDays: 180,
      allergens: [],
      availability: {'sharad': 'available'},
    ),
    const RegionIngredient(
      id: 'jimbu',
      nameEn: 'Himalayan Aromatic Herb',
      nameNe: 'जिम्बु',
      aliases: [],
      category: 'spices',
      standardUnit: 'packet',
      marketPackageGrams: 50,
      storageDays: 365,
      allergens: [],
      availability: {'sharad': 'available'},
    ),
    const RegionIngredient(
      id: 'goat_meat',
      nameEn: 'Mutton / Khasi Ko Masu',
      nameNe: 'खसीको मासु',
      aliases: ['goat'],
      category: 'meat',
      standardUnit: 'kg',
      marketPackageGrams: 1000,
      storageDays: 2,
      allergens: [],
      availability: {'sharad': 'available'},
    ),
  ];

  final testRecipes = [
    const RegionRecipe(
      id: 'aloo-cauli',
      titleEn: 'Aloo Cauli Tarkari',
      titleNe: 'आलु काउलीको तरकारी',
      category: 'curry',
      cuisine: 'pan-nepali',
      prepTimeMinutes: 15,
      cookTimeMinutes: 20,
      servings: 4,
      difficulty: 'easy',
      costEstimateNpr: 180,
      dietary: ['vegetarian', 'vegan'],
      tags: ['curry'],
      ingredients: [
        RecipeIngredientItem(ingredientId: 'potato', quantity: 500, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'cauliflower', quantity: 500, unit: 'g'),
      ],
      pressureCooker: RecipeWhistleProfile(
        enabled: true,
        recommendedWhistles: 2,
        altitudeWhistleOffsetKathmandu: 0,
        heatLevel: 'medium',
        releaseType: 'natural',
      ),
      seasonality: ['sharad'],
    ),
    const RegionRecipe(
      id: 'kalo-dal',
      titleEn: 'Kalo Dal with Jimbu',
      titleNe: 'जिम्बु झानेको कालो दाल',
      category: 'dal',
      cuisine: 'pan-nepali',
      prepTimeMinutes: 10,
      cookTimeMinutes: 25,
      servings: 4,
      difficulty: 'medium',
      costEstimateNpr: 120,
      dietary: ['vegetarian', 'gluten_free'],
      tags: ['dal'],
      ingredients: [
        RecipeIngredientItem(ingredientId: 'kalo_dal', quantity: 400, unit: 'g'),
        RecipeIngredientItem(ingredientId: 'jimbu', quantity: 15, unit: 'g'),
      ],
      pressureCooker: RecipeWhistleProfile(
        enabled: true,
        recommendedWhistles: 4,
        altitudeWhistleOffsetKathmandu: 1,
        heatLevel: 'low',
        releaseType: 'natural',
      ),
      seasonality: ['sharad'],
    ),
  ];

  final testPack = RegionPack(
    manifest: testManifest,
    seasonality: testSeasonality,
    ingredients: testIngredients,
    recipes: testRecipes,
    festivals: const [],
    preservationSuggestions: const [],
  );

  setUp(() {
    RegionPackRepository().setPack(testPack);
  });

  Future<WeeklyPlannerRepository> makeRepo(WidgetTester tester) async {
    final repo = await tester.runAsync(() async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await WeeklyPlannerRepository.createTables(db);
      return WeeklyPlannerRepository(db);
    });
    return repo!;
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget hostGroceryScreen({
    required WeeklyPlannerRepository repo,
    String language = 'ne',
    DateTime? weekStart,
  }) {
    return MaterialApp(
      home: GroceryListScreen(
        weekStart: weekStart ?? DateTime(2026, 10, 4),
        repository: repo,
        currentLanguage: language,
      ),
    );
  }

  group('GroceryListScreen Widget Tests', () {
    testWidgets('shows empty state when no meals planned for the week', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(hostGroceryScreen(repo: repo));
      await settle(tester);

      expect(find.text('यस हप्ताको कुनै भोजन योजना छैन'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);
    });

    testWidgets('renders aggregated grocery items grouped by stalls with vendor units', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      // Seed planned meals for this week
      await tester.runAsync(() async {
        await repo.savePlannedMeal(
          const PlannedMeal(
            id: 'm1',
            dateIso: '2026-10-04',
            slotId: 'morning-dal-bhat',
            recipeId: 'aloo-cauli',
            recipeTitleEn: 'Aloo Cauli Tarkari',
            recipeTitleNe: 'आलु काउलीको तरकारी',
            servings: 4,
          ),
        );
        await repo.savePlannedMeal(
          const PlannedMeal(
            id: 'm2',
            dateIso: '2026-10-05',
            slotId: 'morning-dal-bhat',
            recipeId: 'kalo-dal',
            recipeTitleEn: 'Kalo Dal with Jimbu',
            recipeTitleNe: 'जिम्बु झानेको कालो दाल',
            servings: 4,
          ),
        );
      });

      await tester.pumpWidget(hostGroceryScreen(repo: repo));
      await settle(tester);

      // Verify Screen Header
      expect(find.text('किनमेल सूची (हाट बजार)'), findsOneWidget);

      // Verify Summary Metrics
      expect(find.byKey(const Key('metric_to_buy')), findsOneWidget);
      expect(find.byKey(const Key('metric_in_pantry')), findsOneWidget);

      // Verify Stall Headers exist in Haat Bazaar order
      expect(find.textContaining('तरकारी गल्ली'), findsOneWidget);
      expect(find.textContaining('खाद्यान्न तथा दाल-चामल'), findsOneWidget);
      expect(find.textContaining('मसला गल्ली'), findsOneWidget);

      // Verify Items with Devanagari & vendor unit badges
      expect(find.text('आलु'), findsOneWidget);
      expect(find.text('काउली'), findsOneWidget);
      expect(find.text('कालो दाल (मास)'), findsOneWidget);

      // Vendor units: 500g potato in 250g pau = 2 pau
      expect(find.textContaining('२ पाउ'), findsOneWidget);
      // 500g cauli in 1000g kg pkg = 1 kg
      expect(find.textContaining('१ के.जी.'), findsOneWidget);
      // 400g kalo dal in 400g mana pkg = 1 mana
      expect(find.textContaining('१ माना'), findsOneWidget);

      // Market mode bottom button
      expect(find.byKey(const Key('open_market_mode_btn')), findsOneWidget);
    });

    testWidgets('filters items when tapping stall filter chips', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.runAsync(() async {
        await repo.savePlannedMeal(
          const PlannedMeal(
            id: 'm1',
            dateIso: '2026-10-04',
            slotId: 'morning-dal-bhat',
            recipeId: 'aloo-cauli',
            recipeTitleEn: 'Aloo Cauli Tarkari',
            recipeTitleNe: 'आलु काउलीको तरकारी',
            servings: 4,
          ),
        );
        await repo.savePlannedMeal(
          const PlannedMeal(
            id: 'm2',
            dateIso: '2026-10-05',
            slotId: 'morning-dal-bhat',
            recipeId: 'kalo-dal',
            recipeTitleEn: 'Kalo Dal with Jimbu',
            recipeTitleNe: 'जिम्बु झानेको कालो दाल',
            servings: 4,
          ),
        );
      });

      await tester.pumpWidget(hostGroceryScreen(repo: repo));
      await settle(tester);

      // Tap on Spices filter chip
      final spiceFilter = find.byKey(const Key('stall_filter_spices'));
      expect(spiceFilter, findsOneWidget);
      await tester.tap(spiceFilter);
      await tester.pump();

      // Only spices should be displayed
      expect(find.text('जिम्बु'), findsOneWidget);
      expect(find.text('आलु'), findsNothing);

      // Tap on "All" filter chip
      final allFilter = find.byKey(const Key('stall_filter_all'));
      await tester.tap(allFilter);
      await tester.pump();

      expect(find.text('आलु'), findsOneWidget);
      expect(find.text('जिम्बु'), findsOneWidget);
    });

    testWidgets('toggling item checkbox persists in pantry and recalculates net needed', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.runAsync(() async {
        await repo.savePlannedMeal(
          const PlannedMeal(
            id: 'm1',
            dateIso: '2026-10-04',
            slotId: 'morning-dal-bhat',
            recipeId: 'aloo-cauli',
            recipeTitleEn: 'Aloo Cauli Tarkari',
            recipeTitleNe: 'आलु काउलीको तरकारी',
            servings: 4,
          ),
        );
      });

      await tester.pumpWidget(hostGroceryScreen(repo: repo));
      await settle(tester);

      // Tap checkbox for potato to mark as in pantry
      final potatoCheckbox = find.byKey(const Key('item_pantry_check_potato'));
      expect(potatoCheckbox, findsOneWidget);
      await tester.tap(potatoCheckbox);
      await settle(tester);

      // Verify in-pantry metric increased in SQLite
      final pantryItems = await tester.runAsync(() => repo.getPantryItems());
      expect(pantryItems?['potato'], equals(500.0));
    });

    testWidgets('toggles language between Devanagari and English', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.runAsync(() async {
        await repo.savePlannedMeal(
          const PlannedMeal(
            id: 'm1',
            dateIso: '2026-10-04',
            slotId: 'morning-dal-bhat',
            recipeId: 'aloo-cauli',
            recipeTitleEn: 'Aloo Cauli Tarkari',
            recipeTitleNe: 'आलु काउलीको तरकारी',
            servings: 4,
          ),
        );
      });

      await tester.pumpWidget(hostGroceryScreen(repo: repo, language: 'ne'));
      await settle(tester);

      expect(find.text('किनमेल सूची (हाट बजार)'), findsOneWidget);

      // Tap EN button
      final langBtn = find.byKey(const Key('toggle_language_btn'));
      await tester.tap(langBtn);
      await tester.pump();

      expect(find.text('Weekly Grocery List'), findsOneWidget);
      expect(find.text('Potato'), findsOneWidget);
    });

    testWidgets('WeeklyPlannerScreen navigation button opens GroceryListScreen', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: WeeklyPlannerScreen(
            repository: repo,
            currentLanguage: 'ne',
            initialWeekStart: DateTime(2026, 10, 4),
          ),
        ),
      );
      await settle(tester);

      // Tap shopping basket button in AppBar
      final groceryBtn = find.byKey(const Key('open_grocery_list_btn'));
      expect(groceryBtn, findsOneWidget);
      await tester.tap(groceryBtn);
      await settle(tester);

      expect(find.byType(GroceryListScreen), findsOneWidget);
    });
  });
}
