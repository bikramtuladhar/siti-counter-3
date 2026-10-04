import { MealConsumptionLog } from './consumption_engine.js';
import { toDevanagariDigits } from './nepali_calendar.js';

export type StorageCondition = 'refrigerated' | 'roomTemperature';

export type ClimateZone = 'hotSummer' | 'temperate' | 'coolWinter';

export type LeftoverUrgency = 'fresh' | 'eatSoon' | 'urgent' | 'expired';

export interface ExpiryInfo {
  useByDate: Date;
  shelfLifeHours: number;
  urgency: LeftoverUrgency;
  isEatFirst: boolean;
  messageEn: string;
  messageNe: string;
}

export interface TrackedLeftover {
  id: string;
  mealLogId?: string;
  recipeId: string;
  titleEn: string;
  titleNe: string;
  servingsRemaining: number;
  remainingGrams: number;
  preparedAt: Date | string;
  useByDate: Date | string;
  storageCondition: StorageCondition;
  isConsumed: boolean;
  consumedAt?: Date | string;
  isDiscarded: boolean;
  discardReason?: string;
}

export interface WasteInsight {
  recipeId: string;
  recipeTitle: string;
  dayOfWeek: number; // 1 = Monday .. 7 = Sunday
  dayNameEn: string;
  dayNameNe: string;
  occurrences: number;
  averagePreparedServings: number;
  averageConsumedServings: number;
  recommendedServings: number;
  averageLeftoverGrams: number;
  estimatedMonthlySavingsNpr: number;
  insightEn: string;
  insightNe: string;
}

export interface HouseholdWasteSummary {
  totalLeftoversTracked: number;
  activeLeftoversCount: number;
  eatFirstCount: number;
  consumedCount: number;
  discardedCount: number;
  expiredCount: number;
  wastePreventionRate: number;
  totalGramsSaved: number;
  insights: WasteInsight[];
  gentleFeedbackEn: string;
  gentleFeedbackNe: string;
}

export function toDate(d: Date | string): Date {
  return typeof d === 'string' ? new Date(d) : d;
}

export function getLeftoverUrgency(leftover: TrackedLeftover, now?: Date | string): LeftoverUrgency {
  if (leftover.isConsumed || leftover.isDiscarded) return 'fresh';
  const current = now ? toDate(now) : new Date();
  const useBy = toDate(leftover.useByDate);
  const diffMinutes = Math.floor((useBy.getTime() - current.getTime()) / (60 * 1000));

  if (diffMinutes <= 0) return 'expired';
  if (diffMinutes <= 240) return 'urgent'; // <= 4 hours
  if (diffMinutes <= 720) return 'eatSoon'; // <= 12 hours
  return 'fresh';
}

export function isEatFirst(leftover: TrackedLeftover, now?: Date | string): boolean {
  const u = getLeftoverUrgency(leftover, now);
  return u === 'urgent' || u === 'eatSoon';
}

const DAY_NAMES = [
  { en: 'Monday', ne: 'सोमबार' },
  { en: 'Tuesday', ne: 'मङ्गलबार' },
  { en: 'Wednesday', ne: 'बुधबार' },
  { en: 'Thursday', ne: 'बिहीबार' },
  { en: 'Friday', ne: 'शुक्रबार' },
  { en: 'Saturday', ne: 'शनिबार' },
  { en: 'Sunday', ne: 'आइतबार' },
];

export class WasteEngine {
  static getBaseShelfLifeHours({
    dishCategory,
    storage,
    climate,
  }: {
    dishCategory: string;
    storage: StorageCondition;
    climate: ClimateZone;
  }): number {
    const cat = dishCategory.toLowerCase();
    const isRice = cat.includes('rice') || cat.includes('bhat');
    const isDal = cat.includes('dal') || cat.includes('pulse') || cat.includes('curry');
    const isMeat = cat.includes('meat') || cat.includes('chicken') || cat.includes('buff') || cat.includes('mutton');
    const isRoti = cat.includes('roti') || cat.includes('bread') || cat.includes('chapati');

    if (storage === 'refrigerated') {
      if (isRice) return 36;
      if (isMeat) return 48;
      if (isDal) return 48;
      if (isRoti) return 72;
      return 48;
    } else {
      switch (climate) {
        case 'hotSummer':
          if (isMeat) return 6;
          if (isRice) return 8;
          if (isDal) return 8;
          if (isRoti) return 24;
          return 8;
        case 'temperate':
          if (isMeat) return 10;
          if (isRice) return 10;
          if (isDal) return 12;
          if (isRoti) return 30;
          return 12;
        case 'coolWinter':
          if (isMeat) return 14;
          if (isRice) return 14;
          if (isDal) return 20;
          if (isRoti) return 36;
          return 18;
      }
    }
  }

