/**
 * Siti Counter 3.0 - Companion Display & Native Widget Engine (Section 23.4)
 * Formats, serializes, and manages glanceable data across:
 * - Home screen widgets (iOS WidgetKit, Android Glance): Today's Meals, Active Siti Count, Grocery Checklist.
 * - Apple Watch (watchOS) & Wear OS companion extensions: Live whistle counts, haptic alert triggers, step completion toggles.
 */

export interface WidgetPlannedMealSummary {
  readonly slotId: string;
  readonly slotTitleEn: string;
  readonly slotTitleNe: string;
  readonly recipeTitleEn: string;
  readonly recipeTitleNe: string;
  readonly servings: number;
}

export interface TodaysMealsWidgetData {
  readonly dateIso: string;
  readonly rituNameEn: string;
  readonly rituNameNe: string;
  readonly meals: readonly WidgetPlannedMealSummary[];
  readonly totalPlannedMeals: number;
}

export interface ActiveSitiWidgetData {
  readonly sessionId: string;
  readonly dishTitleEn: string;
  readonly dishTitleNe: string;
  readonly currentWhistles: number;
  readonly targetWhistles: number;
  readonly progressPercent: number; // 0 to 100
  readonly isAlarmActive: boolean;
  readonly status: 'idle' | 'cooking' | 'alarm' | 'completed';
}

export interface GroceryItemWidgetSummary {
  readonly itemId: string;
  readonly nameEn: string;
  readonly nameNe: string;
  readonly quantityStr: string;
  readonly isCompleted: boolean;
}

export interface GroceryChecklistWidgetData {
  readonly totalItems: number;
  readonly completedItems: number;
  readonly pendingItems: number;
  readonly previewItems: readonly GroceryItemWidgetSummary[];
}

export interface WatchCompanionState {
  readonly sessionId: string;
  readonly dishTitleEn: string;
  readonly dishTitleNe: string;
  readonly currentWhistles: number;
  readonly targetWhistles: number;
  readonly currentStepIndex: number;
  readonly totalSteps: number;
  readonly currentStepInstructionEn: string;
  readonly currentStepInstructionNe: string;
  readonly isAlarmActive: boolean;
  readonly status: 'cooking' | 'paused' | 'alarm' | 'completed';
  readonly lastHapticPattern?: 'tick' | 'whistle' | 'targetReached' | 'none';
}

export class CompanionDisplayEngine {
  /**
   * Builds Today's Meals Home Screen Widget snapshot
   */
  public static buildTodaysMealsWidget(input: {
    dateIso: string;
    rituNameEn: string;
    rituNameNe: string;
    meals: WidgetPlannedMealSummary[];
  }): TodaysMealsWidgetData {
    return {
      dateIso: input.dateIso,
      rituNameEn: input.rituNameEn,
      rituNameNe: input.rituNameNe,
      meals: input.meals,
      totalPlannedMeals: input.meals.length,
    };
  }

  /**
   * Builds Active Siti Counter Widget snapshot
   */
  public static buildActiveSitiWidget(input: {
    sessionId: string;
    dishTitleEn: string;
    dishTitleNe: string;
    currentWhistles: number;
    targetWhistles: number;
    status: 'idle' | 'cooking' | 'alarm' | 'completed';
  }): ActiveSitiWidgetData {
    const target = Math.max(1, input.targetWhistles);
    const progress = Math.min(100, Math.round((input.currentWhistles / target) * 100));
    const isAlarm = input.status === 'alarm' || input.currentWhistles >= input.targetWhistles;

    return {
      sessionId: input.sessionId,
      dishTitleEn: input.dishTitleEn,
      dishTitleNe: input.dishTitleNe,
      currentWhistles: input.currentWhistles,
      targetWhistles: input.targetWhistles,
      progressPercent: progress,
      isAlarmActive: isAlarm,
      status: isAlarm ? 'alarm' : input.status,
    };
  }

  /**
   * Builds Grocery Checklist Home Screen Widget snapshot
   */
  public static buildGroceryChecklistWidget(
    items: GroceryItemWidgetSummary[]
  ): GroceryChecklistWidgetData {
    const completed = items.filter((i) => i.isCompleted).length;
    const pending = items.length - completed;

    return {
      totalItems: items.length,
      completedItems: completed,
      pendingItems: pending,
      previewItems: items.slice(0, 5),
    };
  }

  /**
   * Builds Watch Companion App state payload for Apple Watch and Wear OS
   */
  public static buildWatchCompanionState(input: {
    sessionId: string;
    dishTitleEn: string;
    dishTitleNe: string;
    currentWhistles: number;
    targetWhistles: number;
    currentStepIndex: number;
    totalSteps: number;
    currentStepInstructionEn: string;
    currentStepInstructionNe: string;
    isAlarmActive?: boolean;
    status?: 'cooking' | 'paused' | 'alarm' | 'completed';
  }): WatchCompanionState {
    const isAlarm =
      input.isAlarmActive ||
      (input.targetWhistles > 0 && input.currentWhistles >= input.targetWhistles);

    let haptic: 'tick' | 'whistle' | 'targetReached' | 'none' = 'none';
    if (isAlarm) {
      haptic = 'targetReached';
    } else if (input.currentWhistles > 0) {
      haptic = 'whistle';
    }

    return {
      sessionId: input.sessionId,
      dishTitleEn: input.dishTitleEn,
      dishTitleNe: input.dishTitleNe,
      currentWhistles: input.currentWhistles,
      targetWhistles: input.targetWhistles,
      currentStepIndex: input.currentStepIndex,
      totalSteps: input.totalSteps,
      currentStepInstructionEn: input.currentStepInstructionEn,
      currentStepInstructionNe: input.currentStepInstructionNe,
      isAlarmActive: isAlarm,
      status: isAlarm ? 'alarm' : (input.status ?? 'cooking'),
      lastHapticPattern: haptic,
    };
  }
}
