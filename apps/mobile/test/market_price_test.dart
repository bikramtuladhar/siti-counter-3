import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:siti_counter/commerce/market_price_board_screen.dart';
import 'package:siti_counter/commerce/market_price_service.dart';
import 'package:siti_counter/data/region_pack_repository.dart';
import 'package:siti_counter/groceries/grocery_list_screen.dart';
import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/planner/planner_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MarketCommodity & MarketPriceService Unit Tests', () {
    test('MarketCommodity JSON serialization and isBudgetHero computation', () {
      final commodity = MarketCommodity(
        id: 'kalimati_cauli',
        commodityId: 'cauliflower',
        nameEn: 'Cauliflower Local',
        nameNe: 'काउली स्थानीय',
        category: 'vegetables',
        unit: 'kg',
        minPrice: 40,
        maxPrice: 50,
        avgPrice: 45,
        priceTrend: 'falling',
        date: '2026-10-04',
        nepaliDate: '२०८३-०६-१८',
      );

      expect(commodity.isBudgetHero, isTrue);
      expect(commodity.toJson()['commodityId'], 'cauliflower');
      expect(commodity.toJson()['avgPrice'], 45);

      final fromJson = MarketCommodity.fromJson(commodity.toJson());
      expect(fromJson.commodityId, 'cauliflower');
      expect(fromJson.avgPrice, 45);
      expect(fromJson.priceTrend, 'falling');
    });

    test('MarketPriceService default seed prices, filters and budget heroes', () {
      final service = MarketPriceService();
      expect(service.commodities.isNotEmpty, isTrue);
      expect(service.lastUpdated.isNotEmpty, isTrue);

      // Verify category filter
      final greens = service.filterCommodities(category: 'greens');
      expect(greens.every((c) => c.category == 'greens'), isTrue);
      expect(greens.length, greaterThanOrEqualTo(2));

      // Verify search by Nepali text
      final potatoNe = service.filterCommodities(search: 'आलु');
      expect(potatoNe.isNotEmpty, isTrue);
      expect(potatoNe.first.commodityId, 'potato');

      // Verify search by English text
      final tomatoEn = service.filterCommodities(search: 'tomato');
      expect(tomatoEn.isNotEmpty, isTrue);
      expect(tomatoEn.first.commodityId, 'tomato');

      // Budget heroes
      final heroes = service.getBudgetHeroes();
      expect(heroes.isNotEmpty, isTrue);
      expect(heroes.any((c) => c.commodityId == 'cauliflower' || c.commodityId == 'tomato'), isTrue);

      // Conversion to engine map
      final engineMap = service.toEnginePricesMap();
      expect(engineMap.containsKey('potato'), isTrue);
      expect(engineMap['potato']!.avgPrice, greaterThan(0));
    });

    test('MarketPriceService crowdsource price updates trend and average', () {
      final service = MarketPriceService();
      final originalTomato = service.commodities.firstWhere((c) => c.commodityId == 'tomato');
      final originalAvg = originalTomato.avgPrice;

      bool notified = false;
      service.addListener(() => notified = true);

      // Record a higher observed price at local bazaar
      service.recordCrowdsourcedPrice(
        marketName: 'Asan Bazaar',
        commodityId: 'tomato',
        observedPrice: 90,
      );

      expect(notified, isTrue);
      final updatedTomato = service.commodities.firstWhere((c) => c.commodityId == 'tomato');
      expect(updatedTomato.avgPrice, greaterThan(originalAvg));
      expect(updatedTomato.priceTrend, 'rising');
    });
  });

  group('MarketPriceBoardScreen Widget Tests', () {
    testWidgets('Renders market price board with Kalimati header, Budget heroes, and items',
        (tester) async {
      final service = MarketPriceService();

      await tester.pumpWidget(
        MaterialApp(
          home: MarketPriceBoardScreen(
            marketPriceService: service,
            currentLanguage: 'ne',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify AppBar and header
      expect(find.text('कालिमाटी दैनिक बजार भाउ'), findsOneWidget);
      expect(find.text('कालिमाटी फलफूल तथा तरकारी विकास समिति'), findsOneWidget);
      expect(find.text('प्रमाणित'), findsOneWidget);

      // 2. Verify Budget Hero carousel is visible
      expect(find.textContaining('बजेट हिरो'), findsWidgets);

      // 3. Verify category chips
      expect(find.text('सबै'), findsOneWidget);
      expect(find.text('तरकारी'), findsOneWidget);
      expect(find.text('सागपात'), findsOneWidget);
      expect(find.text('मसला'), findsOneWidget);

      // 4. Tap 'सागपात' (Greens) filter chip
      await tester.tap(find.byKey(const Key('cat_chip_greens')));
      await tester.pumpAndSettle();

      // Only greens should be visible
      expect(find.text('पालुङ्गो साग'), findsOneWidget);
      expect(find.text('रायो साग'), findsOneWidget);
      expect(find.text('आलु रातो'), findsNothing);

      // 5. Test search input
      await tester.tap(find.byKey(const Key('cat_chip_all')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('market_search_input')), 'काउली');
      await tester.pumpAndSettle();

      expect(find.text('काउली स्थानीय'), findsOneWidget);
      expect(find.text('आलु रातो'), findsNothing);
    });

    testWidgets('Opens crowdsourced price modal and submits new rate', (tester) async {
      final service = MarketPriceService();

      await tester.pumpWidget(
        MaterialApp(
          home: MarketPriceBoardScreen(
            marketPriceService: service,
            currentLanguage: 'ne',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap Floating Action Button to report price
      final fab = find.byKey(const Key('report_price_fab'));
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // 2. Bottom sheet visible
      expect(find.text('स्थानीय बजार भाउ रिपोर्ट'), findsOneWidget);
      expect(find.byKey(const Key('crowdsource_price_input')), findsOneWidget);

      // 3. Enter observed rate 35 NPR/kg
      await tester.enterText(find.byKey(const Key('crowdsource_price_input')), '35');
      await tester.pumpAndSettle();

      // 4. Tap submit
      await tester.tap(find.byKey(const Key('crowdsource_submit_btn')));
      await tester.pumpAndSettle();

      // 5. Success SnackBar shown
      expect(find.textContaining('बजार भाउ सफलतापूर्वक रिपोर्ट भयो'), findsOneWidget);
    });
  });

  group('GroceryListScreen Market Price Integration', () {
    testWidgets('GroceryListScreen displays Budget Hero and market price indicators on produce',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = (await tester.runAsync(() async {
        final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await WeeklyPlannerRepository.createTables(db);
        final r = WeeklyPlannerRepository(db);
        await r.savePlannedMeal(
          const PlannedMeal(
            id: 'meal_1',
            dateIso: '2026-10-04',
            slotId: 'dinner',
            recipeId: 'alu_cauli_tarkari',
            recipeTitleEn: 'Aloo Cauli Tarkari',
            recipeTitleNe: 'आलु काउली तरकारी',
            servings: 4,
          ),
        );
        return r;
      }))!;

      final testPack = RegionPack(
        manifest: const RegionPackManifest(
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
        ),
        seasonality: const RegionSeasonality(
          regionId: 'nepal-bagmati',
          ritus: [],
        ),
        ingredients: const [
          RegionIngredient(
            id: 'potato',
            nameEn: 'Potato',
            nameNe: 'आलु',
            aliases: ['alu'],
            category: 'vegetables',
            standardUnit: 'pau',
            marketPackageGrams: 250,
            storageDays: 14,
            allergens: [],
            availability: {},
          ),
          RegionIngredient(
            id: 'cauliflower',
            nameEn: 'Cauliflower',
            nameNe: 'काउली',
            aliases: ['gobi'],
            category: 'vegetables',
            standardUnit: 'kg',
            marketPackageGrams: 1000,
            storageDays: 5,
            allergens: [],
            availability: {},
          ),
        ],
        recipes: const [
          RegionRecipe(
            id: 'alu_cauli_tarkari',
            titleEn: 'Aloo Cauli Tarkari',
            titleNe: 'आलु काउली तरकारी',
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
              releaseType: 'quick',
            ),
            seasonality: [],
          ),
        ],
        festivals: const [],
        preservationSuggestions: const [],
      );

      final regionRepo = RegionPackRepository();
      regionRepo.setPack(testPack);

      final weekStart = DateTime(2026, 10, 4);
      final marketService = MarketPriceService();

      await tester.pumpWidget(
        MaterialApp(
          home: GroceryListScreen(
            weekStart: weekStart,
            repository: repo,
            regionPackRepository: regionRepo,
            marketPriceService: marketService,
            currentLanguage: 'ne',
          ),
        ),
      );

      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify grocery item rendered
      expect(find.text('आलु'), findsOneWidget);
      expect(find.text('काउली'), findsOneWidget);

      // Verify market price indicators
      expect(find.textContaining('बजेट हिरो ⭐'), findsWidgets);
      expect(find.textContaining('अनुमानित: रु'), findsWidgets);
    });
  });
}