  static calculateExpiry({
    preparedAt,
    dishCategory = 'dal',
    storage = 'refrigerated',
    climate = 'temperate',
    now,
  }: {
    preparedAt: Date | string;
    dishCategory?: string;
    storage?: StorageCondition;
    climate?: ClimateZone;
    now?: Date | string;
  }): ExpiryInfo {
    const current = now ? toDate(now) : new Date();
    const prep = toDate(preparedAt);
    const hours = WasteEngine.getBaseShelfLifeHours({ dishCategory, storage, climate });
    const useBy = new Date(prep.getTime() + hours * 3600 * 1000);
    const diffMinutes = Math.floor((useBy.getTime() - current.getTime()) / (60 * 1000));

    let urgency: LeftoverUrgency;
    let isEatFirstFlag: boolean;
    let msgEn: string;
    let msgNe: string;

    if (diffMinutes <= 0) {
      urgency = 'expired';
      isEatFirstFlag = false;
      msgEn = 'Use-by time passed. Check smell and appearance before consuming.';
      msgNe = 'उपभोग गर्ने समय सकियो। खानुअघि सुँघेर र हेरेर यकिन गर्नुहोस्।';
    } else if (diffMinutes <= 240) {
      urgency = 'urgent';
      isEatFirstFlag = true;
      msgEn = 'Eat first: best enjoyed in your next meal or today.';
      msgNe = 'पहिले खानुहोस्: आजकै अर्को छाकमा खानु उत्तम हुन्छ।';
    } else if (diffMinutes <= 720) {
      urgency = 'eatSoon';
      isEatFirstFlag = true;
      msgEn = 'Eat soon: good for today’s lunch or dinner.';
      msgNe = 'चाँडै खानुहोस्: आजको खाना वा खाजाका लागि उपयुक्त छ।';
    } else {
      urgency = 'fresh';
      isEatFirstFlag = false;
      msgEn = 'Fresh and safely stored.';
      msgNe = 'ताजा छ, सुरक्षित रूपमा राखिएको छ।';
    }

    return {
      useByDate: useBy,
      shelfLifeHours: hours,
      urgency,
      isEatFirst: isEatFirstFlag,
      messageEn: msgEn,
      messageNe: msgNe,
    };
  }

  static createFromMealLog({
    log,
    id,
    storage = 'refrigerated',
    climate = 'temperate',
    singleServingStandardGrams = 250.0,
    now,
  }: {
    log: MealConsumptionLog;
    id?: string;
    storage?: StorageCondition;
    climate?: ClimateZone;
    singleServingStandardGrams?: number;
    now?: Date | string;
  }): TrackedLeftover | null {
    const totalConsumed = log.memberPortions
      .filter((p) => !p.skipped)
      .reduce((sum, p) => sum + p.calculatedGrams, 0);

    let excessGrams = 0;
    if (log.leftoverGrams !== undefined && log.leftoverGrams !== null && log.leftoverGrams > 0) {
      excessGrams = log.leftoverGrams;
    } else if (log.batchYieldGrams !== undefined && log.batchYieldGrams !== null && log.batchYieldGrams > totalConsumed) {
      excessGrams = log.batchYieldGrams - totalConsumed;
    } else {
      return null;
    }

    if (excessGrams < 50.0) {
      return null;
    }

    const estimatedServings = Math.max(1, Math.min(20, Math.round(excessGrams / singleServingStandardGrams)));
    const prep = toDate(log.consumedAt);
    const expiry = WasteEngine.calculateExpiry({
      preparedAt: prep,
      dishCategory: log.recipeTitle,
      storage,
      climate,
      now,
    });

    return {
      id: id ?? `leftover_${log.id}`,
      mealLogId: log.id,
      recipeId: log.recipeId,
      titleEn: log.recipeTitle,
      titleNe: log.recipeTitle,
      servingsRemaining: estimatedServings,
      remainingGrams: excessGrams,
      preparedAt: prep,
      useByDate: expiry.useByDate,
      storageCondition: storage,
      isConsumed: false,
      isDiscarded: false,
    };
  }

