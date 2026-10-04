import { RegionRecipe } from './region_pack_manager.js';

export type TaskType =
  | 'washChop'
  | 'grindMasala'
  | 'watchCooker'
  | 'rollRotis'
  | 'simmerStir'
  | 'cleanUp';

export type TaskCategory = 'prep' | 'cook' | 'clean';

export type TaskStatus = 'pending' | 'inProgress' | 'completed';

export type AgeGroup = 'toddler' | 'child' | 'teen' | 'adult' | 'elderly';

export type SkillLevel = 'beginner' | 'intermediate' | 'expert';

export function getAgeGroup(age: number): AgeGroup {
  if (age < 5) return 'toddler';
  if (age < 12) return 'child';
  if (age < 18) return 'teen';
  if (age < 65) return 'adult';
  return 'elderly';
}

export function getTaskCategory(task: TaskType): TaskCategory {
  switch (task) {
    case 'washChop':
    case 'grindMasala':
      return 'prep';
    case 'watchCooker':
    case 'rollRotis':
    case 'simmerStir':
      return 'cook';
    case 'cleanUp':
      return 'clean';
  }
}

export function canPerformTask(ageGroup: AgeGroup, task: TaskType): boolean {
  switch (ageGroup) {
    case 'toddler':
      return task === 'cleanUp';
    case 'child':
      return task === 'watchCooker' || task === 'cleanUp' || task === 'washChop';
    case 'teen':
    case 'adult':
    case 'elderly':
      return true;
  }
}

export interface MemberCrewProfile {
  memberId: string;
  name: string;
  age: number;
  ageGroup?: AgeGroup;
  skillLevel?: SkillLevel;
  preferredTasks?: TaskType[];
  avoidedTasks?: TaskType[];
  isAvailable?: boolean;
}

export interface CookTask {
  id: string;
  recipeId: string;
  taskType: TaskType;
  titleEn: string;
  titleNe: string;
  descriptionEn: string;
  descriptionNe: string;
  estimatedMinutes: number;
  minimumAge: number;
  isKidFriendly: boolean;
  requiresSupervision: boolean;
  isParallel: boolean;
  assignedMemberId?: string;
  assignedMemberName?: string;
  status: TaskStatus;
}

export interface RotaContributionRecord {
  id: string;
  sessionId: string;
  recipeId: string;
  memberId: string;
  memberName: string;
  taskType: TaskType;
  role: 'leadCook' | 'coCook' | 'helper';
  completedAt: Date;
  durationMinutes?: number;
}

export interface MemberContributionSummary {
  memberId: string;
  memberName: string;
  totalTasksCompleted: number;
  timesLeadCook: number;
  timesCoCook: number;
  tasksByType: Record<TaskType, number>;
  celebratoryBadge: string;
}

export interface FairShareSummary {
  totalSessions: number;
  totalTasksCompleted: number;
  memberSummaries: MemberContributionSummary[];
  celebratoryHeadline: string;
  teamworkInsight: string;
  rotationSuggestion: string;
}

