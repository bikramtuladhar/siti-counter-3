import { isChildOrBaby, MemberDietaryProfile } from './consumption_engine.js'

export type CompositionSource = 'nfct' | 'ifct'

/** Nutrients per 100 g of the RAW ingredient (Nepal FCT / IFCT). */
export interface FoodComposition {
  id: string
  nameEn: string
  nameNe: string
  foodGroup: string
  kcal: number
  proteinG: number
  fiberG: number
  carbsG: number
  fatG: number
  source: CompositionSource
}

export interface YieldFactor {
  ingredientId: string
  factor: number
  method: string
}

export interface NutrientTotals {
  grams: number
  kcal: number
  proteinG: number
  fiberG: number
  carbsG: number
  fatG: number
}

export interface BatchIngredient {
  ingredientId: string
  rawGrams: number
}

export interface BatchNutrition {
  totals: NutrientTotals
  foodGroups: string[]
  unknownIngredients: string[]
}

export interface PortionIntake {
  nutrients: NutrientTotals
  foodGroups?: string[]
  seasonalFraction?: number
}

export interface NutrientTarget {
  proteinG: number
  fiberG: number
}

export type NutritionLevel = 'warming-up' | 'steady' | 'abundant'

export interface NutritionProgressBar {
  key: string
  fraction: number
  level: NutritionLevel
  messageEn: string
  messageNe: string
}

export interface MemberNutritionView {
  memberId: string
  memberName: string
  nutritionProfile: string
  showsNumbers: boolean
  estimatedKcalPerDay: number | null
  bars: NutritionProgressBar[]
  foodGroupsCovered: string[]
  messageEn: string
  messageNe: string
}

export const ZERO_TOTALS: NutrientTotals = {
  grams: 0,
  kcal: 0,
  proteinG: 0,
  fiberG: 0,
  carbsG: 0,
  fatG: 0,
}

export function addTotals(a: NutrientTotals, b: NutrientTotals): NutrientTotals {
  return {
    grams: a.grams + b.grams,
    kcal: a.kcal + b.kcal,
    proteinG: a.proteinG + b.proteinG,
    fiberG: a.fiberG + b.fiberG,
    carbsG: a.carbsG + b.carbsG,
    fatG: a.fatG + b.fatG,
  }
}

export function scaleTotals(t: NutrientTotals, k: number): NutrientTotals {
  return {
    grams: t.grams * k,
    kcal: t.kcal * k,
    proteinG: t.proteinG * k,
    fiberG: t.fiberG * k,
    carbsG: t.carbsG * k,
    fatG: t.fatG * k,
  }
}

const c = (
  id: string,
  nameEn: string,
  nameNe: string,
  foodGroup: string,
  kcal: number,
  proteinG: number,
  fiberG: number,
  carbsG: number,
  fatG: number,
  source: CompositionSource = 'nfct',
): FoodComposition => ({ id, nameEn, nameNe, foodGroup, kcal, proteinG, fiberG, carbsG, fatG, source })

export const COMPOSITION_TABLE: FoodComposition[] = [
  c('rice', 'Rice', 'चामल', 'grains', 345, 6.8, 0.6, 78.2, 0.5),
  c('wheat-flour', 'Wheat flour (atta)', 'गहुँको पीठो', 'grains', 341, 11.8, 11.4, 71.2, 1.5, 'ifct'),
  c('lentil', 'Lentil (masoor dal)', 'मसुरो दाल', 'pulses', 343, 25.1, 11.4, 59.0, 0.7),
  c('black-lentil', 'Black lentil (kalo dal)', 'कालो दाल', 'pulses', 347, 24.0, 12.0, 59.6, 1.4),
  c('potato', 'Potato', 'आलु', 'vegetables', 97, 1.6, 1.7, 22.6, 0.1),
  c('spinach', 'Spinach (palungo)', 'पालुङ्गो', 'vegetables', 26, 2.0, 0.6, 2.9, 0.7),
  c('cauliflower', 'Cauliflower', 'फूलगोभी', 'vegetables', 30, 2.6, 1.2, 4.0, 0.4),
  c('radish', 'Radish (mula)', 'मूला', 'vegetables', 32, 0.6, 0.8, 7.3, 0.3),
  c('mustard-oil', 'Mustard oil', 'तोरीको तेल', 'fats', 900, 0, 0, 0, 100),
  c('milk', 'Milk', 'दूध', 'dairy', 67, 3.2, 0, 4.4, 4.1),
  c('egg', 'Egg', 'अण्डा', 'protein', 173, 13.3, 0, 0.8, 13.3, 'ifct'),
  c('chicken', 'Chicken', 'कुखुराको मासु', 'protein', 109, 25.9, 0, 0, 0.6, 'ifct'),
  c('banana', 'Banana', 'केरा', 'fruits', 116, 1.2, 0.4, 27.2, 0.3),
]

