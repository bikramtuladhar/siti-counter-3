/**
 * Siti Counter 3.0 - Party Mode Planner Engine (TypeScript)
 * Section 8.7 & 19.5: Scaled menu planning, T-minus backwards prep timeline,
 * equipment/burner conflict detection, combined party groceries, and co-host delegation.
 */

export type CourseType = 'drink' | 'appetizer' | 'main' | 'side' | 'dessert';

export interface PartyIngredient {
  id: string;
  nameEn: string;
  nameNe: string;
  baseGrams: number;
  unit?: string;
}

export interface PartyMenuItem {
  recipeId: string;
  nameEn: string;
  nameNe: string;
  course: CourseType;
  baseServings?: number;
  prepDurationMinutes: number;
  cookDurationMinutes: number;
  requiredEquipment: string[];
  requiredBurners?: number;
  canBePreparedAhead?: boolean;
  marinateMinutes?: number;
  dietaryTags?: string[];
  ingredients?: PartyIngredient[];
}

export interface PartyPlanInput {
  titleEn: string;
  titleNe: string;
  guestCount: number;
  serveTime: string; // e.g. "19:00" or ISO "2026-10-15T19:00:00"
  dietaryRestrictions?: string[];
  menuItems: PartyMenuItem[];
  availableEquipment: string[];
  burnerCount?: number;
  coHosts?: string[];
}

export interface TMinusTask {
  id: string;
  recipeId: string;
  recipeNameEn: string;
  recipeNameNe: string;
  titleEn: string;
  titleNe: string;
  tMinusMinutes: number; // Minutes prior to serving (e.g. 180 means T-3h)
  targetTime: string; // e.g. "16:00"
  durationMinutes: number;
  equipmentUsed: string[];
  burnersUsed: number;
  assignedCoHost?: string;
  isCompleted: boolean;
}

export interface EquipmentConflict {
  equipmentId: string;
  conflictingRecipeIds: string[];
  conflictingRecipeNames: string[];
  overlapStartTime: string;
  overlapEndTime: string;
  resolutionSuggestionEn: string;
  resolutionSuggestionNe: string;
}

export interface PartyGroceryItem {
  ingredientId: string;
  nameEn: string;
  nameNe: string;
  scaledGrams: number;
  unit: string;
}

export interface PartyPlanResult {
  titleEn: string;
  titleNe: string;
  guestCount: number;
  scaleFactor: number;
  timeline: TMinusTask[];
  equipmentConflicts: EquipmentConflict[];
  burnerConflicts: EquipmentConflict[];
  combinedGroceries: PartyGroceryItem[];
  isFeasibleWithoutConflict: boolean;
}

