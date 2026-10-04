import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import 'package:kitchen_engine/waste_engine.dart';
import 'package:siti_counter/consumption/consumption_repository.dart';
import 'package:siti_counter/consumption/leftover_screen.dart';
import 'package:siti_counter/consumption/consumption_dashboard_screen.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const testMembers = [
    MemberDietaryProfile(
      memberId: 'm1',
      name: 'Bikram',
      portionMultiplier: 1.0,
      preferredVesselId: 'plate',
      defaultVesselCount: 1.0,
    ),
    MemberDietaryProfile(
      memberId: 'm2',
      name: 'Srijana',
      portionMultiplier: 0.8,
      preferredVesselId: 'katori',
      defaultVesselCount: 2.0,
    ),
  ];

  final now = DateTime(2026, 10, 5, 19, 0);

  group('ConsumptionRepository Leftover & Waste Tracking', () {
    test('auto-creates tracked leftover on meal logging with excess yield', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await ConsumptionRepository.createTables(db);
      final repo = ConsumptionRepository(db);

      final log = ConsumptionEngine.logUsualMeal(
        recipeId: 'masoor-dal',
        recipeTitle: 'Masoor Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members: testMembers,
        batchYieldGrams: 1200.0, // consumed is 640g -> excess 560g
      );

      final leftover = await repo.logMeal(log, now: now);
      expect(leftover, isNotNull);
      expect(leftover!.recipeId, equals('masoor-dal'));
      expect(leftover.remainingGrams, equals(560.0));

      final active = await repo.getTrackedLeftovers(activeOnly: true);
      expect(active.length, equals(1));
      expect(active.first.recipeId, equals('masoor-dal'));

      // Mark consumed
      await repo.markLeftoverConsumed(leftover.id, now.add(const Duration(hours: 12)));
      final remainingActive = await repo.getTrackedLeftovers(activeOnly: true);
      expect(remainingActive, isEmpty);

      final summary = await repo.getWasteSummary(now: now.add(const Duration(hours: 12)));
      expect(summary.consumedCount, equals(1));
      expect(summary.totalGramsSaved, equals(560.0));
      expect(summary.wastePreventionRate, equals(100.0));

      await db.close();
    });

    test('detects recurring waste patterns in meal logs', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await ConsumptionRepository.createTables(db);
      final repo = ConsumptionRepository(db);

      // Two consecutive Mondays with leftover dal
      final mon1 = DateTime(2026, 10, 5, 19, 30);
      final log1 = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal',
        recipeTitle: 'Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: mon1,
        members: testMembers,
        batchYieldGrams: 1400.0,
        leftoverGrams: 400.0,
      );
      await repo.logMeal(log1, now: mon1);

      final mon2 = DateTime(2026, 10, 12, 19, 30);
      final log2 = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal',
        recipeTitle: 'Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: mon2,
        members: testMembers,
        batchYieldGrams: 1400.0,
        leftoverGrams: 400.0,
      );
      await repo.logMeal(log2, now: mon2);

      final insights = await repo.getWasteInsights(minimumOccurrences: 2, now: mon2);
      expect(insights.length, equals(1));
      expect(insights.first.recipeId, equals('dal'));
      expect(insights.first.dayNameEn, equals('Monday'));
      expect(insights.first.insightEn, contains('Dal is often left over on Mondays'));

      await db.close();
    });
  });

  group('LeftoverScreen Widget Tests', () {
    testWidgets('renders "Eat First" urgent leftovers with countdown badges and actions', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      // Insert an urgent leftover
      final urgentLeftover = TrackedLeftover(
        id: 'leftover-1',
        recipeId: 'bhat',
        titleEn: 'Cooked Rice',
        titleNe: 'भात',
        servingsRemaining: 1,
        remainingGrams: 200.0,
        preparedAt: now.subtract(const Duration(hours: 34)),
        useByDate: now.add(const Duration(hours: 2)), // 2 hours remaining!
        storageCondition: StorageCondition.refrigerated,
        isConsumed: false,
        isDiscarded: false,
      );
      await tester.runAsync(() => repo.saveLeftover(urgentLeftover));

      // Insert a fresh leftover
      final freshLeftover = TrackedLeftover(
        id: 'leftover-2',
        recipeId: 'tarkari',
        titleEn: 'Aloo Gobi',
        titleNe: 'आलु काउली',
        servingsRemaining: 2,
        remainingGrams: 350.0,
        preparedAt: now.subtract(const Duration(hours: 4)),
        useByDate: now.add(const Duration(hours: 44)),
        storageCondition: StorageCondition.refrigerated,
        isConsumed: false,
        isDiscarded: false,
      );
      await tester.runAsync(() => repo.saveLeftover(freshLeftover));

      await tester.pumpWidget(
        MaterialApp(
          home: LeftoverScreen(
            currentLanguage: 'en',
            repository: repo,
            now: now,
          ),
        ),
      );
      await settle(tester);

      // Should display "Eat First" section
      expect(find.text('Eat First'), findsNWidgets(2));
      expect(find.byKey(const Key('leftover_card_leftover-1')), findsOneWidget);
      expect(find.text('Cooked Rice'), findsOneWidget);
      expect(find.text('120 min left'), findsOneWidget);

      // Should display freshly stored section
      expect(find.text('Freshly Stored Dishes'), findsOneWidget);
      expect(find.byKey(const Key('leftover_card_leftover-2')), findsOneWidget);
      expect(find.text('Aloo Gobi'), findsOneWidget);

      // Tap "Ate it ✓" on the urgent leftover
      await tester.tap(find.byKey(const Key('consumed_button_leftover-1')));
      await settle(tester);

      // SnackBar confirmation
      expect(find.text('Marked Cooked Rice as consumed: food saved ✓'), findsOneWidget);

      // Urgent item should be consumed and gone from active list
      expect(find.byKey(const Key('leftover_card_leftover-1')), findsNothing);
    });

    testWidgets('renders calm recurring waste insights with monthly savings', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      // Add two recurring Monday dal logs
      final mon1 = DateTime(2026, 10, 5, 19, 30);
      final log1 = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal',
        recipeTitle: 'Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: mon1,
        members: testMembers,
        batchYieldGrams: 1500.0,
        leftoverGrams: 500.0,
      );
      await tester.runAsync(() => repo.logMeal(log1, now: mon1));

      final mon2 = DateTime(2026, 10, 12, 19, 30);
      final log2 = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal',
        recipeTitle: 'Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: mon2,
        members: testMembers,
        batchYieldGrams: 1500.0,
        leftoverGrams: 500.0,
      );
      await tester.runAsync(() => repo.logMeal(log2, now: mon2));

      await tester.pumpWidget(
        MaterialApp(
          home: LeftoverScreen(
            currentLanguage: 'en',
            repository: repo,
            now: mon2,
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Food Waste Prevention Insights'), findsOneWidget);
      expect(find.textContaining('Dal is often left over on Mondays'), findsOneWidget);
      expect(find.textContaining('Estimated monthly savings: NPR'), findsOneWidget);
    });
  });

  group('ConsumptionDashboardScreen Leftovers Integration', () {
    testWidgets('displays leftovers banner and opens LeftoverScreen', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      // Add an active leftover
      final leftover = TrackedLeftover(
        id: 'leftover-urgent',
        recipeId: 'masoor-dal',
        titleEn: 'Masoor Dal',
        titleNe: 'मसुर दाल',
        servingsRemaining: 1,
        remainingGrams: 250.0,
        preparedAt: now.subtract(const Duration(hours: 42)),
        useByDate: now.add(const Duration(hours: 6)),
        storageCondition: StorageCondition.refrigerated,
        isConsumed: false,
        isDiscarded: false,
      );
      await tester.runAsync(() => repo.saveLeftover(leftover));

      await tester.pumpWidget(
        MaterialApp(
          home: ConsumptionDashboardScreen(
            currentLanguage: 'en',
            repository: repo,
            now: now,
          ),
        ),
      );
      await settle(tester);

      // Banner should be rendered
      expect(find.byKey(const Key('leftovers_summary_banner')), findsOneWidget);
      expect(find.byKey(const Key('leftovers_waste_action')), findsOneWidget);

      // Tap "View →" button in banner
      await tester.tap(find.byKey(const Key('view_leftovers_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);

      // LeftoverScreen should open
      expect(find.text('Leftovers ("Eat First")'), findsOneWidget);
      expect(find.text('Masoor Dal'), findsOneWidget);
    });
  });
}
