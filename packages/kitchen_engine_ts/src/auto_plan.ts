/**
 * Deterministic rule-based auto-plan generator (SPECIFICATION.md Section 8.2, issue #20).
 *
 * Evaluated entirely on-device: the same inputs always yield the same week, byte for byte.
 * There is no randomness, no wall-clock read and no reliance on iteration order — every
 * sort ends in an explicit `recipeId` tie-break, and the caller supplies the start date.
 *
 * Safety is a hard constraint, not a weight. Every household member's allergies and dietary
 * rules are resolved through the allergen engine's `isAllowedInAutoPlan` verdict *before*
 * any candidate is scored, so a recipe can never be scheduled by scoring its way out of a
 * conflict. The result also reports which recipes were excluded and why, so the UI can
 * explain an empty plan instead of silently returning nothing.
 *
 * `kitchen_engine_dart` mirrors this module's semantics for the Flutter client.
 */
import {
  checkRecipeSafety,
  type DietaryRule,
  type MemberAllergyProfile,
} from './allergen_engine.js'
import { getRituForBsMonth, gregorianToBikramSambat, type RituName } from './nepali_calendar.js'

export type AutoPlanGoal = 'quick' | 'budget' | 'seasonal' | 'highProtein' | 'vegetarian'

export const AUTO_PLAN_GOALS: AutoPlanGoal[] = [
  'quick',
  'budget',
  'seasonal',
  'highProtein',
  'vegetarian',
]

export type PlanAvailability =
  | 'peak'
  | 'in_season'
  | 'available'
  | 'limited'
  | 'out_of_season'

/**
 * How strongly a Ritu's availability status argues for (or against) using an ingredient.
 * Peak produce is what the issue asks us to prioritise; out-of-season produce is penalised
 * because it is the most expensive and least flavoursome to buy.
 */
const AVAILABILITY_WEIGHT: Record<PlanAvailability, number> = {
  peak: 4,
  in_season: 3,
  available: 1,
  limited: -1,
  out_of_season: -4,
}

export interface PlanIngredient {
  id: string
  nameEn: string
  nameNe: string
  marketPackageGrams: number
  storageDays: number
  availability: Record<string, PlanAvailability>
}

export interface PlanRecipeIngredient {
  ingredientId: string
  quantityGrams: number
}

export interface PlanRecipe {
  id: string
  titleEn: string
  titleNe: string
  category: string
  dietary: string[]
  prepTimeMinutes: number
  cookTimeMinutes: number
  servings: number
  /** Market cost of a single serving. */
  costEstimateNpr: number
  /** Protein grams in a single serving. */
  proteinGramsPerServing: number
  ingredients: PlanRecipeIngredient[]
  tags: string[]
}

export interface PlanPantryItem {
  ingredientId: string
  quantityGrams: number
}

export interface PlanRhythmSlot {
  id: string
  nameEn: string
  nameNe: string
  sortOrder: number
}

export interface AutoPlanTuning {
  /**
   * Days a recipe is held back after it is planned. Only reachable once the eligible pool has
   * been refilled, which is what happens when a narrow safety filter leaves fewer recipes than
   * the week has slots.
   */
  repeatGapDays: number
}

export const DEFAULT_TUNING: AutoPlanTuning = {
  repeatGapDays: 2,
}

export interface AutoPlanInput {
  /** First day of the plan, as YYYY-MM-DD. Supplied by the caller so runs are reproducible. */
  startDateIso: string
  goal: AutoPlanGoal
  recipes: PlanRecipe[]
  ingredients: PlanIngredient[]
  rhythmSlots: PlanRhythmSlot[]
  allergyProfiles: MemberAllergyProfile[]
  dietaryRules?: DietaryRule[]
  pantryItems?: PlanPantryItem[]
  /** Feeds the whole household; recipes are scaled to match. Defaults to 4. */
  householdServings?: number
  /** Days to plan. Defaults to 7. */
  days?: number
  /** Overrides the calendar-derived Ritu, for tests and offline packs without a calendar. */
  rituId?: RituName
  tuning?: Partial<AutoPlanTuning>
}

export interface AutoPlanScheduledMeal {
  dateIso: string
  dayIndex: number
  slotId: string
  slotNameEn: string
  slotNameNe: string
  recipeId: string
  titleEn: string
  titleNe: string
  category: string
  servings: number
  isSeasonal: boolean
  peakIngredientIds: string[]
  dietaryBadges: string[]
  /** Normalised 0..1 goal fit; lower is a better fit for the chosen goal. */
  score: number
  goalScore: number
  wasteScore: number
  repeatedWithinGap: boolean
}

