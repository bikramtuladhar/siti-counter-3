import { isChildOrBaby, MemberDietaryProfile } from './consumption_engine.js'

export type CompositionSource = 'nfct' | 'ifct' | 'usda'

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

/**
 * Rows imported from USDA FoodData Central by scripts/import-usda-nutrients.mjs.
 * USDA is a US Government work and therefore public domain.
 */
export const USDA_COMPOSITION_TABLE: FoodComposition[] = [
  // BEGIN generated USDA composition
  // Generated from data/nutrition/usda-composition.json by
  // scripts/sync-usda-composition.mjs. USDA FoodData Central, public domain.
  // Edit the JSON, not this file.
  { id: "bean_sprouts", nameEn: "Soybeans, mature seeds, sprouted, raw", nameNe: "bean_sprouts", foodGroup: "vegetables", kcal: 510, proteinG: 13.1, fiberG: 1.1, carbsG: 9.6, fatG: 6.7, source: 'usda' },
  { id: "bitter_gourd", nameEn: "Balsam-pear (bitter gourd), pods, raw", nameNe: "bitter_gourd", foodGroup: "vegetables", kcal: 71, proteinG: 1, fiberG: 2.8, carbsG: 3.7, fatG: 0.2, source: 'usda' },
  { id: "bottle_gourd", nameEn: "Balsam-pear (bitter gourd), pods, raw", nameNe: "bottle_gourd", foodGroup: "vegetables", kcal: 71, proteinG: 1, fiberG: 2.8, carbsG: 3.7, fatG: 0.2, source: 'usda' },
  { id: "buckwheat_flour", nameEn: "Buckwheat flour, whole-groat", nameNe: "buckwheat_flour", foodGroup: "grains", kcal: 335, proteinG: 12.6, fiberG: 10, carbsG: 70.6, fatG: 3.1, source: 'usda' },
  { id: "cabbage", nameEn: "Cabbage, raw", nameNe: "cabbage", foodGroup: "vegetables", kcal: 25, proteinG: 1.3, fiberG: 2.5, carbsG: 5.8, fatG: 0.1, source: 'usda' },
  { id: "cardamom", nameEn: "Spices, cardamom", nameNe: "cardamom", foodGroup: "spices", kcal: 311, proteinG: 10.8, fiberG: 28, carbsG: 68.5, fatG: 6.7, source: 'usda' },
  { id: "carrot", nameEn: "Carrots, raw", nameNe: "carrot", foodGroup: "vegetables", kcal: 41, proteinG: 0.9, fiberG: 2.8, carbsG: 9.6, fatG: 0.2, source: 'usda' },
  { id: "chickpea", nameEn: "Chickpeas (garbanzo beans, bengal gram), mature seeds, raw", nameNe: "chickpea", foodGroup: "pulses", kcal: 378, proteinG: 20.5, fiberG: 12.2, carbsG: 63, fatG: 6, source: 'usda' },
  { id: "coriander", nameEn: "Spices, coriander seed", nameNe: "coriander", foodGroup: "spices", kcal: 298, proteinG: 12.4, fiberG: 41.9, carbsG: 55, fatG: 17.8, source: 'usda' },
  { id: "cumin", nameEn: "Spices, cumin seed", nameNe: "cumin", foodGroup: "spices", kcal: 375, proteinG: 17.8, fiberG: 10.5, carbsG: 44.2, fatG: 22.3, source: 'usda' },
  { id: "fenugreek_seeds", nameEn: "Spices, fenugreek seed", nameNe: "fenugreek_seeds", foodGroup: "spices", kcal: 1352, proteinG: 23, fiberG: 24.6, carbsG: 58.4, fatG: 6.4, source: 'usda' },
  { id: "fish", nameEn: "Fish, tilapia, raw", nameNe: "fish", foodGroup: "protein", kcal: 96, proteinG: 20.1, fiberG: 0, carbsG: 0, fatG: 1.7, source: 'usda' },
  { id: "garlic", nameEn: "Garlic, raw", nameNe: "garlic", foodGroup: "vegetables", kcal: 149, proteinG: 6.4, fiberG: 2.1, carbsG: 33.1, fatG: 0.5, source: 'usda' },
  { id: "ghee", nameEn: "Butter, Clarified butter (ghee)", nameNe: "ghee", foodGroup: "fats", kcal: 3766, proteinG: 0, fiberG: 0, carbsG: 0, fatG: 100, source: 'usda' },
  { id: "ginger", nameEn: "Ginger root, raw", nameNe: "ginger", foodGroup: "vegetables", kcal: 333, proteinG: 1.8, fiberG: 2, carbsG: 17.8, fatG: 0.8, source: 'usda' },
  { id: "goat_meat", nameEn: "Game meat, goat, raw", nameNe: "goat_meat", foodGroup: "protein", kcal: 456, proteinG: 20.6, fiberG: 0, carbsG: 0, fatG: 2.3, source: 'usda' },
  { id: "gram_flour", nameEn: "Chickpeas (garbanzo beans, bengal gram), mature seeds, raw", nameNe: "gram_flour", foodGroup: "pulses", kcal: 378, proteinG: 20.5, fiberG: 12.2, carbsG: 63, fatG: 6, source: 'usda' },
  { id: "green_chili", nameEn: "Peppers, hot chili, green, raw", nameNe: "green_chili", foodGroup: "vegetables", kcal: 167, proteinG: 2, fiberG: 1.5, carbsG: 9.5, fatG: 0.2, source: 'usda' },
  { id: "green_mustard", nameEn: "Mustard greens, raw", nameNe: "green_mustard", foodGroup: "vegetables", kcal: 114, proteinG: 2.9, fiberG: 3.2, carbsG: 4.7, fatG: 0.4, source: 'usda' },
  { id: "green_peas", nameEn: "Peas, green, raw", nameNe: "green_peas", foodGroup: "vegetables", kcal: 339, proteinG: 5.4, fiberG: 5.7, carbsG: 14.5, fatG: 0.4, source: 'usda' },
  { id: "kidney_beans", nameEn: "Beans, kidney, all types, mature seeds, raw", nameNe: "kidney_beans", foodGroup: "pulses", kcal: 1393, proteinG: 23.6, fiberG: 24.9, carbsG: 60, fatG: 0.8, source: 'usda' },
  { id: "litchi", nameEn: "Litchis, raw", nameNe: "litchi", foodGroup: "fruits", kcal: 276, proteinG: 0.8, fiberG: 1.3, carbsG: 16.5, fatG: 0.4, source: 'usda' },
  { id: "mango", nameEn: "Mangos, raw", nameNe: "mango", foodGroup: "fruits", kcal: 60, proteinG: 0.8, fiberG: 1.6, carbsG: 15, fatG: 0.4, source: 'usda' },
  { id: "noodles", nameEn: "Pasta, cooked, unenriched, without added salt", nameNe: "noodles", foodGroup: "grains", kcal: 158, proteinG: 5.8, fiberG: 1.8, carbsG: 30.9, fatG: 0.9, source: 'usda' },
  { id: "okra", nameEn: "Okra, raw", nameNe: "okra", foodGroup: "vegetables", kcal: 138, proteinG: 1.9, fiberG: 3.2, carbsG: 7.5, fatG: 0.2, source: 'usda' },
  { id: "onion", nameEn: "Onions, raw", nameNe: "onion", foodGroup: "vegetables", kcal: 40, proteinG: 1.1, fiberG: 1.7, carbsG: 9.3, fatG: 0.1, source: 'usda' },
  { id: "pomegranate", nameEn: "Pomegranates, raw", nameNe: "pomegranate", foodGroup: "fruits", kcal: 346, proteinG: 1.7, fiberG: 4, carbsG: 18.7, fatG: 1.2, source: 'usda' },
  { id: "pork_meat", nameEn: "Pork, ground, 84% lean / 16% fat, raw", nameNe: "pork_meat", foodGroup: "protein", kcal: 218, proteinG: 18, fiberG: 0, carbsG: 0.4, fatG: 16, source: 'usda' },
  { id: "prawn", nameEn: "Crustaceans, shrimp, raw", nameNe: "prawn", foodGroup: "protein", kcal: 85, proteinG: 20.1, fiberG: 0, carbsG: 0, fatG: 0.5, source: 'usda' },
  { id: "pumpkin", nameEn: "Pumpkin, raw", nameNe: "pumpkin", foodGroup: "vegetables", kcal: 109, proteinG: 1, fiberG: 0.5, carbsG: 6.5, fatG: 0.1, source: 'usda' },
  { id: "rajma", nameEn: "Beans, black, mature seeds, raw", nameNe: "rajma", foodGroup: "pulses", kcal: 341, proteinG: 21.6, fiberG: 15.5, carbsG: 62.4, fatG: 1.4, source: 'usda' },
  { id: "red_chili", nameEn: "Spices, pepper, red or cayenne", nameNe: "red_chili", foodGroup: "spices", kcal: 318, proteinG: 12, fiberG: 27.2, carbsG: 56.6, fatG: 17.3, source: 'usda' },
  { id: "sesame", nameEn: "Seeds, sesame seeds, whole, dried", nameNe: "sesame", foodGroup: "spices", kcal: 2397, proteinG: 17.7, fiberG: 11.8, carbsG: 23.5, fatG: 49.7, source: 'usda' },
  { id: "soy_beans", nameEn: "Soybeans, mature seeds, raw", nameNe: "soy_beans", foodGroup: "pulses", kcal: 446, proteinG: 36.5, fiberG: 9.3, carbsG: 30.2, fatG: 19.9, source: 'usda' },
  { id: "sunflower_oil", nameEn: "Oil, sunflower, high oleic (70% and over)", nameNe: "sunflower_oil", foodGroup: "fats", kcal: 884, proteinG: 0, fiberG: 0, carbsG: 0, fatG: 100, source: 'usda' },
  { id: "tofu", nameEn: "Tofu, raw, firm, prepared with calcium sulfate", nameNe: "tofu", foodGroup: "protein", kcal: 144, proteinG: 17.3, fiberG: 2.3, carbsG: 2.8, fatG: 8.7, source: 'usda' },
  { id: "tomato", nameEn: "Tomatoes, red, ripe, raw, year round average", nameNe: "tomato", foodGroup: "vegetables", kcal: 18, proteinG: 0.9, fiberG: 1.2, carbsG: 3.9, fatG: 0.2, source: 'usda' },
  { id: "turmeric", nameEn: "Spices, turmeric, ground", nameNe: "turmeric", foodGroup: "spices", kcal: 312, proteinG: 9.7, fiberG: 22.7, carbsG: 67.1, fatG: 3.3, source: 'usda' },
  { id: "vegetable_oil", nameEn: "Oil, corn and canola", nameNe: "vegetable_oil", foodGroup: "fats", kcal: 3699, proteinG: 0, fiberG: 0, carbsG: 0, fatG: 100, source: 'usda' },
  // END generated USDA composition
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
    rice_flour: 'rice',
    flour: 'wheat-flour',
    maida: 'wheat-flour',
    chana: 'chickpea',
    chana_dal: 'chickpea',
    masuro_dal: 'lentil',
    mung_dal: 'soy-beans',
    paneer: 'tofu',
    buff_meat: 'goat-meat',
    buff: 'goat-meat',
    khasi: 'goat-meat',
  }

  /** Canonical form of an ingredient id for lookup: folds case and the separator. */
  static normalizeIngredientId(id: string): string {
    return id.trim().toLowerCase().replaceAll('_', '-')
  }

  /** Curated rows first, then the USDA import. */
  private static get allTables(): FoodComposition[][] {
    return [COMPOSITION_TABLE, USDA_COMPOSITION_TABLE]
  }

  /**
   * Looks a row up by exact id, then by normalised id, across both tables.
   *
   * Curated rows are searched first: a hand-checked local value should win over a generic one
   * for the same food. Normalisation matters because the curated rows use kebab-case while the
   * USDA rows use the snake_case the packs already use, so an alias pointing at an imported
   * row would otherwise do nothing.
   */
  private static findById(candidate: string | undefined): FoodComposition | undefined {
    if (!candidate) return undefined
    const tables = [COMPOSITION_TABLE, USDA_COMPOSITION_TABLE]
    for (const table of tables) {
      const exact = table.find((x) => x.id === candidate)
      if (exact) return exact
    }
    // Normalising only the candidate left every alias pointing at an imported row inert,
    // because `goat-meat` never matches the `goat_meat` the USDA rows use.
    const normalized = NutritionEngine.normalizeIngredientId(candidate)
    for (const table of tables) {
      const bySeparator = table.find(
        (x) => NutritionEngine.normalizeIngredientId(x.id) === normalized,
      )
      if (bySeparator) return bySeparator
    }
    return undefined
  }

  static compositionFor(id: string): FoodComposition | undefined {
    const direct = NutritionEngine.findById(id)
    if (direct) return direct
    const alias =
      NutritionEngine.ingredientAliases[NutritionEngine.normalizeIngredientId(id)]
      ?? NutritionEngine.ingredientAliases[id]
    return NutritionEngine.findById(alias)
  }

  /** Every row available, curated first then imported. */
  static get allCompositions(): FoodComposition[] {
    return [...COMPOSITION_TABLE, ...USDA_COMPOSITION_TABLE]
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