export const YIELD_FACTORS: YieldFactor[] = [
  { ingredientId: 'rice', factor: 3.0, method: 'boiled' },
  { ingredientId: 'wheat-flour', factor: 1.5, method: 'dough/roti' },
  { ingredientId: 'lentil', factor: 2.5, method: 'boiled' },
  { ingredientId: 'black-lentil', factor: 2.4, method: 'boiled' },
  { ingredientId: 'potato', factor: 0.95, method: 'curried' },
  { ingredientId: 'spinach', factor: 0.5, method: 'sauteed' },
  { ingredientId: 'cauliflower', factor: 0.85, method: 'curried' },
  { ingredientId: 'radish', factor: 0.8, method: 'curried' },
  { ingredientId: 'chicken', factor: 0.75, method: 'curried' },
  { ingredientId: 'egg', factor: 0.95, method: 'boiled' },
]

export const DAILY_TARGETS: Record<string, NutrientTarget> = {
  everyday: { proteinG: 50, fiberG: 25 },
  pregnancy: { proteinG: 71, fiberG: 28 },
  elderly: { proteinG: 55, fiberG: 25 },
  fitness: { proteinG: 90, fiberG: 30 },
}

export const ALL_FOOD_GROUPS = ['grains', 'pulses', 'vegetables', 'fruits', 'dairy', 'protein']

function makeBar(key: string, ratio: number, en: string, ne: string): NutritionProgressBar {
  const fraction = Number.isNaN(ratio) ? 0 : Math.min(1, Math.max(0, ratio))
  const level: NutritionLevel = ratio < 0.6 ? 'warming-up' : ratio < 1.0 ? 'steady' : 'abundant'
  return { key, fraction, level, messageEn: en, messageNe: ne }
}

/** Yield-factor based nutrition engine (Section 11.1, 11.4). Parity with Dart. */
export class NutritionEngine {
  /**
   * Ingredient ids naming a food the table already covers under a different id.
   *
   * Mirrors the Dart engine: the packs and the table disagree on spelling, so an exact-id
   * lookup silently returned nothing and the ingredient contributed zero nutrients.
   */
  static readonly ingredientAliases: Record<string, string> = {
    kalo_dal: 'black-lentil',
    masoor_dal: 'lentil',
    masur_dal: 'lentil',
    masu: 'chicken',
    'chicken-meat': 'chicken',
    kukura: 'chicken',
    ghiu: 'ghee',
    'clarified-butter': 'ghee',
    'tel-paoda': 'spinach',
    palungo: 'spinach',
    saag: 'spinach',
    alu: 'potato',
    kohlrabi: 'cabbage',
    pyaaz: 'onion',
    kershipa: 'onion',
    khaman: 'wheat-flour',
    'momo-skin': 'wheat-flour',
  }

  /** Canonical form of an ingredient id for lookup: folds case and the separator. */
  static normalizeIngredientId(id: string): string {
    return id.trim().toLowerCase().replaceAll('_', '-')
  }

  static compositionFor(id: string): FoodComposition | undefined {
    const exact = COMPOSITION_TABLE.find((x) => x.id === id)
    if (exact) return exact

    const normalized = NutritionEngine.normalizeIngredientId(id)
    const bySeparator = COMPOSITION_TABLE.find((x) => x.id === normalized)
    if (bySeparator) return bySeparator

    const alias = NutritionEngine.ingredientAliases[normalized]
      ?? NutritionEngine.ingredientAliases[id]
    if (alias) return COMPOSITION_TABLE.find((x) => x.id === alias)
    return undefined
  }

  /** Whether [id] resolves to nutrient data. */
  static hasCompositionFor(id: string): boolean {
    return NutritionEngine.compositionFor(id) !== undefined
  }

  /** Cooked grams per raw gram; 1.0 when no factor is known. */
  static yieldFor(id: string): number {
    const exact = YIELD_FACTORS.find((y) => y.ingredientId === id)
    if (exact) return exact.factor

    const normalized = NutritionEngine.normalizeIngredientId(id)
    const bySeparator = YIELD_FACTORS.find((y) => y.ingredientId === normalized)
    if (bySeparator) return bySeparator.factor

    const alias = NutritionEngine.ingredientAliases[normalized]
      ?? NutritionEngine.ingredientAliases[id]
    if (alias) return YIELD_FACTORS.find((y) => y.ingredientId === alias)?.factor ?? 1.0
    return 1.0
  }