export interface AutoPlanGroceryLine {
  ingredientId: string
  nameEn: string
  nameNe: string
  totalRequiredGrams: number
  pantryAvailableGrams: number
  netNeededGrams: number
  marketPackageGrams: number
  packagesToBuy: number
  totalPurchasedGrams: number
  surplusGrams: number
  availability: PlanAvailability
  storageDays: number
  usedByRecipeIds: string[]
}

export interface AutoPlanExclusion {
  recipeId: string
  titleEn: string
  reason: string
  blockedAllergen?: string
  blockedDietaryRule?: DietaryRule
}

export interface AutoPlanTotals {
  estimatedCostNpr: number
  proteinGrams: number
  distinctIngredients: number
  pantryCoveredGrams: number
  purchasedGrams: number
  estimatedSurplusGrams: number
}

export interface AutoPlanResult {
  goal: AutoPlanGoal
  startDateIso: string
  endDateIso: string
  days: number
  servings: number
  /** Ritu of the first day, for the plan header. Individual days may cross a Ritu boundary. */
  rituId: RituName
  meals: AutoPlanScheduledMeal[]
  grocery: AutoPlanGroceryLine[]
  totals: AutoPlanTotals
  exclusions: AutoPlanExclusion[]
  /** Slots that no eligible recipe could fill, so callers can surface a partial week. */
  unfilledSlots: Array<{ dateIso: string; dayIndex: number; slotId: string }>
}

const MS_PER_DAY = 86400000

/** Parses YYYY-MM-DD into a local-noon Date: immune to timezone and DST drift. */
function parseIsoDate(iso: string): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso)
  if (!match) {
    throw new Error(`startDateIso must be YYYY-MM-DD, received "${iso}"`)
  }
  const year = Number(match[1])
  const month = Number(match[2])
  const day = Number(match[3])
  const date = new Date(year, month - 1, day, 12, 0, 0, 0)
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    throw new Error(`startDateIso is not a real calendar date: "${iso}"`)
  }
  return date
}

function toIsoDate(date: Date): string {
  const year = date.getFullYear().toString().padStart(4, '0')
  const month = (date.getMonth() + 1).toString().padStart(2, '0')
  const day = date.getDate().toString().padStart(2, '0')
  return `${year}-${month}-${day}`
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * MS_PER_DAY)
}

function scaleToGrams(quantityGrams: number, recipeServings: number, householdServings: number): number {
  if (recipeServings <= 0) return quantityGrams
  return (quantityGrams * householdServings) / recipeServings
}

function roundGrams(value: number): number {
  return Math.round(value * 100) / 100
}

/** Min-max normalisation onto 0..1. A flat input collapses to 0 so it never skews a tie-break. */
function normalise(values: number[]): number[] {
  if (values.length === 0) return []
  let min = values[0]
  let max = values[0]
  for (const value of values) {
    if (value < min) min = value
    if (value > max) max = value
  }
  if (max === min) return values.map(() => 0)
  return values.map((value) => (value - min) / (max - min))
}

/** Lexicographic comparison of a ranking key; the id makes the order total. */
function compareKeys(a: [number, number, number, string], b: [number, number, number, string]): number {
  for (let index = 0; index < 3; index += 1) {
    if (a[index] !== b[index]) return a[index] < b[index] ? -1 : 1
  }
  if (a[3] === b[3]) return 0
  return a[3] < b[3] ? -1 : 1
}

function availabilityOf(
  ingredient: PlanIngredient | undefined,
  rituId: string
): PlanAvailability {
  const raw = ingredient?.availability?.[rituId]
  if (raw === undefined) return 'available'
  return raw
}

/** The single place a Ritu is derived, so Dart can mirror one rule. */
export function resolveRituId(date: Date): RituName {
  return getRituForBsMonth(gregorianToBikramSambat(date).month).id as RituName
}

interface SeasonSummary {
  weightedScore: number
  peakIngredientIds: string[]
  outOfSeasonIngredientIds: string[]
}

function summariseSeason(
  recipe: PlanRecipe,
  ingredientById: Map<string, PlanIngredient>,
  rituId: string
): SeasonSummary {
  const peakIngredientIds: string[] = []
  const outOfSeasonIngredientIds: string[] = []
  let weightedScore = 0

  for (const item of recipe.ingredients) {
    const ingredient = ingredientById.get(item.ingredientId)
    if (!ingredient) continue
    const availability = availabilityOf(ingredient, rituId)
    weightedScore += AVAILABILITY_WEIGHT[availability]
    if (availability === 'peak') peakIngredientIds.push(item.ingredientId)
    if (availability === 'out_of_season') outOfSeasonIngredientIds.push(item.ingredientId)
  }

  peakIngredientIds.sort()
  outOfSeasonIngredientIds.sort()
  return { weightedScore, peakIngredientIds, outOfSeasonIngredientIds }
}