export class CrewEngine {
  /**
   * Splits a recipe into parallel tasks: wash/chop, grind masala, watch cooker, roll rotis, clean-up.
   */
  static splitRecipe(recipe: RegionRecipe): CookTask[] {
    const tasks: CookTask[] = [];
    const recipeLower = recipe.titleEn.toLowerCase();
    const isBreadOrRoti =
      recipeLower.includes('roti') ||
      recipeLower.includes('paratha') ||
      recipeLower.includes('puri') ||
      recipeLower.includes('naan') ||
      recipe.category.toLowerCase().includes('bread');

    // 1. Wash & Chop (Prep)
    if (recipe.ingredients && recipe.ingredients.length > 0) {
      const ingredientsSummary = recipe.ingredients
        .slice(0, 3)
        .map((i) => i.ingredientId.replace(/_/g, ' '))
        .join(', ');
      tasks.push({
        id: `${recipe.id}_wash_chop`,
        recipeId: recipe.id,
        taskType: 'washChop',
        titleEn: 'Wash & Chop Vegetables',
        titleNe: 'तरकारी धुने र काट्ने',
        descriptionEn: `Wash lentils/rice and finely chop vegetables (${ingredientsSummary}).`,
        descriptionNe: 'दाल/चामल पखाल्ने र तरकारी तयार गर्ने।',
        estimatedMinutes: Math.min(20, Math.max(5, Math.round(recipe.prepTimeMinutes * 0.6))),
        minimumAge: 5,
        isKidFriendly: true,
        requiresSupervision: true,
        isParallel: true,
        status: 'pending',
      });
    }

    // 2. Grind Masala (Prep)
    const needsGrinding = recipe.ingredients.some((i) => {
      const id = i.ingredientId.toLowerCase();
      return (
        id.includes('ginger') ||
        id.includes('garlic') ||
        id.includes('chilli') ||
        id.includes('cumin') ||
        id.includes('coriander') ||
        id.includes('masala')
      );
    });

    if (needsGrinding) {
      tasks.push({
        id: `${recipe.id}_grind_masala`,
        recipeId: recipe.id,
        taskType: 'grindMasala',
        titleEn: 'Grind Fresh Masala',
        titleNe: 'ताजा मसला पिस्ने',
        descriptionEn: 'Pound ginger, garlic, and fresh whole spices on silauto or blender.',
        descriptionNe: 'अदुवा, लसुन र मसला पिस्ने वा सिलौटोमा कुट्ने।',
        estimatedMinutes: 8,
        minimumAge: 10,
        isKidFriendly: true,
        requiresSupervision: false,
        isParallel: true,
        status: 'pending',
      });
    }

    // 3. Watch Cooker (Pressure Cooking / Whistle Monitoring)
    if (recipe.pressureCooker && recipe.pressureCooker.enabled && recipe.pressureCooker.recommendedWhistles > 0) {
      const whistles = recipe.pressureCooker.recommendedWhistles;
      tasks.push({
        id: `${recipe.id}_watch_cooker`,
        recipeId: recipe.id,
        taskType: 'watchCooker',
        titleEn: `Watch Pressure Cooker (${whistles} whistles)`,
        titleNe: `कुकरको सिट्टी गन्ने (${whistles} सिट्टी)`,
        descriptionEn: `Keep an ear out for the pressure cooker and count ${whistles} whistles from a safe distance.`,
        descriptionNe: `सुरक्षित दूरीबाट कुकरको ${whistles} सिट्टी गन्ने र ध्यान राख्ने।`,
        estimatedMinutes: Math.min(30, Math.max(8, Math.round(recipe.cookTimeMinutes * 0.7))),
        minimumAge: 5,
        isKidFriendly: true,
        requiresSupervision: false,
        isParallel: false,
        status: 'pending',
      });
    }

    // 4. Roll Rotis (Active Cooking for flatbreads/rotis)
    if (isBreadOrRoti) {
      tasks.push({
        id: `${recipe.id}_roll_rotis`,
        recipeId: recipe.id,
        taskType: 'rollRotis',
        titleEn: 'Roll & Cook Hot Rotis',
        titleNe: 'रोटी बेल्ने र सेक्ने',
        descriptionEn: 'Knead dough portions, roll round rotis with belan, and flip on hot tava.',
        descriptionNe: 'पिठोको लोला बनाउने, गोलो रोटी बेल्ने र तावामा सेक्ने।',
        estimatedMinutes: Math.min(25, Math.max(10, Math.round(recipe.cookTimeMinutes * 0.8))),
        minimumAge: 12,
        isKidFriendly: false,
        requiresSupervision: false,
        isParallel: true,
        status: 'pending',
      });
    }

    // 5. Simmer & Stir (Tadka, Sauteing, Seasoning)
    tasks.push({
      id: `${recipe.id}_simmer_stir`,
      recipeId: recipe.id,
      taskType: 'simmerStir',
      titleEn: 'Temper Tadka & Simmer',
      titleNe: 'झान्न र चलाउन',
      descriptionEn: 'Heat oil/ghee, temper fenugreek and cumin, saute, and stir until tender.',
      descriptionNe: 'तेल/घ्यूमा मेथी जिरा झाङ्ने, भुट्ने र चलाउने।',
      estimatedMinutes: Math.min(35, Math.max(10, recipe.cookTimeMinutes)),
      minimumAge: 14,
      isKidFriendly: false,
      requiresSupervision: false,
      isParallel: false,
      status: 'pending',
    });

    // 6. Clean-up & Table Setup
    tasks.push({
      id: `${recipe.id}_clean_up`,
      recipeId: recipe.id,
      taskType: 'cleanUp',
      titleEn: 'Clean-up & Set the Table',
      titleNe: 'थाल लगाउने र भान्सा सफा गर्ने',
      descriptionEn: 'Set katoris, plates, and water glasses, then wash prep utensils and wipe counters.',
      descriptionNe: 'थाल, कचौरा र पानीको गिलास राख्ने, र भान्साको काउन्टर सफा गर्ने।',
      estimatedMinutes: 10,
      minimumAge: 4,
      isKidFriendly: true,
      requiresSupervision: false,
      isParallel: true,
      status: 'pending',
    });

    return tasks;
  }