  static analyzeWastePatterns(
    logs: MealConsumptionLog[],
    options?: {
      minimumOccurrences?: number;
      singleServingStandardGrams?: number;
      estimatedCostPerServingNpr?: number;
    }
  ): WasteInsight[] {
    const minimumOccurrences = options?.minimumOccurrences ?? 2;
    const singleServingGrams = options?.singleServingStandardGrams ?? 250.0;
    const costPerServing = options?.estimatedCostPerServingNpr ?? 65.0;

    const buckets = new Map<string, {
      preparedServings: number;
      consumedServings: number;
      leftoverGrams: number;
      title: string;
      recipeId: string;
      dayOfWeek: number;
    }[]>();

    for (const log of logs) {
      const totalConsumed = log.memberPortions
        .filter((p) => !p.skipped)
        .reduce((sum, p) => sum + p.calculatedGrams, 0);

      let leftoverGrams = 0;
      if (log.leftoverGrams !== undefined && log.leftoverGrams !== null && log.leftoverGrams > 0) {
        leftoverGrams = log.leftoverGrams;
      } else if (log.batchYieldGrams !== undefined && log.batchYieldGrams !== null && log.batchYieldGrams > totalConsumed) {
        leftoverGrams = log.batchYieldGrams - totalConsumed;
      }

      if (leftoverGrams >= 80.0) {
        const consumedDate = toDate(log.consumedAt);
        // In JS Date: 0 = Sun, 1 = Mon, ..., 6 = Sat. Convert to 1 = Mon .. 7 = Sun
        const jsDay = consumedDate.getDay();
        const dayOfWeek = jsDay === 0 ? 7 : jsDay;
        const key = `${log.recipeId}|${dayOfWeek}`;

        const consumedServings = totalConsumed > 0
          ? totalConsumed / singleServingGrams
          : log.totalServings;
        const preparedServings = (totalConsumed + leftoverGrams) / singleServingGrams;

        if (!buckets.has(key)) {
          buckets.set(key, []);
        }
        buckets.get(key)!.push({
          preparedServings,
          consumedServings,
          leftoverGrams,
          title: log.recipeTitle,
          recipeId: log.recipeId,
          dayOfWeek,
        });
      }
    }

    const insights: WasteInsight[] = [];

    for (const [, entries] of buckets.entries()) {
      if (entries.length >= minimumOccurrences) {
        const occurrences = entries.length;
        const first = entries[0];
        const avgPrepared = entries.reduce((s, x) => s + x.preparedServings, 0) / occurrences;
        const avgConsumed = entries.reduce((s, x) => s + x.consumedServings, 0) / occurrences;
        const avgLeftoverG = entries.reduce((s, x) => s + x.leftoverGrams, 0) / occurrences;

        const prepRound = Math.round(avgPrepared);
        const recRound = Math.max(1, Math.min(20, Math.round(avgConsumed)));

        if (prepRound > recRound) {
          const dayIdx = first.dayOfWeek - 1;
          const dayPair = DAY_NAMES[dayIdx];
          const title = first.title;

          const monthlySavings = (prepRound - recRound) * costPerServing * 4;

          const prepNe = toDevanagariDigits(prepRound);
          const recNe = toDevanagariDigits(recRound);

          const insightEn = `${title} is often left over on ${dayPair.en}s; try ${recRound} servings instead of ${prepRound}.`;
          const insightNe = `${dayPair.ne} ${title} प्रायः बाँकी रहने गर्छ; ${prepNe} भागको सट्टा ${recNe} भाग पकाउनुहोस्।`;

          insights.push({
            recipeId: first.recipeId,
            recipeTitle: title,
            dayOfWeek: first.dayOfWeek,
            dayNameEn: dayPair.en,
            dayNameNe: dayPair.ne,
            occurrences,
            averagePreparedServings: avgPrepared,
            averageConsumedServings: avgConsumed,
            recommendedServings: recRound,
            averageLeftoverGrams: avgLeftoverG,
            estimatedMonthlySavingsNpr: monthlySavings,
            insightEn,
            insightNe,
          });
        }
      }
    }

    return insights;
  }

  static calculateWasteSummary({
    leftovers,
    recentMealLogs = [],
    now,
  }: {
    leftovers: TrackedLeftover[];
    recentMealLogs?: MealConsumptionLog[];
    now?: Date | string;
  }): HouseholdWasteSummary {
    const current = now ? toDate(now) : new Date();

    let activeCount = 0;
    let eatFirstCount = 0;
    let consumedCount = 0;
    let discardedCount = 0;
    let expiredCount = 0;
    let gramsSaved = 0;

    for (const l of leftovers) {
      if (l.isConsumed) {
        consumedCount++;
        gramsSaved += l.remainingGrams;
      } else if (l.isDiscarded) {
        discardedCount++;
      } else {
        activeCount++;
        const urgency = getLeftoverUrgency(l, current);
        if (urgency === 'expired') {
          expiredCount++;
        } else if (urgency === 'urgent' || urgency === 'eatSoon') {
          eatFirstCount++;
        }
      }
    }

    const totalResolved = consumedCount + discardedCount + expiredCount;
    const preventionRate = totalResolved > 0
      ? Math.max(0, Math.min(100, (consumedCount / totalResolved) * 100))
      : 100.0;

    const insights = WasteEngine.analyzeWastePatterns(recentMealLogs);

    let feedbackEn: string;
    let feedbackNe: string;

    if (activeCount === 0 && eatFirstCount === 0) {
      feedbackEn = 'Kitchen fridge is tidy. No leftover dish is pending.';
      feedbackNe = 'भान्सा सफा र व्यवस्थित छ। कुनै खाना बाँकी छैन।';
    } else if (eatFirstCount > 0) {
      feedbackEn = `${eatFirstCount} dish needs eating first today to prevent waste.`;
      feedbackNe = `खाना खेर जान नदिन आज ${eatFirstCount} वटा परिकार पहिले खानुहोस्।`;
    } else {
      feedbackEn = `${activeCount} dishes safely stored for upcoming meals.`;
      feedbackNe = `${activeCount} वटा परिकार आगामी छाकका लागि सुरक्षित छन्।`;
    }

    return {
      totalLeftoversTracked: leftovers.length,
      activeLeftoversCount: activeCount,
      eatFirstCount,
      consumedCount,
      discardedCount,
      expiredCount,
      wastePreventionRate: preventionRate,
      totalGramsSaved: gramsSaved,
      insights,
      gentleFeedbackEn: feedbackEn,
      gentleFeedbackNe: feedbackNe,
    };
  }
}
