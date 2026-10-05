/**
 * Siti Counter 3.0 - Companion Display & Native Widget Engine (Section 23.4)
 * Formats, serializes, and manages glanceable data across:
 * - Home screen widgets (iOS WidgetKit, Android Glance): Today's Meals, Active Siti Count, Grocery Checklist.
 * - Apple Watch (watchOS) & Wear OS companion extensions: Live whistle counts, haptic alert triggers, step completion toggles.
 */

export interface WidgetPlannedMealSummary {
  readonly slotId: string
  readonly slotTitleEn: string
  readonly slotTitleNe: string
  readonly recipeTitleEn: string
  readonly recipeTitleNe: string
  readonly servings: number
}

/**
 * Lifecycle of an active cooking session as rendered on glanceable surfaces.
 *
 * - `idle`      no session running yet
 * - `cooking`   session running, below the whistle target
 * - `paused`    session held by the user (Watch/app), still below target
 * - `alarm`     whistle target reached and not yet acknowledged
 * - `completed` target was reached and the alarm was acknowledged (session finished)
 *
 * Note: `completed` is terminal. Re-deriving the alarm from `currentWhistles >= targetWhistles`
 * must NOT resurrect an acknowledged session; see `isTargetReached` / `isAlarmActive` below.
 */
export type CompanionStatus = 'idle' | 'cooking' | 'paused' | 'alarm' | 'completed'

/** Number of grocery rows a glanceable surface shows before collapsing into a count. */
export const GROCERY_PREVIEW_LIMIT = 5

export interface TodaysMealsWidgetData {
  readonly dateIso: string
  readonly rituNameEn: string
  readonly rituNameNe: string
  readonly meals: readonly WidgetPlannedMealSummary[]
  readonly totalPlannedMeals: number
}

export interface ActiveSitiWidgetData {
  readonly sessionId: string
  readonly dishTitleEn: string
  readonly dishTitleNe: string
  readonly currentWhistles: number
  readonly targetWhistles: number
  readonly progressPercent: number // 0 to 100
  readonly isAlarmActive: boolean
  readonly status: CompanionStatus
  /** True once the alarm has been acknowledged; suppresses automatic re-arming. */
  readonly isAlarmAcknowledged: boolean
}

export interface GroceryItemWidgetSummary {
  readonly itemId: string
  readonly nameEn: string
  readonly nameNe: string
  readonly quantityStr: string
  readonly isCompleted: boolean
}

export interface GroceryChecklistWidgetData {
  readonly totalItems: number
  readonly completedItems: number
  readonly pendingItems: number
  readonly previewItems: readonly GroceryItemWidgetSummary[]
}

export type WatchHapticPattern = 'tick' | 'whistle' | 'targetReached' | 'none'

export interface WatchCompanionState {
  readonly sessionId: string
  readonly dishTitleEn: string
  readonly dishTitleNe: string
  readonly currentWhistles: number
  readonly targetWhistles: number
  readonly currentStepIndex: number
  readonly totalSteps: number
  readonly currentStepInstructionEn: string
  readonly currentStepInstructionNe: string
  readonly isAlarmActive: boolean
  readonly status: CompanionStatus
  /** True once the alarm has been acknowledged; suppresses automatic re-arming. */
  readonly isAlarmAcknowledged: boolean
  readonly lastHapticPattern: WatchHapticPattern
}

export interface BuildTodaysMealsInput {
  dateIso: string
  rituNameEn: string
  rituNameNe: string
  meals: WidgetPlannedMealSummary[]
}

export interface BuildActiveSitiInput {
  sessionId: string
  dishTitleEn: string
  dishTitleNe: string
  currentWhistles: number
  targetWhistles: number
  status?: CompanionStatus
  isAlarmActive?: boolean
  isAlarmAcknowledged?: boolean
}

export interface BuildWatchCompanionInput {
  sessionId: string
  dishTitleEn: string
  dishTitleNe: string
  currentWhistles: number
  targetWhistles: number
  currentStepIndex: number
  totalSteps: number
  currentStepInstructionEn: string
  currentStepInstructionNe: string
  isAlarmActive?: boolean
  isAlarmAcknowledged?: boolean
  status?: CompanionStatus
}

export class CompanionDisplayEngine {
  /**
   * A whistle target is only meaningful when the caller supplied a positive target.
   * A zero/absent target means "no target configured" and must never raise an alarm.
   */
  public static isTargetReached(currentWhistles: number, targetWhistles: number): boolean {
    if (targetWhistles <= 0) return false
    return currentWhistles >= targetWhistles
  }

