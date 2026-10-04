import { UuidV7 } from './sync_engine.js'

/**
 * Supported physical vessel forms for intuitive portioning.
 */
export type VesselType =
  | 'katori' // Small metal/ceramic bowl (150 ml standard) for dal, curries, yogurt
  | 'bowl'   // Medium bowl (250 ml standard) for soups, cereals, salad
  | 'plate'  // Thali / dinner plate (400 g standard) for rice / dal bhat
  | 'ladle'  // Daadu / Panche (60 ml standard) for curries, dal servings
  | 'roti'   // Flatbread piece (40 g standard)
  | 'piece'  // Discrete units (50 g standard) for momo, samosa, bara, wo
  | 'cup'    // Drinking / measuring cup (240 ml standard)

/**
 * A calibrated vessel representation with volume/weight calibration.
 */
export interface CalibratedVessel {
  id: string
  nameEn: string
  nameNe: string
  type: VesselType
  volumeMl: number
  standardGrams: number
  descriptionEn: string
  descriptionNe: string
  isCustom?: boolean
}

export const STANDARD_VESSELS: CalibratedVessel[] = [
  {
    id: 'katori',
    nameEn: 'Katori (Small Bowl)',
    nameNe: 'कचौरा / कटोरी',
    type: 'katori',
    volumeMl: 150.0,
    standardGrams: 150.0,
    descriptionEn: 'Standard small steel katori for dal, vegetable tarkari, or yogurt.',
    descriptionNe: 'दाल, तरकारी वा दही खाने सानो कचौरा।',
  },
  {
    id: 'bowl',
    nameEn: 'Medium Bowl',
    nameNe: 'मध्यम कचौरा / बाउल',
    type: 'bowl',
    volumeMl: 250.0,
    standardGrams: 250.0,
    descriptionEn: 'Medium deep bowl for soup, thukpa, or oats.',
    descriptionNe: 'सुप, थुक्पा वा खाजा खाने मध्यम कचौरा।',
  },
  {
    id: 'plate',
    nameEn: 'Dinner Plate / Thali',
    nameNe: 'थाली / प्लेट',
    type: 'plate',
    volumeMl: 400.0,
    standardGrams: 400.0,
    descriptionEn: 'Standard plate mound for rice, dal bhat, or noodles.',
    descriptionNe: 'दाल-भात वा मुख्य खाना पस्कने थाली।',
  },
  {
    id: 'ladle',
    nameEn: 'Ladle (Dadu)',
    nameNe: 'डडु / पन्चे',
    type: 'ladle',
    volumeMl: 60.0,
    standardGrams: 60.0,
    descriptionEn: 'Serving ladle for pouring dal, curry, or gravies.',
    descriptionNe: 'दाल र रसदार तरकारी पस्कने डडु।',
  },
  {
    id: 'roti',
    nameEn: 'Roti / Chapati',
    nameNe: 'रोटी',
    type: 'roti',
    volumeMl: 40.0,
    standardGrams: 40.0,
    descriptionEn: 'Count of whole wheat flatbreads or pancakes.',
    descriptionNe: 'गहुँको रोटी वा चपाती।',
  },
  {
    id: 'piece',
    nameEn: 'Piece (Bara/Momo/Snack)',
    nameNe: 'टुक्रा / पिस',
    type: 'piece',
    volumeMl: 50.0,
    standardGrams: 50.0,
    descriptionEn: 'Discrete count for momos, bara, wo, or samosas.',
    descriptionNe: 'म:म, बारा, समोसा वा खाजाको गणना।',
  },
  {
    id: 'cup',
    nameEn: 'Cup (Chiya/Milk)',
    nameNe: 'कप',
    type: 'cup',
    volumeMl: 240.0,
    standardGrams: 240.0,
    descriptionEn: 'Standard drinking cup for tea, milk, or beverage.',
    descriptionNe: 'चिया वा दूध पिउने कप।',
  },
]

/**
 * Household calibration container for vessel customization.
 */
export class HouseholdVesselProfile {
  public customVolumes: Record<string, number>

  constructor(customVolumes: Record<string, number> = {}) {
    this.customVolumes = { ...customVolumes }
  }

  public getEffectiveVessel(vesselId: string): CalibratedVessel {
    const standard =
      STANDARD_VESSELS.find((v) => v.id === vesselId) ?? STANDARD_VESSELS[0]
    if (this.customVolumes[vesselId] !== undefined) {
      const customVol = this.customVolumes[vesselId]
      return {
        ...standard,
        volumeMl: customVol,
        standardGrams: customVol, // 1 ml ≈ 1 g assumption for cooked foods
        isCustom: true,
      }
    }
    return standard
  }

  public toJSON() {
    return {
      customVolumes: this.customVolumes,
    }
  }

