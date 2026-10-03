import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/planner/planner_repository.dart';
import 'package:siti_counter/planner/weekly_planner_screen.dart';

/// sqflite FFI performs real async I/O, which never completes inside the
/// fake-async zone of testWidgets. Let real I/O finish, then pump the frame.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

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

  Widget host(WeeklyPlannerRepository repo) => MaterialApp(
        home: WeeklyPlannerScreen(
          repository: repo,
          currentLanguage: 'ne',
          initialWeekStart: DateTime(2026, 10, 4), // Sunday
        ),
      );

  group('WeeklyPlannerScreen', () {
    testWidgets('renders 7 days with default Nepali meal rhythms and navigates weeks',
        (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(host(repo));
      await settle(tester);

      expect(find.text('हप्ताको भोजन योजना (Planner)'), findsOneWidget);
      expect(find.text('4 Oct – 10 Oct, 2026'), findsOneWidget);
      expect(find.text('आइतबार'), findsOneWidget);
      expect(find.text('सोमबार'), findsOneWidget);
      expect(find.text('बिहानीको दाल भात'), findsWidgets);
      expect(find.text('दिउँसोको खाजा'), findsWidgets);
      expect(find.text('साँझको दाल भात'), findsWidgets);

      await tester.tap(find.byKey(const Key('next_week_button')));
      await settle(tester);
      expect(find.text('11 Oct – 17 Oct, 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('prev_week_button')));
      await settle(tester);
      expect(find.text('4 Oct – 10 Oct, 2026'), findsOneWidget);
    });

    testWidgets('displays planned meal with seasonal and dietary badges and removes it',
        (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.runAsync(() => repo.savePlannedMeal(const PlannedMeal(
            id: '2026-10-04_morning_dal_bhat',
            dateIso: '2026-10-04',
            slotId: 'morning_dal_bhat',
            recipeId: 'kalo-dal-jimbu',
            recipeTitleEn: 'Kalo Daal with Jimbu',
            recipeTitleNe: 'जिम्बु झानेको कालो दाल',
            isSeasonal: true,
            dietaryBadges: ['vegetarian'],
          )));

      await tester.pumpWidget(host(repo));
      await settle(tester);

      expect(find.text('जिम्बु झानेको कालो दाल'), findsOneWidget);
      expect(find.text('ऋतु अनुसार'), findsOneWidget);
      expect(find.text('vegetarian'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await settle(tester);

      expect(find.text('जिम्बु झानेको कालो दाल'), findsNothing);
    });

    testWidgets('opens rhythm configuration bottom sheet', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(host(repo));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('भोजन समय अनुकूलन (Meal Rhythms)'), findsOneWidget);
      expect(find.text('समय: 09:30'), findsOneWidget);
      expect(find.text('समय: 14:30'), findsOneWidget);
      expect(find.text('समय: 19:30'), findsOneWidget);

      await tester.tap(find.text('ठीक छ'));
      await tester.pumpAndSettle();

      expect(find.text('भोजन समय अनुकूलन (Meal Rhythms)'), findsNothing);
    });
  });
}