  /**
   * Progress toward the whistle target, clamped to 0..100.
   * A missing target reports 0 rather than dividing by a substituted 1.
   */
  public static progressPercent(currentWhistles: number, targetWhistles: number): number {
    if (targetWhistles <= 0) return 0
    const raw = (currentWhistles / targetWhistles) * 100
    return Math.max(0, Math.min(100, Math.round(raw)))
  }

  /**
   * Resolves the effective alarm flag and status.
   *
   * Once `isAlarmAcknowledged` is set the session is terminal (`completed`) and the alarm
   * stays dismissed, so a later whistle increment cannot silently re-arm it.
   */
  private static resolveAlarm(params: {
    currentWhistles: number
    targetWhistles: number
    requestedAlarm?: boolean
    isAlarmAcknowledged?: boolean
    requestedStatus?: CompanionStatus
  }): { isAlarmActive: boolean; status: CompanionStatus } {
    const acknowledged = params.isAlarmAcknowledged === true
    if (acknowledged) {
      return { isAlarmActive: false, status: 'completed' }
    }

    const targetReached = this.isTargetReached(params.currentWhistles, params.targetWhistles)
    const isAlarm = params.requestedAlarm === true || targetReached
    const status: CompanionStatus = isAlarm ? 'alarm' : (params.requestedStatus ?? 'cooking')

    return { isAlarmActive: isAlarm, status }
  }

  /**
   * Picks the rows a glanceable grocery surface shows: pending items first, because a
   * checklist widget exists to answer "what do I still need to buy?".
   */
  public static selectGroceryPreviewItems(
    items: GroceryItemWidgetSummary[],
    limit: number = GROCERY_PREVIEW_LIMIT
  ): GroceryItemWidgetSummary[] {
    const pending = items.filter((i) => !i.isCompleted)
    const completed = items.filter((i) => i.isCompleted)
    return [...pending, ...completed].slice(0, Math.max(0, limit))
  }

  /**
   * Builds Today's Meals Home Screen Widget snapshot
   */
  public static buildTodaysMealsWidget(input: BuildTodaysMealsInput): TodaysMealsWidgetData {
    return {
      dateIso: input.dateIso,
      rituNameEn: input.rituNameEn,
      rituNameNe: input.rituNameNe,
      meals: input.meals,
      totalPlannedMeals: input.meals.length,
    }
  }

  /**
   * Builds Active Siti Counter Widget snapshot
   */
  public static buildActiveSitiWidget(input: BuildActiveSitiInput): ActiveSitiWidgetData {
    const { isAlarmActive, status } = this.resolveAlarm({
      currentWhistles: input.currentWhistles,
      targetWhistles: input.targetWhistles,
      requestedAlarm: input.isAlarmActive,
      isAlarmAcknowledged: input.isAlarmAcknowledged,
      requestedStatus: input.status,
    })

    return {
      sessionId: input.sessionId,
      dishTitleEn: input.dishTitleEn,
      dishTitleNe: input.dishTitleNe,
      currentWhistles: input.currentWhistles,
      targetWhistles: input.targetWhistles,
      progressPercent: this.progressPercent(input.currentWhistles, input.targetWhistles),
      isAlarmActive,
      status,
      isAlarmAcknowledged: input.isAlarmAcknowledged === true,
    }
  }

  /**
   * Builds Grocery Checklist Home Screen Widget snapshot
   */
  public static buildGroceryChecklistWidget(
    items: GroceryItemWidgetSummary[]
  ): GroceryChecklistWidgetData {
    const completed = items.filter((i) => i.isCompleted).length

    return {
      totalItems: items.length,
      completedItems: completed,
      pendingItems: items.length - completed,
      previewItems: this.selectGroceryPreviewItems(items),
    }
  }

  /**
   * Builds Watch Companion App state payload for Apple Watch and Wear OS
   */
  public static buildWatchCompanionState(input: BuildWatchCompanionInput): WatchCompanionState {
    const { isAlarmActive, status } = this.resolveAlarm({
      currentWhistles: input.currentWhistles,
      targetWhistles: input.targetWhistles,
      requestedAlarm: input.isAlarmActive,
      isAlarmAcknowledged: input.isAlarmAcknowledged,
      requestedStatus: input.status,
    })

    let haptic: WatchHapticPattern = 'none'
    if (isAlarmActive) {
      haptic = 'targetReached'
    } else if (input.currentWhistles > 0 && status !== 'completed') {
      haptic = 'whistle'
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
      isAlarmActive,
      status,
      isAlarmAcknowledged: input.isAlarmAcknowledged === true,
      lastHapticPattern: haptic,
    }
  }
}