export class PartyPlannerEngine {
  /**
   * Generates a fully scaled Party Plan with T-minus timeline and equipment conflict detection.
   */
  static generatePlan(input: PartyPlanInput): PartyPlanResult {
    const guestCount = Math.max(1, input.guestCount);
    const baseServings = 4;
    const scaleFactor = guestCount / baseServings;
    const burnerCount = input.burnerCount ?? 3;
    const availableEquipSet = new Set(input.availableEquipment.map((e) => e.toLowerCase()));
    const coHosts = input.coHosts && input.coHosts.length > 0 ? input.coHosts : ['Host'];

    // Parse serve time into hours and minutes
    const serveTimeParts = input.serveTime.includes('T')
      ? input.serveTime.split('T')[1].split(':')
      : input.serveTime.split(':');
    const serveHour = parseInt(serveTimeParts[0], 10);
    const serveMin = parseInt(serveTimeParts[1], 10);
    const serveTotalMinutes = serveHour * 60 + serveMin;

    const formatClockTime = (totalMinutes: number): string => {
      let m = totalMinutes % (24 * 60);
      if (m < 0) m += 24 * 60;
      const h = Math.floor(m / 60);
      const min = m % 60;
      return `${h.toString().padStart(2, '0')}:${min.toString().padStart(2, '0')}`;
    };

    const tasks: TMinusTask[] = [];
    let taskIdx = 0;

    // 1. Backwards schedule tasks per menu item
    for (const item of input.menuItems) {
      // Determine when the dish must finish cooking relative to serve time (T-0)
      let finishOffsetMinutes = 0;
      if (item.course === 'appetizer') {
        finishOffsetMinutes = 20; // Ready 20m before dinner when guests arrive
      } else if (item.course === 'drink') {
        finishOffsetMinutes = 30; // Chilled 30m before dinner
      } else if (item.course === 'dessert' && item.canBePreparedAhead) {
        finishOffsetMinutes = 120; // Done well in advance
      } else if (item.course === 'main') {
        finishOffsetMinutes = 10; // 10m resting/plating buffer
      } else {
        finishOffsetMinutes = 15;
      }

      const cookEndMinutes = serveTotalMinutes - finishOffsetMinutes;
      const cookStartMinutes = cookEndMinutes - item.cookDurationMinutes;
      const tMinusCook = serveTotalMinutes - cookStartMinutes;

      // Cook Task
      if (item.cookDurationMinutes > 0) {
        const assignedCoHost = coHosts[taskIdx % coHosts.length];
        taskIdx++;

        tasks.push({
          id: `task_${item.recipeId}_cook`,
          recipeId: item.recipeId,
          recipeNameEn: item.nameEn,
          recipeNameNe: item.nameNe,
          titleEn: `Cook ${item.nameEn}`,
          titleNe: `${item.nameNe} पकाउनुहोस्`,
          tMinusMinutes: tMinusCook,
          targetTime: formatClockTime(cookStartMinutes),
          durationMinutes: item.cookDurationMinutes,
          equipmentUsed: item.requiredEquipment,
          burnersUsed: item.requiredBurners ?? 1,
          assignedCoHost,
          isCompleted: false,
        });
      }

      // Marinate Task (if required)
      let prepEndMinutes = cookStartMinutes;
      if (item.marinateMinutes && item.marinateMinutes > 0) {
        const marinateStartMinutes = cookStartMinutes - item.marinateMinutes;
        const tMinusMarinate = serveTotalMinutes - marinateStartMinutes;
        const assignedCoHost = coHosts[taskIdx % coHosts.length];
        taskIdx++;

        tasks.push({
          id: `task_${item.recipeId}_marinate`,
          recipeId: item.recipeId,
          recipeNameEn: item.nameEn,
          recipeNameNe: item.nameNe,
          titleEn: `Marinate ${item.nameEn}`,
          titleNe: `${item.nameNe} मोल्नुहोस् (Marinate)`,
          tMinusMinutes: tMinusMarinate,
          targetTime: formatClockTime(marinateStartMinutes),
          durationMinutes: item.marinateMinutes,
          equipmentUsed: [],
          burnersUsed: 0,
          assignedCoHost,
          isCompleted: false,
        });

        prepEndMinutes = marinateStartMinutes;
      }

      // Prep / Chop Task
      if (item.prepDurationMinutes > 0) {
        const prepStartMinutes = prepEndMinutes - item.prepDurationMinutes;
        const tMinusPrep = serveTotalMinutes - prepStartMinutes;
        const assignedCoHost = coHosts[taskIdx % coHosts.length];
        taskIdx++;

        tasks.push({
          id: `task_${item.recipeId}_prep`,
          recipeId: item.recipeId,
          recipeNameEn: item.nameEn,
          recipeNameNe: item.nameNe,
          titleEn: `Prep ingredients for ${item.nameEn}`,
          titleNe: `${item.nameNe} को सामग्री तयार पार्नुहोस्`,
          tMinusMinutes: tMinusPrep,
          targetTime: formatClockTime(prepStartMinutes),
          durationMinutes: item.prepDurationMinutes,
          equipmentUsed: item.requiredEquipment.filter((e) => e.includes('blender') || e.includes('food_processor')),
          burnersUsed: 0,
          assignedCoHost,
          isCompleted: false,
        });
      }
    }

    // Sort timeline chronologically (highest T-minus first down to T-0)
    tasks.sort((a, b) => b.tMinusMinutes - a.tMinusMinutes);

    // 2. Equipment Conflict Detection
    const equipmentConflicts: EquipmentConflict[] = [];
    const cookingTasks = tasks.filter((t) => t.equipmentUsed.length > 0 && t.durationMinutes > 0);

    for (let i = 0; i < cookingTasks.length; i++) {
      for (let j = i + 1; j < cookingTasks.length; j++) {
        const taskA = cookingTasks[i];
        const taskB = cookingTasks[j];

        // Shared equipment check
        const sharedEquipment = taskA.equipmentUsed.filter((eq) =>
          taskB.equipmentUsed.includes(eq)
        );

        if (sharedEquipment.length > 0) {
          const aStart = serveTotalMinutes - taskA.tMinusMinutes;
          const aEnd = aStart + taskA.durationMinutes;
          const bStart = serveTotalMinutes - taskB.tMinusMinutes;
          const bEnd = bStart + taskB.durationMinutes;

          // Check if time intervals overlap
          const overlapStart = Math.max(aStart, bStart);
          const overlapEnd = Math.min(aEnd, bEnd);

          if (overlapStart < overlapEnd) {
            for (const eq of sharedEquipment) {
              const eqName = eq.replace(/_/g, ' ');
              equipmentConflicts.push({
                equipmentId: eq,
                conflictingRecipeIds: [taskA.recipeId, taskB.recipeId],
                conflictingRecipeNames: [taskA.recipeNameEn, taskB.recipeNameEn],
                overlapStartTime: formatClockTime(overlapStart),
                overlapEndTime: formatClockTime(overlapEnd),
                resolutionSuggestionEn: `Stagger preparation: cook ${taskA.recipeNameEn} earlier and keep warm to free the ${eqName} for ${taskB.recipeNameEn}.`,
                resolutionSuggestionNe: `समय मिलाउनुहोस्: ${taskA.recipeNameNe} लाई पहिले पकाएर तातो राख्नुहोस् जसले गर्दा ${eqName} ${taskB.recipeNameNe} को लागि खाली हुन्छ।`,
              });
            }
          }
        }
      }
    }

    // 3. Stove Burner Conflict Detection
    const burnerConflicts: EquipmentConflict[] = [];
    const stoveTasks = tasks.filter((t) => t.burnersUsed > 0);

    for (let i = 0; i < stoveTasks.length; i++) {
      for (let j = i + 1; j < stoveTasks.length; j++) {
        const a = stoveTasks[i];
        const b = stoveTasks[j];

        const aStart = serveTotalMinutes - a.tMinusMinutes;
        const aEnd = aStart + a.durationMinutes;
        const bStart = serveTotalMinutes - b.tMinusMinutes;
        const bEnd = bStart + b.durationMinutes;

        const overlapStart = Math.max(aStart, bStart);
        const overlapEnd = Math.min(aEnd, bEnd);

        if (overlapStart < overlapEnd) {
          // Check if concurrent stove burners exceed burnerCount
          const totalBurnersInOverlap = a.burnersUsed + b.burnersUsed;
          if (totalBurnersInOverlap > burnerCount) {
            burnerConflicts.push({
              equipmentId: 'stove_burners',
              conflictingRecipeIds: [a.recipeId, b.recipeId],
              conflictingRecipeNames: [a.recipeNameEn, b.recipeNameEn],
              overlapStartTime: formatClockTime(overlapStart),
              overlapEndTime: formatClockTime(overlapEnd),
              resolutionSuggestionEn: `Exceeds ${burnerCount} cooktop burners (${totalBurnersInOverlap} needed). Cook one dish ahead.`,
              resolutionSuggestionNe: `चुल्होको क्षमता (${burnerCount} बर्नर) भन्दा बढी भयो। एउटा परिकार अगाडि नै पकाउनुहोस्।`,
            });
          }
        }
      }
    }

    // 4. Combined Party Groceries
    const groceryMap = new Map<string, PartyGroceryItem>();

    for (const item of input.menuItems) {
      if (item.ingredients) {
        for (const ing of item.ingredients) {
          const scaled = ing.baseGrams * scaleFactor;
          const existing = groceryMap.get(ing.id);
          if (existing) {
            existing.scaledGrams += scaled;
          } else {
            groceryMap.set(ing.id, {
              ingredientId: ing.id,
              nameEn: ing.nameEn,
              nameNe: ing.nameNe,
              scaledGrams: Math.round(scaled),
              unit: ing.unit ?? 'g',
            });
          }
        }
      }
    }

    const combinedGroceries = Array.from(groceryMap.values()).sort((a, b) =>
      a.nameEn.localeCompare(b.nameEn)
    );

    return {
      titleEn: input.titleEn,
      titleNe: input.titleNe,
      guestCount,
      scaleFactor,
      timeline: tasks,
      equipmentConflicts,
      burnerConflicts,
      combinedGroceries,
      isFeasibleWithoutConflict: equipmentConflicts.length === 0 && burnerConflicts.length === 0,
    };
  }
}