  /** Nutrients per 100 g of the COOKED ingredient. */
  static cookedPer100g(id: string): NutrientTotals {
    const comp = NutritionEngine.compositionFor(id)
    if (!comp) return { ...ZERO_TOTALS }
    const f = NutritionEngine.yieldFor(id)
    return {
      grams: 100,
      kcal: comp.kcal / f,
      proteinG: comp.proteinG / f,
      fiberG: comp.fiberG / f,
      carbsG: comp.carbsG / f,
      fatG: comp.fatG / f,
    }
  }

  static computeBatch(ingredients: BatchIngredient[], cookedYieldGrams?: number): BatchNutrition {
    let total: NutrientTotals = { ...ZERO_TOTALS }
    let estimatedCooked = 0
    const groups = new Set<string>()
    const unknown: string[] = []

    for (const ing of ingredients) {
      const comp = NutritionEngine.compositionFor(ing.ingredientId)
      if (!comp || ing.rawGrams <= 0) {
        if (!comp) unknown.push(ing.ingredientId)
        continue
      }
      const k = ing.rawGrams / 100
      total = addTotals(total, {
        grams: 0,
        kcal: comp.kcal * k,
        proteinG: comp.proteinG * k,
        fiberG: comp.fiberG * k,
        carbsG: comp.carbsG * k,
        fatG: comp.fatG * k,
      })
      estimatedCooked += ing.rawGrams * NutritionEngine.yieldFor(ing.ingredientId)
      if (comp.foodGroup !== 'fats') groups.add(comp.foodGroup)
    }

    const cooked = cookedYieldGrams !== undefined && cookedYieldGrams > 0 ? cookedYieldGrams : estimatedCooked
    return {
      totals: { ...total, grams: cooked },
      foodGroups: [...groups],
      unknownIngredients: unknown,
    }
  }

  /** Nutrients in a portion of [grams] cooked food. */
  static portion(batch: BatchNutrition, grams: number): NutrientTotals {
    if (batch.totals.grams <= 0 || grams <= 0) return { ...ZERO_TOTALS }
    return scaleTotals(batch.totals, grams / batch.totals.grams)
  }

  static buildMemberView(
    member: MemberDietaryProfile,
    intakes: PortionIntake[],
    days = 7,
  ): MemberNutritionView {
    const groups = new Set<string>()
    for (const i of intakes) (i.foodGroups ?? []).forEach((g) => groups.add(g))
    const covered = ALL_FOOD_GROUPS.filter((g) => groups.has(g))

    if (isChildOrBaby(member)) {
      const n = covered.length
      return {
        memberId: member.memberId,
        memberName: member.name,
        nutritionProfile: member.nutritionProfile ?? 'everyday',
        showsNumbers: false,
        estimatedKcalPerDay: null,
        bars: [],
        foodGroupsCovered: covered,
        messageEn:
          n >= 4
            ? `A colourful plate this week: ${n} food groups enjoyed.`
            : 'Lovely start. Try adding another colour to a plate soon.',
        messageNe:
          n >= 4
            ? `यो हप्ता रंगीन थाली: ${n} खाद्य समूह खाइयो।`
            : 'राम्रो सुरुवात। चाँडै थालीमा अर्को रंग थप्न सकिन्छ।',
      }
    }

    const profile = member.nutritionProfile ?? 'everyday'
    const target = DAILY_TARGETS[profile] ?? DAILY_TARGETS.everyday
    let sum: NutrientTotals = { ...ZERO_TOTALS }
    let seasonalWeighted = 0
    for (const i of intakes) {
      sum = addTotals(sum, i.nutrients)
      seasonalWeighted += i.nutrients.grams * (i.seasonalFraction ?? 0)
    }
    const d = days <= 0 ? 1 : days
    const protein = sum.proteinG / (target.proteinG * d)
    const fiber = sum.fiberG / (target.fiberG * d)
    const seasonal = sum.grams > 0 ? seasonalWeighted / sum.grams : 0

    return {
      memberId: member.memberId,
      memberName: member.name,
      nutritionProfile: member.nutritionProfile ?? 'everyday',
      showsNumbers: true,
      estimatedKcalPerDay: intakes.length === 0 ? null : Math.round(sum.kcal / d),
      bars: [
        makeBar('protein', protein, 'Protein is building up nicely.', 'प्रोटिन राम्ररी जम्दैछ।'),
        makeBar('fiber', fiber, 'Fibre from dal and vegetables adds up.', 'दाल र तरकारीबाट फाइबर थपिँदैछ।'),
        makeBar('seasonal', seasonal, 'Eating with the season keeps meals fresh.', 'ऋतु अनुसारको खानाले ताजा राख्छ।'),
      ],
      foodGroupsCovered: covered,
      messageEn: 'Every meal counts. Here is this week at a glance.',
      messageNe: 'हरेक खानाको महत्त्व छ। यो हप्ताको झलक यहाँ छ।',
    }
  }
}