/** Hard gate for the vegetarian goal, independent of any household dietary rules. */
function isPlantBased(recipe: PlanRecipe): boolean {
  return (
    recipe.dietary.includes('vegetarian') ||
    recipe.dietary.includes('vegan') ||
    recipe.dietary.includes('lacto-vegetarian') ||
    recipe.dietary.includes('jain-vegetarian')
  )
}

/**
 * Raw goal score; lower is better. Scales are normalised later so weights stay comparable
 * across goals whose units differ (minutes, rupees, signed availability).
 */
function rawGoalScore(
  goal: AutoPlanGoal,
  recipe: PlanRecipe,
  season: SeasonSummary
): number {
  switch (goal) {
    case 'quick':
      return recipe.prepTimeMinutes + recipe.cookTimeMinutes
    case 'budget':
      return recipe.costEstimateNpr
    case 'seasonal':
      return -season.weightedScore
    case 'highProtein':
      return -recipe.proteinGramsPerServing
    case 'vegetarian':
      // Affordable plant food: the vegetarian gate above guarantees plant-based, so cost is
      // the discriminator and protein density would just re-run the highProtein goal.
      return recipe.costEstimateNpr
  }
}

interface Candidate {
  recipe: PlanRecipe
  season: SeasonSummary
}

/**
 * Builds a seven-day schedule against the household's safety constraints.
 *
 * Slots are filled in a fixed order (day ascending, then slot sort order). Each slot takes the
 * best remaining candidate, ranked lexicographically by:
 *
 *   1. goal fit (normalised 0..1, lower is better)
 *   2. waste — the share of grams already in the pantry or committed earlier in the week
 *   3. rotation — a penalty for reusing a recipe inside `repeatGapDays`
 *   4. recipe id — the tie-break that makes the whole ordering total
 *
 * The goal leads deliberately. Issue #20 lists allergy safety, waste and seasonality as
 * constraints *within* a goal, so blending them into one weighted number would let waste
 * quietly outvote what the user actually asked for. Because cost, time and availability are
 * small integers, ties are common and the waste term decides most of them in practice.
 *
 * Each recipe is used at most once while the pool lasts, which is what gives a generated week
 * its variety. When a narrow safety filter leaves fewer recipes than the week has slots, the
 * pool refills and the rotation penalty starts applying.
 */
