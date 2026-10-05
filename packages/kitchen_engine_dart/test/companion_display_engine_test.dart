import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CompanionDisplayEngine Dart Parity Tests', () {
    test('Today’s Meals Widget data building', () {
      final widget = CompanionDisplayEngine.buildTodaysMealsWidget(
        dateIso: '2026-10-05',
        rituNameEn: 'Sharad',
        rituNameNe: 'शरद',
        meals: [
          const WidgetPlannedMealSummary(
            slotId: 'morning-dal-bhat',
            slotTitleEn: 'Morning Dal Bhat',
            slotTitleNe: 'बिहानीको दाल भात',
            recipeTitleEn: 'Masyang Dal & Bhat',
            recipeTitleNe: 'मास्याङ दाल र भात',
            servings: 4,
          ),
          const WidgetPlannedMealSummary(
            slotId: 'evening-bhat',
            slotTitleEn: 'Evening Dal Bhat',
            slotTitleNe: 'साँझको खाना',
            recipeTitleEn: 'Aloo Tama Tarkari',
            recipeTitleNe: 'आलु तामा तरकारी',
            servings: 4,
          ),
        ],
      );

      expect(widget.dateIso, '2026-10-05');
      expect(widget.rituNameEn, 'Sharad');
      expect(widget.totalPlannedMeals, 2);
      expect(widget.meals.first.recipeTitleEn, 'Masyang Dal & Bhat');
    });

    test('Active Siti Counter Widget with progress & alarm', () {
      // In-progress
      final activeWidget = CompanionDisplayEngine.buildActiveSitiWidget(
        sessionId: 'sess_1',
        dishTitleEn: 'Kalo Dal',
        dishTitleNe: 'कालो दाल',
        currentWhistles: 2,
        targetWhistles: 4,
        status: 'cooking',
      );

      expect(activeWidget.progressPercent, 50);
      expect(activeWidget.isAlarmActive, isFalse);
      expect(activeWidget.status, 'cooking');

      // Reached target -> alarm
      final completedWidget = CompanionDisplayEngine.buildActiveSitiWidget(
        sessionId: 'sess_1',
        dishTitleEn: 'Kalo Dal',
        dishTitleNe: 'कालो दाल',
        currentWhistles: 4,
        targetWhistles: 4,
        status: 'cooking',
      );

      expect(completedWidget.progressPercent, 100);
      expect(completedWidget.isAlarmActive, isTrue);
      expect(completedWidget.status, 'alarm');
    });

    test('Grocery Checklist Widget data summary', () {
      final widget = CompanionDisplayEngine.buildGroceryChecklistWidget([
        const GroceryItemWidgetSummary(itemId: '1', nameEn: 'Potato', nameNe: 'आलु', quantityStr: '1 kg', isCompleted: true),
        const GroceryItemWidgetSummary(itemId: '2', nameEn: 'Mustard Oil', nameNe: 'तोरीको तेल', quantityStr: '1 L', isCompleted: false),
        const GroceryItemWidgetSummary(itemId: '3', nameEn: 'Salt', nameNe: 'नुन', quantityStr: '1 pkt', isCompleted: true),
        const GroceryItemWidgetSummary(itemId: '4', nameEn: 'Coriander', nameNe: 'धनियाँ', quantityStr: '1 mutha', isCompleted: false),
      ]);

      expect(widget.totalItems, 4);
      expect(widget.completedItems, 2);
      expect(widget.pendingItems, 2);
      expect(widget.previewItems.length, 4);
    });

    test('Watch Companion State with haptic patterns', () {
      final midCook = CompanionDisplayEngine.buildWatchCompanionState(
        sessionId: 'sess_watch_1',
        dishTitleEn: 'Khasi ko Masu',
        dishTitleNe: 'खसीको मासु',
        currentWhistles: 3,
        targetWhistles: 6,
        currentStepIndex: 2,
        totalSteps: 4,
        currentStepInstructionEn: 'Maintain medium flame until 6 whistles',
        currentStepInstructionNe: '६ सिट्ठीसम्म मध्यम आँचमा राख्नुहोस्',
      );

      expect(midCook.currentWhistles, 3);
      expect(midCook.lastHapticPattern, WatchHapticPattern.whistle);
      expect(midCook.isAlarmActive, isFalse);

      final targetReached = CompanionDisplayEngine.buildWatchCompanionState(
        sessionId: 'sess_watch_1',
        dishTitleEn: 'Khasi ko Masu',
        dishTitleNe: 'खसीको मासु',
        currentWhistles: 6,
        targetWhistles: 6,
        currentStepIndex: 3,
        totalSteps: 4,
        currentStepInstructionEn: 'Turn off heat and let pressure release naturally',
        currentStepInstructionNe: 'आँच बन्द गर्नुहोस् र बाफ आफैँ निस्कन दिनुहोस्',
      );

      expect(targetReached.currentWhistles, 6);
      expect(targetReached.lastHapticPattern, WatchHapticPattern.targetReached);
      expect(targetReached.isAlarmActive, isTrue);
      expect(targetReached.status, 'alarm');
    });
  });
}