  public static fromJSON(json: { customVolumes?: Record<string, number> }): HouseholdVesselProfile {
    return new HouseholdVesselProfile(json.customVolumes ?? {})
  }
}

/**
 * Member dietary and portion configuration.
 */
export interface MemberDietaryProfile {
  memberId: string
  name: string
  role?: string // 'Adult' | 'Child' | 'Toddler' | 'Elderly'
  nutritionProfile?: string // 'everyday' | 'child' | 'baby' | 'elderly' | 'pregnancy' | 'fitness'
  portionMultiplier?: number
  preferredVesselId?: string
  defaultVesselCount?: number
}

export function isChildOrBaby(profile: MemberDietaryProfile): boolean {
  const nut = profile.nutritionProfile?.toLowerCase() ?? 'everyday'
  const role = profile.role?.toLowerCase() ?? 'adult'
  return nut === 'child' || nut === 'baby' || role === 'child' || role === 'toddler'
}

/**
 * Portion entry for an individual member during a meal.
 */
export interface MemberConsumptionEntry {
  memberId: string
  memberName: string
  vesselId: string
  vesselCount: number
  calculatedGrams: number
  ateUsual: boolean
  skipped?: boolean
  notes?: string
}

/**
 * Fully logged home-cooked meal consumption record.
 */
export interface MealConsumptionLog {
  id: string
  mealPlanId?: string
  recipeId: string
  recipeTitle: string
  mealSlot: string
  consumedAt: string // ISO-8601
  memberPortions: MemberConsumptionEntry[]
  totalServings: number
  loggedAsUsual: boolean
  batchYieldGrams?: number
  leftoverGrams?: number
}

/**
 * Outside food or quick-add snack consumption record.
 */
export interface OutsideFoodEntry {
  id: string
  memberId: string
  memberName: string
  foodName: string
  mealSlot: string
  consumedAt: string // ISO-8601
  portionSize: string // 'small', 'medium', 'large'
  estimatedCalories?: number
  tags: string[]
}

/**
 * Member weekly summary reflecting gentle, non-shaming health metrics.
 */
export interface MemberConsumptionSummary {
  memberId: string
  memberName: string
  nutritionProfile: string
  mealsLogged: number
  mealsSkipped: number
  snacksLogged: number
  totalGramsConsumed: number
  estimatedCalories?: number | null // Strictly null for child/baby to avoid shaming
  gentleFeedback: string
}

/**
 * Full household weekly nutrition & consumption summary.
 */
export interface WeeklyHouseholdSummary {
  weekStartDate: string
  weekEndDate: string
  totalMealsLogged: number
  totalHomeCookedMeals: number
  totalOutsideSnacksLogged: number
  usualComplianceRate: number // % confirmed as "Yes, usual"
  mealSlotFrequencies: Record<string, number>
  memberSummaries: MemberConsumptionSummary[]
  householdRhythmStatus: string
  gentleFamilyFeedback: string
}

export interface LogUsualMealParams {
  id?: string
  mealPlanId?: string
  recipeId: string
  recipeTitle: string
  mealSlot: string
  consumedAt?: Date | string
  members: MemberDietaryProfile[]
  vesselProfile?: HouseholdVesselProfile
  batchYieldGrams?: number
  leftoverGrams?: number
}

export interface PortionAdjustment {
  vesselId: string
  vesselCount: number
  skipped?: boolean
  notes?: string
}

export interface LogAdjustedMealParams {
  id?: string
  mealPlanId?: string
  recipeId: string
  recipeTitle: string
  mealSlot: string
  consumedAt?: Date | string
  members: MemberDietaryProfile[]
  adjustments: Record<string, PortionAdjustment>
  vesselProfile?: HouseholdVesselProfile
  batchYieldGrams?: number
  leftoverGrams?: number
}

export interface QuickAddOutsideFoodParams {
  id?: string
  memberId: string
  memberName: string
  foodName: string
  mealSlot?: string
  consumedAt?: Date | string
  portionSize?: string
  estimatedCalories?: number
  tags?: string[]
}

export interface CalculateWeeklySummaryParams {
  weekStart: Date | string
  weekEnd: Date | string
  mealLogs: MealConsumptionLog[]
  outsideLogs: OutsideFoodEntry[]
  members: MemberDietaryProfile[]
}

/**
 * Core domain engine for minimal-effort meal logging and vessel calibration.
 */