  /**
   * Assigns tasks based on age appropriateness, skill, and preference.
   */
  static assignTasks({
    tasks,
    crew,
    leadCookMemberId,
    history,
  }: {
    tasks: CookTask[];
    crew: MemberCrewProfile[];
    leadCookMemberId?: string;
    history?: RotaContributionRecord[];
  }): CookTask[] {
    if (!crew || crew.length === 0) return tasks;

    const availableCrew = crew.filter((m) => m.isAvailable !== false);
    if (availableCrew.length === 0) return tasks;

    const currentSessionLoad: Record<string, number> = {};
    const historicalTaskTypeCount: Record<string, Record<TaskType, number>> = {};

    for (const m of availableCrew) {
      currentSessionLoad[m.memberId] = 0;
      historicalTaskTypeCount[m.memberId] = {
        washChop: 0,
        grindMasala: 0,
        watchCooker: 0,
        rollRotis: 0,
        simmerStir: 0,
        cleanUp: 0,
      };
    }

    if (history) {
      for (const rec of history) {
        if (historicalTaskTypeCount[rec.memberId]) {
          historicalTaskTypeCount[rec.memberId][rec.taskType] =
            (historicalTaskTypeCount[rec.memberId][rec.taskType] || 0) + 1;
        }
      }
    }

    const leadCook =
      availableCrew.find((m) => m.memberId === leadCookMemberId) || availableCrew[0];

    for (const task of tasks) {
      const eligible = availableCrew.filter((m) => {
        const ageGroup = m.ageGroup || getAgeGroup(m.age);
        return canPerformTask(ageGroup, task.taskType);
      });
      if (eligible.length === 0) continue;

      let bestCandidate: MemberCrewProfile | null = null;
      let highestScore = -9999;

      for (const candidate of eligible) {
        let score = 0;
        const ageGroup = candidate.ageGroup || getAgeGroup(candidate.age);

        // Lead cook gets primary cooking tasks
        if (
          candidate.memberId === leadCook.memberId &&
          (task.taskType === 'simmerStir' || task.taskType === 'rollRotis')
        ) {
          score += 50;
        }

        // Children / toddlers get priority for safe fun tasks
        if (ageGroup === 'child' && task.taskType === 'watchCooker') {
          score += 40;
        }
        if (ageGroup === 'toddler' && task.taskType === 'cleanUp') {
          score += 30;
        }

        // Preference boost
        if (candidate.preferredTasks && candidate.preferredTasks.includes(task.taskType)) {
          score += 25;
        }

        // Avoided task penalty
        if (candidate.avoidedTasks && candidate.avoidedTasks.includes(task.taskType)) {
          score -= 40;
        }

        // Rota rotation penalty for repeated tasks
        const pastCount = historicalTaskTypeCount[candidate.memberId]?.[task.taskType] || 0;
        score -= pastCount * 3;

        // Session load balancing
        const load = currentSessionLoad[candidate.memberId] || 0;
        score -= load * 15;

        if (score > highestScore) {
          highestScore = score;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate) {
        task.assignedMemberId = bestCandidate.memberId;
        task.assignedMemberName = bestCandidate.name;
        currentSessionLoad[bestCandidate.memberId] =
          (currentSessionLoad[bestCandidate.memberId] || 0) + 1;
      }
    }

    return tasks;
  }

  /**
   * Generates a warm, friendly invitation prompt for the lead cook.
   * Example: "Invite Sita & Rohan to help with Dal Bhat?"
   */
  static generateInvitationPrompt({
    recipe,
    leadCook,
    crew,
    assignedTasks,
  }: {
    recipe: RegionRecipe;
    leadCook: MemberCrewProfile;
    crew: MemberCrewProfile[];
    assignedTasks: CookTask[];
  }): string {
    const otherCrew = crew.filter(
      (m) => m.memberId !== leadCook.memberId && m.isAvailable !== false
    );
    if (otherCrew.length === 0) {
      return `Ready to cook ${recipe.titleEn}? All tasks are set for you!`;
    }

    const names = otherCrew.map((m) => m.name);
    const namesString =
      names.length === 1
        ? names[0]
        : names.length === 2
        ? `${names[0]} & ${names[1]}`
        : `${names.slice(0, -1).join(', ')} & ${names[names.length - 1]}`;

    const highlights: string[] = [];
    for (const member of otherCrew.slice(0, 2)) {
      const task = assignedTasks.find((t) => t.assignedMemberId === member.memberId);
      if (task) {
        if (task.taskType === 'watchCooker') {
          highlights.push(`${member.name} can count whistles`);
        } else if (task.taskType === 'rollRotis') {
          highlights.push(`${member.name} can roll hot rotis`);
        } else if (task.taskType === 'washChop') {
          highlights.push(`${member.name} can prep & chop`);
        } else if (task.taskType === 'grindMasala') {
          highlights.push(`${member.name} can grind fresh masala`);
        } else if (task.taskType === 'cleanUp') {
          highlights.push(`${member.name} can set the table`);
        }
      }
    }

    const detail = highlights.length > 0 ? ` (${highlights.join(', ')})` : '';
    return `Invite ${namesString} to help with ${recipe.titleEn}?${detail}`;
  }

  /**
   * Calculates non-shaming fair-share summary highlighting teamwork.
   */
  static calculateFairShareSummary({
    crew,
    history,
  }: {
    crew: MemberCrewProfile[];
    history: RotaContributionRecord[];
  }): FairShareSummary {
    const sessionIds = new Set(history.map((h) => h.sessionId));
    const totalSessions = sessionIds.size;
    const totalTasks = history.length;

    const memberSummaries: MemberContributionSummary[] = [];

    for (const member of crew) {
      const memberRecords = history.filter((r) => r.memberId === member.memberId);
      const leadCount = memberRecords.filter((r) => r.role === 'leadCook').length;
      const coCookCount = memberRecords.filter(
        (r) => r.role === 'coCook' || r.role === 'helper'
      ).length;

      const byType: Record<TaskType, number> = {
        washChop: 0,
        grindMasala: 0,
        watchCooker: 0,
        rollRotis: 0,
        simmerStir: 0,
        cleanUp: 0,
      };

      for (const r of memberRecords) {
        byType[r.taskType] = (byType[r.taskType] || 0) + 1;
      }

      let badge = 'Kitchen Contributor';
      let maxCount = 0;
      let topType: TaskType | null = null;
      for (const [type, count] of Object.entries(byType) as [TaskType, number][]) {
        if (count > maxCount) {
          maxCount = count;
          topType = type;
        }
      }

      if (leadCount >= 3) {
        badge = 'Master Head Chef';
      } else if (topType === 'watchCooker' && maxCount >= 2) {
        badge = 'Whistle Guardian 🔔';
      } else if (topType === 'rollRotis' && maxCount >= 2) {
        badge = 'Roti Artist 🫓';
      } else if (topType === 'washChop' && maxCount >= 2) {
        badge = 'Master Prep Pro 🔪';
      } else if (topType === 'grindMasala' && maxCount >= 2) {
        badge = 'Flavor Alchemist 🌿';
      } else if (topType === 'cleanUp' && maxCount >= 2) {
        badge = 'Table Host & Harmony ✨';
      } else if (memberRecords.length > 0) {
        badge = 'Valued Kitchen Helper 🤝';
      } else {
        badge = 'Ready for Next Feast 🎉';
      }

      memberSummaries.push({
        memberId: member.memberId,
        memberName: member.name,
        totalTasksCompleted: memberRecords.length,
        timesLeadCook: leadCount,
        timesCoCook: coCookCount,
        tasksByType: byType,
        celebratoryBadge: badge,
      });
    }

    const headline =
      totalSessions > 0
        ? `Teamwork this week: ${totalSessions} shared cooking sessions! 🌟`
        : 'Welcome to Co-Cooking! Ready for your first household session?';

    const teamworkInsight =
      totalTasks > 0
        ? `Everyone brings something special to the kitchen table. Cooking together made prep ${
            totalTasks * 4
          } minutes faster!`
        : 'Invite household members to chop, listen for whistles, or set the table.';

    let rotationSuggestion = 'Keep sharing the joy of cooking!';
    if (memberSummaries.length > 0) {
      const leastCleanUp = memberSummaries.reduce((a, b) =>
        (a.tasksByType.cleanUp || 0) <= (b.tasksByType.cleanUp || 0) ? a : b
      );
      rotationSuggestion = `Next session tip: Let ${leastCleanUp.memberName} try table styling or gentle clean-up!`;
    }

    return {
      totalSessions,
      totalTasksCompleted: totalTasks,
      memberSummaries,
      celebratoryHeadline: headline,
      teamworkInsight,
      rotationSuggestion,
    };
  }
}
