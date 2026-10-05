import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CompanionDisplayEngine,
} from './companion_display_engine.js';

test('CompanionDisplayEngine - Today’s Meals Widget data building', () => {
  const widget = CompanionDisplayEngine.buildTodaysMealsWidget({
    dateIso: '2026-10-05',
    rituNameEn: 'Sharad',
    rituNameNe: 'शरद',
    meals: [
      {
        slotId: 'morning-dal-bhat',
        slotTitleEn: 'Morning Dal Bhat',
        slotTitleNe: 'बिहानीको दाल भात',
        recipeTitleEn: 'Masyang Dal & Bhat',
        recipeTitleNe: 'मास्याङ दाल र भात',
        servings: 4,
      },
      {
        slotId: 'evening-bhat',
        slotTitleEn: 'Evening Dal Bhat',
        slotTitleNe: 'साँझको खाना',
        recipeTitleEn: 'Aloo Tama Tarkari',
        recipeTitleNe: 'आलु तामा तरकारी',
        servings: 4,
      },
    ],
  });

  assert.equal(widget.dateIso, '2026-10-05');
  assert.equal(widget.rituNameEn, 'Sharad');
  assert.equal(widget.totalPlannedMeals, 2);
  assert.equal(widget.meals[0].recipeTitleEn, 'Masyang Dal & Bhat');
});

test('CompanionDisplayEngine - Active Siti Counter Widget with progress & alarm', () => {
  // In-progress cooking
  const activeWidget = CompanionDisplayEngine.buildActiveSitiWidget({
    sessionId: 'sess_1',
    dishTitleEn: 'Kalo Dal',
    dishTitleNe: 'कालो दाल',
    currentWhistles: 2,
    targetWhistles: 4,
    status: 'cooking',
  });

  assert.equal(activeWidget.progressPercent, 50);
  assert.equal(activeWidget.isAlarmActive, false);
  assert.equal(activeWidget.status, 'cooking');

  // Reached target -> triggers alarm
  const completedWidget = CompanionDisplayEngine.buildActiveSitiWidget({
    sessionId: 'sess_1',
    dishTitleEn: 'Kalo Dal',
    dishTitleNe: 'कालो दाल',
    currentWhistles: 4,
    targetWhistles: 4,
    status: 'cooking',
  });

  assert.equal(completedWidget.progressPercent, 100);
  assert.equal(completedWidget.isAlarmActive, true);
  assert.equal(completedWidget.status, 'alarm');
});

test('CompanionDisplayEngine - Grocery Checklist Widget data summary', () => {
  const widget = CompanionDisplayEngine.buildGroceryChecklistWidget([
    { itemId: '1', nameEn: 'Potato', nameNe: 'आलु', quantityStr: '1 kg', isCompleted: true },
    { itemId: '2', nameEn: 'Mustard Oil', nameNe: 'तोरीको तेल', quantityStr: '1 L', isCompleted: false },
    { itemId: '3', nameEn: 'Salt', nameNe: 'नुन', quantityStr: '1 pkt', isCompleted: true },
    { itemId: '4', nameEn: 'Coriander', nameNe: 'धनियाँ', quantityStr: '1 mutha', isCompleted: false },
  ]);

  assert.equal(widget.totalItems, 4);
  assert.equal(widget.completedItems, 2);
  assert.equal(widget.pendingItems, 2);
  assert.equal(widget.previewItems.length, 4);
});

test('CompanionDisplayEngine - Watch Companion State with haptic patterns', () => {
  // Mid-cook whistle pattern
  const midCook = CompanionDisplayEngine.buildWatchCompanionState({
    sessionId: 'sess_watch_1',
    dishTitleEn: 'Khasi ko Masu',
    dishTitleNe: 'खसीको मासु',
    currentWhistles: 3,
    targetWhistles: 6,
    currentStepIndex: 2,
    totalSteps: 4,
    currentStepInstructionEn: 'Maintain medium flame until 6 whistles',
    currentStepInstructionNe: '६ सिट्ठीसम्म मध्यम आँचमा राख्नुहोस्',
  });

  assert.equal(midCook.currentWhistles, 3);
  assert.equal(midCook.lastHapticPattern, 'whistle');
  assert.equal(midCook.isAlarmActive, false);

  // Target reached haptic pattern
  const targetReached = CompanionDisplayEngine.buildWatchCompanionState({
    sessionId: 'sess_watch_1',
    dishTitleEn: 'Khasi ko Masu',
    dishTitleNe: 'खसीको मासु',
    currentWhistles: 6,
    targetWhistles: 6,
    currentStepIndex: 3,
    totalSteps: 4,
    currentStepInstructionEn: 'Turn off heat and let pressure release naturally',
    currentStepInstructionNe: 'आँच बन्द गर्नुहोस् र बाफ आफैँ निस्कन दिनुहोस्',
  });

  assert.equal(targetReached.currentWhistles, 6);
  assert.equal(targetReached.lastHapticPattern, 'targetReached');
  assert.equal(targetReached.isAlarmActive, true);
  assert.equal(targetReached.status, 'alarm');
});