export function generateAutoPlan(input: AutoPlanInput): AutoPlanResult {
  const tuning: AutoPlanTuning = { ...DEFAULT_TUNING, ...(input.tuning ?? {}) }
  const days = input.days ?? 7
  const servings = input.householdServings ?? 4
  const dietaryRules = input.dietaryRules ?? []

  if (days <= 0) {
    throw new Error(`days must be positive, received ${days}`)
  }
  if (servings <= 0) {
    throw new Error(`householdServings must be positive, received ${servings}`)
  }

  const startDate = parseIsoDate(input.startDateIso)
  const dates: Date[] = []
  for (let offset = 0; offset < days; offset += 1) {
    dates.push(addDays(startDate, offset))
  }

  const ingredientById = new Map(input.ingredients.map((i) => [i.id, i]))
  const slots = [...input.rhythmSlots].sort((a, b) =>
    a.sortOrder === b.sortOrder ? (a.id < b.id ? -1 : a.id > b.id ? 1 : 0) : a.sortOrder - b.sortOrder
  )

  // --- Safety gate. Nothing below this point can reintroduce an excluded recipe. ---
  const exclusions: AutoPlanExclusion[] = []
  const candidates: Candidate[] = []

  for (const recipe of input.recipes) {
    const verdict = checkRecipeSafety({
      ingredientIds: recipe.ingredients.map((i) => i.ingredientId),
      allergyProfiles: input.allergyProfiles,
      dietaryRules,
    })

    if (!verdict.isAllowedInAutoPlan) {
      const first = verdict.conflicts[0]
      exclusions.push({
        recipeId: recipe.id,
        titleEn: recipe.titleEn,
        reason: first?.reason ?? 'Blocked by a household safety constraint.',
        blockedAllergen: first?.allergen,
        blockedDietaryRule: first?.dietaryRule,
      })
      continue
    }

    if (input.goal === 'vegetarian' && !isPlantBased(recipe)) {
      exclusions.push({
        recipeId: recipe.id,
        titleEn: recipe.titleEn,
        reason: 'Not plant-based, so it cannot satisfy the Vegetarian goal.',
      })
      continue
    }

    candidates.push({
      recipe,
      season: { weightedScore: 0, peakIngredientIds: [], outOfSeasonIngredientIds: [] },
    })
  }
  exclusions.sort((a, b) => (a.recipeId < b.recipeId ? -1 : a.recipeId > b.recipeId ? 1 : 0))
  const eligible = [...candidates]

  const pantryGrams = new Map<string, number>()
  for (const item of input.pantryItems ?? []) {
    const existing = pantryGrams.get(item.ingredientId) ?? 0
    pantryGrams.set(item.ingredientId, existing + item.quantityGrams)
  }

  /** Grams of each ingredient already spoken for, by the pantry or an earlier slot this week. */
  const committedGrams = new Map<string, number>(pantryGrams)
  const lastPlannedDay = new Map<string, number>()
  const meals: AutoPlanScheduledMeal[] = []
  const unfilledSlots: AutoPlanResult['unfilledSlots'] = []

  for (let dayIndex = 0; dayIndex < days; dayIndex += 1) {
    const date = dates[dayIndex]
    const dateIso = toIsoDate(date)
    const rituId = input.rituId ?? resolveRituId(date)

    for (const slot of slots) {
      // Variety first: each recipe is planned once. A narrow safety filter can leave fewer
      // recipes than slots, so refill rather than return a starved week.
      if (candidates.length === 0) {
        if (eligible.length === 0) {
          unfilledSlots.push({ dateIso, dayIndex, slotId: slot.id })
          continue
        }
        candidates.push(...eligible)
      }

      for (const candidate of candidates) {
        candidate.season = summariseSeason(candidate.recipe, ingredientById, rituId)
      }

      const goalScores = candidates.map((c) => rawGoalScore(input.goal, c.recipe, c.season))
      const normalisedGoal = normalise(goalScores)

      // Waste term: the share of this recipe's scaled grams that the household already has
      // in the pantry or has committed to earlier in the week. Higher is less waste.
      const wasteRatios = candidates.map((c) => {
        let total = 0
        let reused = 0
        for (const item of c.recipe.ingredients) {
          const grams = scaleToGrams(item.quantityGrams, c.recipe.servings, servings)
          total += grams
          const available = committedGrams.get(item.ingredientId) ?? 0
          if (available > 0) {
            reused += Math.min(grams, available)
          }
        }
        return total > 0 ? reused / total : 0
      })

      let bestIndex = 0
      let bestKey: [number, number, number, string] | null = null
      for (let index = 0; index < candidates.length; index += 1) {
        const candidate = candidates[index]
        const previousDay = lastPlannedDay.get(candidate.recipe.id)
        const repeatedWithinGap =
          previousDay !== undefined && dayIndex - previousDay <= tuning.repeatGapDays

        const key: [number, number, number, string] = [
          normalisedGoal[index],
          1 - wasteRatios[index],
          repeatedWithinGap ? 1 : 0,
          candidate.recipe.id,
        ]

        if (bestKey === null || compareKeys(key, bestKey) < 0) {
          bestIndex = index
          bestKey = key
        }
      }

      const chosen = candidates[bestIndex]
      candidates.splice(bestIndex, 1)

      // Read the previous occurrence before recording this one, otherwise the gap is always 0.
      const previousDay = lastPlannedDay.get(chosen.recipe.id)
      const repeatedWithinGap =
        previousDay !== undefined && dayIndex - previousDay <= tuning.repeatGapDays
      lastPlannedDay.set(chosen.recipe.id, dayIndex)

      const scaledIngredients = chosen.recipe.ingredients.map((item) => ({
        ingredientId: item.ingredientId,
        grams: scaleToGrams(item.quantityGrams, chosen.recipe.servings, servings),
      }))
      for (const item of scaledIngredients) {
        committedGrams.set(
          item.ingredientId,
          (committedGrams.get(item.ingredientId) ?? 0) + item.grams
        )
      }

      meals.push({
        dateIso,
        dayIndex,
        slotId: slot.id,
        slotNameEn: slot.nameEn,
        slotNameNe: slot.nameNe,
        recipeId: chosen.recipe.id,
        titleEn: chosen.recipe.titleEn,
        titleNe: chosen.recipe.titleNe,
        category: chosen.recipe.category,
        servings,
        isSeasonal: chosen.season.peakIngredientIds.length > 0,
        peakIngredientIds: chosen.season.peakIngredientIds,
        dietaryBadges: [...chosen.recipe.dietary].sort(),
        score: roundGrams(normalisedGoal[bestIndex]),
        goalScore: roundGrams(goalScores[bestIndex]),
        wasteScore: roundGrams(wasteRatios[bestIndex]),
        repeatedWithinGap,
      })
    }
  }

  // Render in the household's rhythm order, not alphabetical slot id, so a day reads
  // morning-first even when the slot ids sort differently.
  const slotOrder = new Map(slots.map((slot, index) => [slot.id, index]))
  meals.sort(
    (a, b) =>
      a.dayIndex - b.dayIndex ||
      (slotOrder.get(a.slotId) ?? 0) - (slotOrder.get(b.slotId) ?? 0) ||
      (a.slotId < b.slotId ? -1 : a.slotId > b.slotId ? 1 : 0)
  )

  // --- Combined grocery requirement across the whole week. ---
  const required = new Map<string, number>()
  const usedBy = new Map<string, Set<string>>()
  for (const meal of meals) {
    const recipe = input.recipes.find((r) => r.id === meal.recipeId)
    if (!recipe) continue
    for (const item of recipe.ingredients) {
      const grams = scaleToGrams(item.quantityGrams, recipe.servings, servings)
      required.set(item.ingredientId, (required.get(item.ingredientId) ?? 0) + grams)
      const ids = usedBy.get(item.ingredientId) ?? new Set<string>()
      ids.add(recipe.id)
      usedBy.set(item.ingredientId, ids)
    }
  }

  const firstRituId = input.rituId ?? resolveRituId(dates[0])
  const grocery: AutoPlanGroceryLine[] = []

  for (const ingredientId of [...required.keys()].sort()) {
    const ingredient = ingredientById.get(ingredientId)
    const totalRequiredGrams = roundGrams(required.get(ingredientId) ?? 0)
    const pantryAvailableGrams = roundGrams(pantryGrams.get(ingredientId) ?? 0)
    const netNeededGrams = roundGrams(Math.max(0, totalRequiredGrams - pantryAvailableGrams))

    // An ingredient the pack does not describe still belongs on the list; fall back to a
    // 250 g market package so the shopper is told to buy something rather than nothing.
    const marketPackageGrams =
      ingredient && ingredient.marketPackageGrams > 0 ? ingredient.marketPackageGrams : 250
    const packagesToBuy =
      netNeededGrams > 0 ? Math.ceil(netNeededGrams / marketPackageGrams) : 0
    const totalPurchasedGrams = packagesToBuy * marketPackageGrams

    grocery.push({
      ingredientId,
      nameEn: ingredient?.nameEn ?? ingredientId,
      nameNe: ingredient?.nameNe ?? ingredientId,
      totalRequiredGrams,
      pantryAvailableGrams,
      netNeededGrams,
      marketPackageGrams,
      packagesToBuy,
      totalPurchasedGrams,
      surplusGrams: roundGrams(
        Math.max(0, pantryAvailableGrams + totalPurchasedGrams - totalRequiredGrams)
      ),
      availability: availabilityOf(ingredient, firstRituId),
      storageDays: ingredient?.storageDays ?? 0,
      usedByRecipeIds: [...(usedBy.get(ingredientId) ?? new Set<string>())].sort(),
    })
  }

  let estimatedCostNpr = 0
  let proteinGrams = 0
  for (const meal of meals) {
    const recipe = input.recipes.find((r) => r.id === meal.recipeId)
    if (!recipe) continue
    estimatedCostNpr += recipe.costEstimateNpr * servings
    proteinGrams += recipe.proteinGramsPerServing * servings
  }

  return {
    goal: input.goal,
    startDateIso: toIsoDate(dates[0]),
    endDateIso: toIsoDate(dates[days - 1]),
    days,
    servings,
    rituId: firstRituId,
    meals,
    grocery,
    totals: {
      estimatedCostNpr: Math.round(estimatedCostNpr),
      proteinGrams: roundGrams(proteinGrams),
      distinctIngredients: grocery.length,
      pantryCoveredGrams: roundGrams(
        grocery.reduce((sum, line) => sum + Math.min(line.pantryAvailableGrams, line.totalRequiredGrams), 0)
      ),
      purchasedGrams: roundGrams(grocery.reduce((sum, line) => sum + line.totalPurchasedGrams, 0)),
      estimatedSurplusGrams: roundGrams(grocery.reduce((sum, line) => sum + line.surplusGrams, 0)),
    },
    exclusions,
    unfilledSlots,
  }
}