export class ConsumptionEngine {
  /**
   * Logs a meal immediately when user confirms "Yes, everyone ate their usual".
   */
  public static logUsualMeal(params: LogUsualMealParams): MealConsumptionLog {
    const logId = params.id ?? UuidV7.generate()
    const logTime =
      typeof params.consumedAt === 'string'
        ? params.consumedAt
        : (params.consumedAt ?? new Date()).toISOString()
    const vesselProfile = params.vesselProfile ?? new HouseholdVesselProfile()

    const portions: MemberConsumptionEntry[] = []
    let totalServings = 0

    for (const m of params.members) {
      const preferredVesselId = m.preferredVesselId ?? 'katori'
      const defaultCount = m.defaultVesselCount ?? 1.0
      const portionMultiplier = m.portionMultiplier ?? 1.0

      const vessel = vesselProfile.getEffectiveVessel(preferredVesselId)
      const grams = vessel.standardGrams * defaultCount * portionMultiplier

      portions.push({
        memberId: m.memberId,
        memberName: m.name,
        vesselId: preferredVesselId,
        vesselCount: defaultCount,
        calculatedGrams: grams,
        ateUsual: true,
        skipped: false,
      })
      totalServings += portionMultiplier
    }

    return {
      id: logId,
      mealPlanId: params.mealPlanId,
      recipeId: params.recipeId,
      recipeTitle: params.recipeTitle,
      mealSlot: params.mealSlot,
      consumedAt: logTime,
      memberPortions: portions,
      totalServings,
      loggedAsUsual: true,
      batchYieldGrams: params.batchYieldGrams,
      leftoverGrams: params.leftoverGrams,
    }
  }

  /**
   * Logs a meal when portions were adjusted by vessel or skipped.
   */
  public static logAdjustedMeal(params: LogAdjustedMealParams): MealConsumptionLog {
    const logId = params.id ?? UuidV7.generate()
    const logTime =
      typeof params.consumedAt === 'string'
        ? params.consumedAt
        : (params.consumedAt ?? new Date()).toISOString()
    const vesselProfile = params.vesselProfile ?? new HouseholdVesselProfile()

    const portions: MemberConsumptionEntry[] = []
    let totalServings = 0

    for (const m of params.members) {
      const preferredVesselId = m.preferredVesselId ?? 'katori'
      const defaultCount = m.defaultVesselCount ?? 1.0
      const portionMultiplier = m.portionMultiplier ?? 1.0

      const adj = params.adjustments[m.memberId]
      if (adj) {
        if (adj.skipped) {
          portions.push({
            memberId: m.memberId,
            memberName: m.name,
            vesselId: adj.vesselId || preferredVesselId,
            vesselCount: 0,
            calculatedGrams: 0,
            ateUsual: false,
            skipped: true,
            notes: adj.notes ?? 'Skipped meal',
          })
        } else {
          const vessel = vesselProfile.getEffectiveVessel(adj.vesselId)
          const grams = vessel.standardGrams * adj.vesselCount
          const portionFraction = adj.vesselCount / (defaultCount > 0 ? defaultCount : 1.0)

          portions.push({
            memberId: m.memberId,
            memberName: m.name,
            vesselId: adj.vesselId,
            vesselCount: adj.vesselCount,
            calculatedGrams: grams,
            ateUsual: adj.vesselCount === defaultCount && adj.vesselId === preferredVesselId,
            skipped: false,
            notes: adj.notes,
          })
          totalServings += portionMultiplier * portionFraction
        }
      } else {
        // Fallback to usual
        const vessel = vesselProfile.getEffectiveVessel(preferredVesselId)
        const grams = vessel.standardGrams * defaultCount * portionMultiplier
        portions.push({
          memberId: m.memberId,
          memberName: m.name,
          vesselId: preferredVesselId,
          vesselCount: defaultCount,
          calculatedGrams: grams,
          ateUsual: true,
          skipped: false,
        })
        totalServings += portionMultiplier
      }
    }

    return {
      id: logId,
      mealPlanId: params.mealPlanId,
      recipeId: params.recipeId,
      recipeTitle: params.recipeTitle,
      mealSlot: params.mealSlot,
      consumedAt: logTime,
      memberPortions: portions,
      totalServings,
      loggedAsUsual: false,
      batchYieldGrams: params.batchYieldGrams,
      leftoverGrams: params.leftoverGrams,
    }
  }

  /**
   * Quick adds an outside snack or restaurant meal.
   */
  public static quickAddOutsideFood(params: QuickAddOutsideFoodParams): OutsideFoodEntry {
    const consumedAtStr =
      typeof params.consumedAt === 'string'
        ? params.consumedAt
        : (params.consumedAt ?? new Date()).toISOString()

    return {
      id: params.id ?? UuidV7.generate(),
      memberId: params.memberId,
      memberName: params.memberName,
      foodName: params.foodName,
      mealSlot: params.mealSlot ?? 'snack',
      consumedAt: consumedAtStr,
      portionSize: params.portionSize ?? 'medium',
      estimatedCalories: params.estimatedCalories,
      tags: params.tags ?? [],
    }
  }

