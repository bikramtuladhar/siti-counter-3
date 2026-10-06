import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import 'package:siti_counter/consumption/consumption_repository.dart';
import 'package:siti_counter/consumption/post_meal_usual_dialog.dart';
import 'package:siti_counter/consumption/vessel_portion_adjuster_dialog.dart';
import 'package:siti_counter/consumption/household_vessel_calibration_dialog.dart';
import 'package:siti_counter/consumption/quick_add_outside_food_dialog.dart';
import 'package:siti_counter/consumption/consumption_dashboard_screen.dart';
import 'package:siti_counter/consumption/family_nutrition_screen.dart';
import 'package:kitchen_engine/nutrition_engine.dart';
import 'package:kitchen_engine/region_pack.dart';

/// sqflite FFI performs real async I/O, which never completes inside the
/// fake-async zone of testWidgets. Let real I/O finish, then pump the frame.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ConsumptionRepository> makeRepo(WidgetTester tester) async {
  final repo = await tester.runAsync(() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await ConsumptionRepository.createTables(db);
    return ConsumptionRepository(db);
  });
  return repo!;
}


/// Minimal pack whose recipes carry real, differing ingredients, so a test can tell two meals
/// apart by their nutrients.
RegionPack _packWithRecipe({
  required String id,
  required List<(String, double, String)> ingredients,
}) =>
    RegionPack(
      manifest: const RegionPackManifest(
        id: 'test-pack',
        version: '1.0.0',
        name: 'Test',
        country: 'Nepal',
        countryCode: 'NP',
        region: 'Bagmati',
        status: 'active',
        elevationMeters: 1400,
        defaultLanguage: 'ne',
        calendar: 'bikram-sambat',
        seasonSystem: 'six-ritus',
      ),
      seasonality: const RegionSeasonality(regionId: 'test-pack', ritus: []),
      ingredients: const [],
      festivals: const [],
      recipes: [
        RegionRecipe(
          id: id,
          titleEn: id,
          titleNe: id,
          category: 'main',
          cuisine: 'nepali',
          dietary: const [],
          prepTimeMinutes: 10,
          cookTimeMinutes: 20,
          servings: 4,
          difficulty: 'easy',
          pressureCooker: const RecipeWhistleProfile(
            enabled: false,
            recommendedWhistles: 0,
            altitudeWhistleOffsetKathmandu: 0,
            heatLevel: 'low',
            releaseType: 'natural',
          ),
          ingredients: [
            for (final i in ingredients)
              RecipeIngredientItem(ingredientId: i.$1, quantity: i.$2, unit: i.$3),
          ],
          steps: const [],
          seasonality: const [],
          tags: const [],
        ),
      ],
    );

final _testPack = RegionPack(
  manifest: const RegionPackManifest(
    id: 'test-pack',
    version: '1.0.0',
    name: 'Test',
    country: 'Nepal',
    countryCode: 'NP',
    region: 'Bagmati',
    status: 'active',
    elevationMeters: 1400,
    defaultLanguage: 'ne',
    calendar: 'bikram-sambat',
    seasonSystem: 'six-ritus',
  ),
  seasonality: const RegionSeasonality(regionId: 'test-pack', ritus: []),
  ingredients: const [],
  festivals: const [],
  recipes: [
    _recipe('dal-bhat', [('rice', 300.0, 'g'), ('lentil', 150.0, 'g')]),
    _recipe('thukpa', [('wheat_flour', 200.0, 'g'), ('potato', 200.0, 'g')]),
  ],
);

