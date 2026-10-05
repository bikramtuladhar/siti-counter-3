import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/displays/companion_widget_service.dart';
import 'package:siti_counter/displays/home_screen_widget_previews.dart';
import 'package:siti_counter/displays/watch_companion_preview_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Companion Displays & Watch App Integration Tests (Issue #45)', () {
    test('CompanionWidgetService updates, syncs and exports widget payloads', () {
      final service = CompanionWidgetService();

      // 1. Update Today's Meals
      service.updateTodaysMeals(
        dateIso: '2026-10-05',
        rituNameEn: 'Sharad',
        rituNameNe: 'शरद',
        meals: [
          const WidgetPlannedMealSummary(
            slotId: 'lunch',
            slotTitleEn: 'Lunch',
            slotTitleNe: 'दिउँसोको खाना',
            recipeTitleEn: 'Dal Bhat Tarkari',
            recipeTitleNe: 'दाल भात तरकारी',
            servings: 4,
          ),
        ],
      );

      expect(service.todaysMealsWidget, isNotNull);
      expect(service.todaysMealsWidget!.meals.length, equals(1));
      expect(service.todaysMealsWidget!.rituNameEn, equals('Sharad'));

      // 2. Update Active Siti Counter
      service.updateActiveSiti(
        sessionId: 'session_123',
        dishTitleEn: 'Mutton Curry',
        dishTitleNe: 'खसीको मासु',
        currentWhistles: 2,
        targetWhistles: 5,
        status: 'cooking',
      );

      expect(service.activeSitiWidget, isNotNull);
      expect(service.activeSitiWidget!.currentWhistles, equals(2));
      expect(service.activeSitiWidget!.progressPercent, equals(40));
      expect(service.activeSitiWidget!.isAlarmActive, isFalse);

      // 3. Update Grocery Checklist
      service.updateGroceryChecklist([
        const GroceryItemWidgetSummary(
          itemId: 'item_1',
          nameEn: 'Coriander Seeds',
          nameNe: 'धनियाँको गेडा',
          quantityStr: '100g',
          isCompleted: true,
        ),
        const GroceryItemWidgetSummary(
          itemId: 'item_2',
          nameEn: 'Mustard Oil',
          nameNe: 'तोरीको तेल',
          quantityStr: '1L',
          isCompleted: false,
        ),
      ]);

      expect(service.groceryChecklistWidget, isNotNull);
      expect(service.groceryChecklistWidget!.totalItems, equals(2));
      expect(service.groceryChecklistWidget!.completedItems, equals(1));
      expect(service.groceryChecklistWidget!.pendingItems, equals(1));

      // 4. Export payloads
      final payloads = service.exportNativeWidgetPayloads();
      expect(payloads['todaysMeals'], isNotNull);
      expect(payloads['activeSiti'], isNotNull);
      expect(payloads['groceryChecklist'], isNotNull);
      expect(payloads['timestamp'], isNotNull);
    });

    testWidgets('HomeScreenWidgetPreviews renders all three native widget cards correctly',
        (tester) async {
      final todaysMeals = CompanionDisplayEngine.buildTodaysMealsWidget(
        dateIso: '2026-10-05',
        rituNameEn: 'Sharad',
        rituNameNe: 'शरद',
        meals: [
          const WidgetPlannedMealSummary(
            slotId: 'dinner',
            slotTitleEn: 'Dinner',
            slotTitleNe: 'रातिको खाना',
            recipeTitleEn: 'Khichdi',
            recipeTitleNe: 'खिचडी',
            servings: 2,
          ),
        ],
      );

      final activeSiti = CompanionDisplayEngine.buildActiveSitiWidget(
        sessionId: 'session_dal',
        dishTitleEn: 'Yellow Dal',
        dishTitleNe: 'पहेँलो दाल',
        currentWhistles: 3,
        targetWhistles: 3,
        status: 'alarm',
      );

      final grocery = CompanionDisplayEngine.buildGroceryChecklistWidget([
        const GroceryItemWidgetSummary(
          itemId: 'g1',
          nameEn: 'Garlic',
          nameNe: 'लसुन',
          quantityStr: '250g',
          isCompleted: false,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreenWidgetPreviews(
              todaysMeals: todaysMeals,
              activeSiti: activeSiti,
              groceryChecklist: grocery,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Active Siti card
      expect(find.byKey(const Key('widget_active_siti')), findsOneWidget);
      expect(find.textContaining('Yellow Dal'), findsOneWidget);
      expect(find.byKey(const Key('widget_siti_whistle_value')), findsOneWidget);
      expect(find.byKey(const Key('widget_siti_alarm_banner')), findsOneWidget);

      // Verify Today's Meals card
      expect(find.byKey(const Key('widget_todays_meals')), findsOneWidget);
      expect(find.textContaining('Sharad'), findsOneWidget);
      expect(find.text('Khichdi'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);

      // Verify Grocery Checklist card
      expect(find.byKey(const Key('widget_grocery_checklist')), findsOneWidget);
      expect(find.byKey(const Key('widget_grocery_item_g1')), findsOneWidget);
      expect(find.textContaining('Garlic'), findsOneWidget);
    });

    testWidgets('WatchCompanionPreviewSheet supports live interactions, steps and haptics',
        (tester) async {
      final service = CompanionWidgetService();

      service.updateWatchCompanionState(
        WatchCompanionState(
          sessionId: 'session_watch_1',
          dishTitleEn: 'Black Lentil Dal',
          dishTitleNe: 'मासको दाल',
          currentWhistles: 1,
          targetWhistles: 3,
          currentStepIndex: 0,
          totalSteps: 3,
          currentStepInstructionEn: 'Heat cooker with ghee and jimbu',
          currentStepInstructionNe: 'घिउ र जिम्बू हालेर कुकर तताउनुहोस्',
          isAlarmActive: false,
          status: 'cooking',
          lastHapticPattern: WatchHapticPattern.whistle,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchCompanionPreviewSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial State assertions
      expect(find.byKey(const Key('watch_companion_surface')), findsOneWidget);
      expect(find.byKey(const Key('watch_dish_title')), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Step 1/3'), findsOneWidget);
      expect(find.text('Heat cooker with ghee and jimbu'), findsOneWidget);
      expect(find.byKey(const Key('watch_alarm_alert')), findsNothing);

      // 2. Increment Siti Whistle
      await tester.tap(find.byKey(const Key('btn_watch_add_whistle')));
      await tester.pumpAndSettle();

      expect(find.text('2/3'), findsOneWidget);
      expect(service.watchCompanionState!.currentWhistles, equals(2));
      expect(service.watchCompanionState!.lastHapticPattern, equals(WatchHapticPattern.whistle));

      // 3. Advance cooking step
      await tester.tap(find.byKey(const Key('btn_watch_toggle_step')));
      await tester.pumpAndSettle();

      expect(find.text('Step 2/3'), findsOneWidget);
      expect(service.watchCompanionState!.currentStepIndex, equals(1));
      expect(service.watchCompanionState!.lastHapticPattern, equals(WatchHapticPattern.tick));

      // 4. Reach target whistle (from 2 to 3 whistles)
      await tester.tap(find.byKey(const Key('btn_watch_add_whistle')));
      await tester.pumpAndSettle();

      expect(find.text('3/3'), findsOneWidget);
      expect(service.watchCompanionState!.isAlarmActive, isTrue);
      expect(service.watchCompanionState!.status, equals('alarm'));
      expect(
        service.watchCompanionState!.lastHapticPattern,
        equals(WatchHapticPattern.targetReached),
      );
      expect(find.byKey(const Key('watch_alarm_alert')), findsOneWidget);
      expect(find.byKey(const Key('btn_watch_dismiss_alarm')), findsOneWidget);

      // 5. Dismiss alarm from watch
      await tester.tap(find.byKey(const Key('btn_watch_dismiss_alarm')));
      await tester.pumpAndSettle();

      expect(service.watchCompanionState!.isAlarmActive, isFalse);
      expect(service.watchCompanionState!.status, equals('done'));
      expect(find.byKey(const Key('watch_alarm_alert')), findsNothing);
    });
  });
}