  /**
   * Calculates calm, non-shaming weekly summary across household.
   */
  public static calculateWeeklySummary(params: CalculateWeeklySummaryParams): WeeklyHouseholdSummary {
    const startMs =
      typeof params.weekStart === 'string'
        ? new Date(params.weekStart).getTime()
        : params.weekStart.getTime()
    const endMs =
      typeof params.weekEnd === 'string'
        ? new Date(params.weekEnd).getTime()
        : params.weekEnd.getTime()

    const startIso =
      typeof params.weekStart === 'string'
        ? params.weekStart
        : params.weekStart.toISOString()
    const endIso =
      typeof params.weekEnd === 'string'
        ? params.weekEnd
        : params.weekEnd.toISOString()

    const filteredMeals = params.mealLogs.filter((m) => {
      const t = new Date(m.consumedAt).getTime()
      return t >= startMs - 1000 && t <= endMs + 1000
    })

    const filteredOutside = params.outsideLogs.filter((o) => {
      const t = new Date(o.consumedAt).getTime()
      return t >= startMs - 1000 && t <= endMs + 1000
    })

    let usualCount = 0
    const slotFreq: Record<string, number> = {}

    for (const meal of filteredMeals) {
      if (meal.loggedAsUsual) usualCount++
      slotFreq[meal.mealSlot] = (slotFreq[meal.mealSlot] ?? 0) + 1
    }

    const totalMeals = filteredMeals.length
    const usualRate = totalMeals > 0 ? (usualCount / totalMeals) * 100.0 : 100.0

    const memberSummaries: MemberConsumptionSummary[] = []

    for (const m of params.members) {
      let mealsCount = 0
      let skippedCount = 0
      let totalGrams = 0

      for (const meal of filteredMeals) {
        const portion = meal.memberPortions.find((p) => p.memberId === m.memberId)
        if (portion) {
          if (portion.skipped) {
            skippedCount++
          } else {
            mealsCount++
            totalGrams += portion.calculatedGrams
          }
        }
      }

      const snacksCount = filteredOutside.filter((o) => o.memberId === m.memberId).length

      // Section 8 & 11: Children & toddlers are never shown calorie counts.
      const isChild = isChildOrBaby(m)
      let calories: number | null = null
      if (!isChild && mealsCount > 0) {
        // Approximate ~1.3 kcal/g for balanced dal bhat meals
        calories = Math.round(totalGrams * 1.3)
      }

      let gentleFeedback: string
      if (isChild) {
        gentleFeedback =
          mealsCount >= 10
            ? 'उत्कृष्ट पोषण: नियमित घरको खानाले वृद्धि विकासमा राम्रो सहयोग पुगिरहेको छ।'
            : 'सन्तुलित पोषण: विभिन्न प्रकारका फलफूल र दाल मिसाएर खुवाउनु उपयुक्त हुन्छ।'
      } else {
        gentleFeedback =
          mealsCount >= 12
            ? 'उत्कृष्ट लय: प्राय: सबै छाक घरमै पाकेको ताजा र पौष्टिक खाना खाइएको छ।'
            : 'सन्तुलित हप्ता: घरको खानाको मात्रा सन्तोषजनक छ, प्रोटिनयुक्त दाल नियमित गर्नुहोस्।'
      }

      memberSummaries.push({
        memberId: m.memberId,
        memberName: m.name,
        nutritionProfile: m.nutritionProfile ?? 'everyday',
        mealsLogged: mealsCount,
        mealsSkipped: skippedCount,
        snacksLogged: snacksCount,
        totalGramsConsumed: totalGrams,
        estimatedCalories: calories,
        gentleFeedback,
      })
    }

    const rhythmStatus =
      totalMeals >= 12
        ? 'नियमित र सन्तुलित (Consistent)'
        : 'मध्यम (Moderate Rhythm)'

    const familyFeedback =
      totalMeals >= 10
        ? 'तपाईंको परिवारले यस हप्ता धेरैजसो छाक घरमै पाकेको ताजा दाल-भात उपभोग गरेको छ।'
        : 'यस हप्ताको खानाको लय राम्रो छ। नियमित समयमा खाना खाने तालिका कायम राख्नुहोस्।'

    return {
      weekStartDate: startIso,
      weekEndDate: endIso,
      totalMealsLogged: totalMeals,
      totalHomeCookedMeals: totalMeals,
      totalOutsideSnacksLogged: filteredOutside.length,
      usualComplianceRate: usualRate,
      mealSlotFrequencies: slotFreq,
      memberSummaries,
      householdRhythmStatus: rhythmStatus,
      gentleFamilyFeedback: familyFeedback,
    }
  }
}