RegionRecipe _recipe(String id, List<(String, double, String)> ingredients) =>
    RegionRecipe(
      id: id,
      titleEn: id,
      titleNe: id,
      category: 'main',
      cuisine: 'nepali',
      dietary: const [],
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      servings: 4,
      difficulty: 'easy',
      pressureCooker: const RecipeWhistleProfile(
        enabled: false,
        recommendedWhistles: 0,
        altitudeWhistleOffsetKathmandu: 0,
        heatLevel: 'low',
        releaseType: 'natural',
      ),
      ingredients: [
        for (final i in ingredients)
          RecipeIngredientItem(ingredientId: i.$1, quantity: i.$2, unit: i.$3),
      ],
      steps: const [],
      seasonality: const [],
      tags: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final testMembers = [
    const MemberDietaryProfile(
      memberId: 'm1',
      name: 'Bikram',
      role: 'Adult',
      nutritionProfile: 'everyday',
      portionMultiplier: 1.0,
      preferredVesselId: 'plate',
      defaultVesselCount: 1.0,
    ),
    const MemberDietaryProfile(
      memberId: 'm2',
      name: 'Srijana',
      role: 'Adult',
      nutritionProfile: 'everyday',
      portionMultiplier: 0.8,
      preferredVesselId: 'katori',
      defaultVesselCount: 2.0,
    ),
    const MemberDietaryProfile(
      memberId: 'm3',
      name: 'Aayush',
      role: 'Child',
      nutritionProfile: 'child',
      portionMultiplier: 0.5,
      preferredVesselId: 'katori',
      defaultVesselCount: 1.0,
    ),
  ];

  group('ConsumptionRepository SQLite Tests', () {
    late Database db;
    late ConsumptionRepository repository;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await ConsumptionRepository.createTables(db);
      repository = ConsumptionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('initializes default household members if empty', () async {
      final members = await repository.getMembers();
      expect(members.length, equals(3));
      expect(members.any((m) => m.name == 'Bikram'), isTrue);
      expect(members.any((m) => m.name == 'Aayush' && m.isChildOrBaby), isTrue);
    });

    test('can customize household vessel volume and reset to standard', () async {
      // Calibrate katori to 180 ml
      await repository.saveVesselCalibration('katori', 180.0);
      var profile = await repository.getVesselProfile();
      expect(profile.customVolumes['katori'], equals(180.0));
      expect(profile.getEffectiveVessel('katori').volumeMl, equals(180.0));
      expect(profile.getEffectiveVessel('katori').isCustom, isTrue);

      // Reset to standard
      await repository.resetVesselCalibration('katori');
      profile = await repository.getVesselProfile();
      expect(profile.customVolumes.containsKey('katori'), isFalse);
      expect(profile.getEffectiveVessel('katori').volumeMl, equals(150.0));
    });

    test('logs home meals, outside snacks, and computes weekly household summary', () async {
      final now = DateTime(2026, 10, 15, 19, 0);
      final weekStart = DateTime(2026, 10, 11);
      final weekEnd = DateTime(2026, 10, 17);

      final mealLog = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal-bhat-tarkari',
        recipeTitle: 'Dal Bhat Tarkari',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members: testMembers,
        batchYieldGrams: 1600.0,
        leftoverGrams: 200.0,
      );
      await repository.logMeal(mealLog);

      final snackLog = ConsumptionEngine.quickAddOutsideFood(
        memberId: 'm1',
        memberName: 'Bikram',
        foodName: 'Buff Momo',
        mealSlot: 'afternoon-khaja',
        consumedAt: now,
        portionSize: 'medium',
        estimatedCalories: 380,
      );
      await repository.logOutsideFood(snackLog);

      final summary = await repository.getWeeklySummary(
        weekStart: weekStart,
        weekEnd: weekEnd,
      );

      expect(summary.totalMealsLogged, equals(1));
      expect(summary.totalOutsideSnacksLogged, equals(1));
      expect(summary.usualComplianceRate, equals(100.0));

      final bikram = summary.memberSummaries.firstWhere((m) => m.memberId == 'm1');
      expect(bikram.mealsLogged, equals(1));
      expect(bikram.snacksLogged, equals(1));
      expect(bikram.estimatedCalories, isNotNull);

      // Child calorie shield test
      final aayush = summary.memberSummaries.firstWhere((m) => m.memberId == 'm3');
      expect(aayush.mealsLogged, equals(1));
      expect(aayush.estimatedCalories, isNull);
    });
  });

  group('PostMealUsualDialog Widget Tests', () {
    testWidgets('renders prompt and confirms usual meal on one tap', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);
      MealConsumptionLog? capturedLog;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => PostMealUsualDialog(
                      recipeId: 'dal-bhat',
                      recipeTitle: 'Dal Bhat',
                      mealSlot: 'evening-dal-bhat',
                      currentLanguage: 'ne',
                      repository: repo,
                      members: testMembers,
                      onLogged: (log) => capturedLog = log,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await settle(tester);

      // Check Dialog rendered
      expect(find.text('सबैले आफ्नो सामान्य मात्रा खानुभयो?'), findsOneWidget);
      expect(find.text('Bikram'), findsOneWidget);
      expect(find.text('Srijana'), findsOneWidget);
      expect(find.text('Aayush'), findsOneWidget);
      expect(find.byKey(const Key('confirm_usual_button')), findsOneWidget);
      expect(find.byKey(const Key('adjust_portions_button')), findsOneWidget);

      // Tap One-tap confirm
      await tester.tap(find.byKey(const Key('confirm_usual_button')));
      await settle(tester);

      expect(capturedLog, isNotNull);
      expect(capturedLog!.loggedAsUsual, isTrue);
      expect(capturedLog!.recipeId, equals('dal-bhat'));

      // Verify persisted in repository
      final logs = await tester.runAsync(() => repo.getMealLogs());
      expect(logs!.length, equals(1));
      expect(logs.first.loggedAsUsual, isTrue);
    });
  });

  group('VesselPortionAdjusterDialog Widget Tests', () {
    testWidgets('adjusts vessel portions with steppers, skip toggle, and live grams', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);
      MealConsumptionLog? capturedLog;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => VesselPortionAdjusterDialog(
                      recipeId: 'dal-bhat',
                      recipeTitle: 'Dal Bhat',
                      mealSlot: 'evening-dal-bhat',
                      currentLanguage: 'en',
                      repository: repo,
                      members: testMembers,
                      onLogged: (log) => capturedLog = log,
                    ),
                  );
                },
                child: const Text('Open Adjuster'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Adjuster'));
      await settle(tester);

      expect(find.text('Adjust Meal Portions'), findsOneWidget);

      // Increase Bikram's plate from 1.0 to 1.5
      expect(find.byKey(const Key('inc_m1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inc_m1')));
      await settle(tester);

      expect(find.text('1.5'), findsOneWidget);
      // 400g * 1.5 = 600g
      expect(find.text('≈ 600 g'), findsOneWidget);

      // Toggle Srijana skipped
      await tester.tap(find.byKey(const Key('skip_checkbox_m2')));
      await settle(tester);

      // Save portions
      await tester.tap(find.byKey(const Key('save_adjusted_portions_button')));
      await settle(tester);

      expect(capturedLog, isNotNull);
      expect(capturedLog!.loggedAsUsual, isFalse);

      final pBikram = capturedLog!.memberPortions.firstWhere((p) => p.memberId == 'm1');
      expect(pBikram.vesselCount, equals(1.5));
      expect(pBikram.calculatedGrams, equals(600.0));
      expect(pBikram.ateUsual, isFalse);

      final pSrijana = capturedLog!.memberPortions.firstWhere((p) => p.memberId == 'm2');
      expect(pSrijana.skipped, isTrue);
      expect(pSrijana.calculatedGrams, equals(0.0));

      // Aayush ate usual
      final pAayush = capturedLog!.memberPortions.firstWhere((p) => p.memberId == 'm3');
      expect(pAayush.ateUsual, isTrue);
    });
  });

  group('HouseholdVesselCalibrationDialog Widget Tests', () {
    testWidgets('calibrates vessel volume and resets', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => HouseholdVesselCalibrationDialog(
                      currentLanguage: 'ne',
                      repository: repo,
                      initialProfile: const HouseholdVesselProfile(),
                    ),
                  );
                },
                child: const Text('Open Calibration'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Calibration'));
      await settle(tester);

      expect(find.text('भाँडा क्यालिब्रेसन (Vessels)'), findsOneWidget);

      // Increment katori volume (+10 ml)
      await tester.tap(find.byKey(const Key('add_10_katori')));
      await settle(tester);

      expect(find.byKey(const Key('reset_vessel_katori')), findsOneWidget);

      // Reset katori back
      await tester.tap(find.byKey(const Key('reset_vessel_katori')));
      await settle(tester);

      expect(find.byKey(const Key('reset_vessel_katori')), findsNothing);
    });
  });

  group('QuickAddOutsideFoodDialog Widget Tests', () {
    testWidgets('quick adds snack with chips and portion selection', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);
      OutsideFoodEntry? added;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => QuickAddOutsideFoodDialog(
                      currentLanguage: 'ne',
                      repository: repo,
                      members: testMembers,
                      onAdded: (e) => added = e,
                    ),
                  );
                },
                child: const Text('Open Snack'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Snack'));
      await settle(tester);

      expect(find.text('बाहिरको खाजा / स्न्याक्स'), findsOneWidget);

      // Tap chip for 'बफ म:म'
      await tester.tap(find.text('बफ म:म'));
      await settle(tester);

      expect(find.text('बफ म:म'), findsWidgets);

      // Tap save
      await tester.tap(find.byKey(const Key('save_outside_food_button')));
      await settle(tester);

      expect(added, isNotNull);
      expect(added!.foodName, equals('बफ म:म'));
      expect(added!.portionSize, equals('medium'));
    });
  });

  group('ConsumptionDashboardScreen Widget Tests', () {
    testWidgets('renders weekly calm rhythm, feedback, and shields child calories', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);
      final now = DateTime.now();
      final mealLog = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal-bhat',
        recipeTitle: 'Dal Bhat',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members: testMembers,
      );
      await tester.runAsync(() => repo.logMeal(mealLog));

      final summary = ConsumptionEngine.calculateWeeklySummary(
        weekStart: now.subtract(const Duration(days: 3)),
        weekEnd: now.add(const Duration(days: 3)),
        mealLogs: [mealLog],
        outsideLogs: [],
        members: testMembers,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConsumptionDashboardScreen(
            currentLanguage: 'ne',
            repository: repo,
            initialSummary: summary,
            initialMembers: testMembers,
          ),
        ),
      );

      await settle(tester);

      expect(find.text('पारिवारिक खाना र पोषण'), findsOneWidget);
      expect(find.text('हप्ताको शान्त लय (Calm Rhythm)'), findsOneWidget);
      expect(find.text('Bikram'), findsOneWidget);
      expect(find.text('Aayush'), findsOneWidget);

      // Check actions exist
      expect(find.byKey(const Key('calibrate_vessels_action')), findsOneWidget);
      expect(find.byKey(const Key('quick_add_snack_action')), findsOneWidget);
      expect(find.byKey(const Key('trigger_post_meal_button')), findsOneWidget);
    });
  });

  group('FamilyNutritionScreen Widget Tests', () {
    testWidgets('adults get gentle bars; children get food groups only', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);
      final logs = [
        for (var i = 0; i < 3; i++)
          ConsumptionEngine.logUsualMeal(
            recipeId: 'dal-bhat',
            recipeTitle: 'Dal Bhat',
            mealSlot: 'evening-dal-bhat',
            members: testMembers,
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: FamilyNutritionScreen(
            currentLanguage: 'en',
            repository: repo,
            initialMembers: testMembers,
            initialLogs: logs,
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Family Nutrition'), findsOneWidget);
      expect(find.byKey(const Key('bar_m1_protein')), findsOneWidget);
      expect(find.byKey(const Key('bar_m1_fiber')), findsOneWidget);
      expect(find.byKey(const Key('bar_m1_seasonal')), findsOneWidget);

      // Child: no bars, no calorie text, only food groups.
      expect(find.byKey(const Key('bar_m3_protein')), findsNothing);
      expect(find.byKey(const Key('food_groups_m3')), findsOneWidget);
      expect(find.textContaining('kcal'), findsNothing);
    });

    test('nutritionInputFromLogs skips skipped members', () {
      final log = ConsumptionEngine.logAdjustedMeal(
        recipeId: 'dal-bhat',
        recipeTitle: 'Dal Bhat',
        mealSlot: 'evening-dal-bhat',
        members: testMembers,
        adjustments: {
          'm2': (vesselId: 'katori', vesselCount: 1.0, skipped: true, notes: null),
        },
      );
      final resolve = resolverForPack(_testPack);

      expect(nutritionInputFromLogs([log], 'm2', resolve).intakes, isEmpty);
      expect(nutritionInputFromLogs([log], 'm1', resolve).intakes, hasLength(1));
      expect(NutritionEngine.yieldFor('rice'), 3.0);
    });

    test('a meal is scored from its own recipe, not a fixed reference batch', () {
      // The bug this replaces: every meal was scored as dal bhat, so logging thukpa or momo
      // produced dal bhat's numbers.
      final resolve = resolverForPack(_testPack);

      final dalBhat = ConsumptionEngine.logAdjustedMeal(
        recipeId: 'dal-bhat',
        recipeTitle: 'Dal Bhat',
        mealSlot: 'lunch',
        members: testMembers,
        adjustments: const {},
      );
      final thukpa = ConsumptionEngine.logAdjustedMeal(
        recipeId: 'thukpa',
        recipeTitle: 'Thukpa',
        mealSlot: 'lunch',
        members: testMembers,
        adjustments: const {},
      );

      final a = nutritionInputFromLogs([dalBhat], 'm1', resolve).intakes.single.nutrients;
      final b = nutritionInputFromLogs([thukpa], 'm1', resolve).intakes.single.nutrients;
      expect(a.proteinG, isNot(closeTo(b.proteinG, 0.001)));
    });

    test('an unresolvable meal is counted, not replaced with a default', () {
      // A meal logged outside the app has no recipe in the pack. It must be reported as a gap
      // rather than silently scored as something else.
      final resolve = resolverForPack(_testPack);
      final outside = ConsumptionEngine.logAdjustedMeal(
        recipeId: 'restaurant-biryani',
        recipeTitle: 'Biryani',
        mealSlot: 'dinner',
        members: testMembers,
        adjustments: const {},
      );

      final input = nutritionInputFromLogs([outside], 'm1', resolve);
      expect(input.intakes, isEmpty);
      expect(input.skippedMeals, greaterThan(0));
      expect(input.hasAnyData, isFalse);
    });

    test('partial composition coverage is flagged rather than presented as whole', () {
      // timur has no USDA entry, so the batch is legitimately partial. garlic would no longer
      // work here: it has been imported.
      final pack = _packWithRecipe(
        id: 'timur-rice',
        ingredients: const [('rice', 300.0, 'g'), ('timur', 20.0, 'g')],
      );
      final resolve = resolverForPack(pack);
      final log = ConsumptionEngine.logAdjustedMeal(
        recipeId: 'timur-rice',
        recipeTitle: 'Timur Rice',
        mealSlot: 'lunch',
        members: testMembers,
        adjustments: const {},
      );

      final input = nutritionInputFromLogs([log], 'm1', resolve);
      expect(input.anyIncomplete, isTrue);
      expect(input.skippedMeals, 0, reason: 'partial data still produces a figure');
    });
  });
}
