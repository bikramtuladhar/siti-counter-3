import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/planner/monthly_planner_view.dart';
import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/theme/tokens.dart';

PlannedMeal meal(String id, String dateIso, String title) => PlannedMeal(
  id: id,
  dateIso: dateIso,
  slotId: 'breakfast',
  recipeId: 'r_$id',
  recipeTitleEn: title,
  recipeTitleNe: title,
);

Widget host(DateTime month, List<PlannedMeal> meals, {int slotsPerDay = 3}) =>
    MaterialApp(
      home: Scaffold(
        body: MonthlyPlannerView(
          month: month,
          meals: meals,
          preferNepali: false,
          slotsPerDay: slotsPerDay,
        ),
      ),
    );

void main() {
  group('MonthlyPlannerView', () {
    testWidgets('renders a whole-month grid with no plan state', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host(DateTime(2026, 10, 1), const []));

      // Every in-month day is present as a cell.
      for (final day in [1, 15, 30, 31]) {
        expect(
          find.byKey(Key('month_cell_2026-10-${day.toString().padLeft(2, '0')}')),
          findsOneWidget,
          reason: 'expected a cell for 2026-10-$day',
        );
      }

      // Weekday headers align the grid.
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
    });

    testWidgets('shows planned meal titles on their own day', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        host(DateTime(2026, 10, 1), [
          meal('a', '2026-10-04', 'Dal bhat'),
          meal('b', '2026-10-04', 'Achar'),
          meal('c', '2026-10-20', 'Momo'),
        ]),
      );

      expect(find.text('Dal bhat'), findsOneWidget);
      expect(find.text('Momo'), findsOneWidget);

      // Two of two slots fit, so neither overflows.
      expect(find.text('+0'), findsNothing);
    });

    testWidgets('collapses overflow beyond the visible slots', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        host(
          DateTime(2026, 10, 1),
          [
            meal('a', '2026-10-04', 'Dal bhat'),
            meal('b', '2026-10-04', 'Achar'),
            meal('c', '2026-10-04', 'Gundruk'),
          ],
        ),
      );

      // Two titles render, the third is summarised.
      expect(find.text('Dal bhat'), findsOneWidget);
      expect(find.text('Gundruk'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('marks a fully planned day with the freshGreen indicator',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        host(
          DateTime(2026, 10, 1),
          [
            meal('a', '2026-10-04', 'One'),
            meal('b', '2026-10-04', 'Two'),
            meal('c', '2026-10-04', 'Three'),
          ],
          slotsPerDay: 3,
        ),
      );

      final indicator = tester.widgetList<Container>(find.descendant(
        of: find.byKey(const Key('month_cell_2026-10-04')),
        matching: find.byType(Container),
      ));

      expect(
        indicator.any((c) => c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).color == SitiColors.freshGreen),
        isTrue,
        reason: 'a fully planned day should show the complete indicator',
      );
    });

    testWidgets("today is conveyed by more than colour", (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final today = DateTime.now();
      final iso =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        host(
          DateTime(today.year, today.month, 1),
          [meal('a', iso, 'Dal Bhat')],
        ),
      );

      // Today was signalled only by a terracotta tint and border, which carries no information
      // for someone who cannot distinguish those colours.
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp(r'today')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'1 meals planned')), findsOneWidget);
      // Disposed here rather than via addTearDown: the binding verifies handles before tearDowns
      // run, so a deferred dispose fails the test.
      handle.dispose();
    });

    testWidgets('an empty day announces that nothing is planned', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        host(DateTime(2026, 10, 1), const []),
      );

      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('nothing planned')), findsWidgets);
      handle.dispose();
    });

    testWidgets('tapping an empty day reports it, because the plus sign implies it works',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DateTime? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthlyPlannerView(
              month: DateTime(2026, 10, 1),
              meals: const [],
              preferNepali: false,
              onDayTapped: (d) => tapped = d,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('month_cell_2026-10-15')));
      expect(tapped, DateTime(2026, 10, 15));
    });

    testWidgets('a full day does not overflow on a 390pt phone', (tester) async {
      // The cell height was tuned against the placeholder test font, which is shorter than a
      // real one. At phone width with two titles, an overflow count and the indicator, the
      // cell overflowed by 8px.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        host(
          DateTime(2026, 10, 1),
          [
            meal('a', '2026-10-04', 'Masu Bhat'),
            meal('b', '2026-10-04', 'Mixed Vegetable Tarkari'),
            meal('c', '2026-10-04', 'Gundruk'),
            meal('d', '2026-10-04', 'Achar'),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('excludes days outside the displayed month', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // November and September meals must not surface inside October's grid.
      await tester.pumpWidget(
        host(DateTime(2026, 10, 1), [
          meal('a', '2026-11-02', 'Next month'),
          meal('b', '2026-09-28', 'Last month'),
        ]),
      );

      expect(find.text('Next month'), findsNothing);
      expect(find.text('Last month'), findsNothing);
    });
  });
}