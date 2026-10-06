/**
 * Siti Counter 3.0 - Dish roles and time-of-day suitability (Section 23.4)
 *
 * A pack describes the same dish more than once: dal bhat is a breakfast main course and a
 * dinner main course, and achar is a side dish that never stands alone. Without an explicit
 * role the app has no way to tell those apart, so it happily recommends a pickle as if it
 * were a meal.
 *
 * Roles are declared per recipe rather than inferred from category, because category
 * (`tarkari`, `dal`, `masu`) describes the dish, not how it is eaten.
 *
 * Mirror of `packages/kitchen_engine_dart/lib/meal_role_engine.dart`; keep the two in step.
 */

import type { RegionRecipe } from './region_pack_manager.js'

/** How a dish is served. A dish can be more than one of these. */
export type DishRole = 'mainCourse' | 'sideDish' | 'both'

/** Meal times a dish is suitable for. */
export type MealTime = 'morning' | 'midday' | 'evening' | 'night'

const ALL_MEAL_TIMES: readonly MealTime[] = [
  'morning',
  'midday',
  'evening',
  'night',
]

function parseRole(value: string): DishRole | null {
  switch (value) {
    case 'mainCourse':
    case 'main_course':
    case 'main':
      return 'mainCourse'
    case 'sideDish':
    case 'side_dish':
    case 'side':
      return 'sideDish'
    case 'both':
      return 'both'
    default:
      return null
  }
}

function parseMealTime(value: string): MealTime | null {
  switch (value) {
    case 'morning':
    case 'breakfast':
      return 'morning'
    case 'midday':
    case 'lunch':
      return 'midday'
    case 'evening':
    case 'snack':
      return 'evening'
    case 'night':
    case 'dinner':
      return 'night'
    default:
      return null
  }
}

export class DishRoleResolver {
  /**
   * Parses declared dish roles, defaulting to main-course-only.
   *
   * A recipe with no declared roles is treated as a main course: the safe default is to keep
   * offering the dish rather than silently hiding food from the household.
   */
  static rolesOf(recipe: RegionRecipe): Set<DishRole> {
    const declared = recipe.dishRoles ?? []
    if (declared.length === 0) return new Set<DishRole>(['mainCourse'])

    const roles = new Set<DishRole>()
    for (const value of declared) {
      const role = parseRole(value)
      if (role) roles.add(role)
    }

    if (roles.size === 0) return new Set<DishRole>(['mainCourse'])
    if (roles.has('both')) return new Set<DishRole>(['mainCourse', 'sideDish'])
    return roles
  }

  /** Whether the dish can stand as a meal in its own right. */
  static isMainCourse(recipe: RegionRecipe): boolean {
    return DishRoleResolver.rolesOf(recipe).has('mainCourse')
  }

  /** Whether the dish is meant to accompany something else. */
  static isSideDish(recipe: RegionRecipe): boolean {
    return DishRoleResolver.rolesOf(recipe).has('sideDish')
  }

  /** Whether the dish is only ever an accompaniment. */
  static isSideDishOnly(recipe: RegionRecipe): boolean {
    return !DishRoleResolver.isMainCourse(recipe) && DishRoleResolver.isSideDish(recipe)
  }

  /**
   * Meal times the dish suits, defaulting to every time when nothing is declared.
   *
   * An empty declaration must not mean "never", or an unclassified pack would produce an
   * empty plan.
   */
  static mealTimesOf(recipe: RegionRecipe): Set<MealTime> {
    const declared = recipe.mealTimes ?? []
    if (declared.length === 0) return new Set<MealTime>(ALL_MEAL_TIMES)

    const times = new Set<MealTime>()
    for (const value of declared) {
      const time = parseMealTime(value)
      if (time) times.add(time)
    }

    return times.size === 0 ? new Set<MealTime>(ALL_MEAL_TIMES) : times
  }

  static suitsMealTime(recipe: RegionRecipe, time: MealTime): boolean {
    return DishRoleResolver.mealTimesOf(recipe).has(time)
  }

  /**
   * Recipes that may be recommended as a meal.
   *
   * This is the rule that keeps a side dish out of a meal slot: only a main course (or a
   * dish that is both) qualifies.
   */
  static mainsOnly(recipes: RegionRecipe[]): RegionRecipe[] {
    return recipes.filter((recipe) => DishRoleResolver.isMainCourse(recipe))
  }

  /**
   * Maps a planner meal-slot id onto the meal times a dish may be served at.
   *
   * Morning and evening are merged on purpose: dal bhat is the canonical Nepali breakfast
   * and also a dinner, so the same main course legitimately appears at both ends of the day.
   * A side dish maps to nothing, so it can never be slotted into a meal.
   */
  static timesForSlot(slotId: string): Set<MealTime> {
    switch (slotId) {
      case 'breakfast':
      case 'morning-dal-bhat':
      case 'morning':
        return new Set<MealTime>(['morning', 'evening'])
      case 'lunch':
      case 'midday':
        return new Set<MealTime>(['midday'])
      case 'evening-snack':
      case 'evening':
        return new Set<MealTime>(['evening'])
      case 'dinner':
      case 'night':
        return new Set<MealTime>(['night'])
      default:
        // An unrecognised slot does not silently exclude every dish.
        return new Set<MealTime>(ALL_MEAL_TIMES)
    }
  }

  /** Whether [recipe] may be planned into [slotId]. */
  static canBePlannedIn(recipe: RegionRecipe, slotId: string): boolean {
    if (!DishRoleResolver.isMainCourse(recipe)) return false
    const times = DishRoleResolver.timesForSlot(slotId)
    return [...times].some((time) => DishRoleResolver.suitsMealTime(recipe, time))
  }
}

/** A main course paired with side dishes to serve alongside it. */
export interface MealSuggestion {
  mainCourse: RegionRecipe
  sideDishes: RegionRecipe[]
  reasonEn: string
  reasonNe: string
}

export interface SuggestMealsInput {
  recipes: RegionRecipe[]
  slotId: string
  seasonalityRituIds?: ReadonlySet<string>
  excludedIngredientIds?: ReadonlySet<string>
  limit?: number
}

export class MealSuggestionEngine {
  /**
   * Suggests up to `limit` meals suitable for `slotId`.
   *
   * Rules, in order of importance:
   *  1. A side dish is never the meal. Only main courses are returned as `mainCourse`.
   *  2. Side dishes are attached to a main, never offered on their own.
   *  3. A main course must suit the time of the slot being filled.
   *
   * `excludedIngredientIds` is applied before role and time filtering, so an allergen never
   * appears even as an accompaniment.
   */
  static suggest(input: SuggestMealsInput): MealSuggestion[] {
    const limit = input.limit ?? 5
    if (limit <= 0) return []

    const seasonality = input.seasonalityRituIds ?? new Set<string>()
    const excluded = input.excludedIngredientIds ?? new Set<string>()

    const eligibleMains = input.recipes.filter((recipe) => {
      if (!DishRoleResolver.canBePlannedIn(recipe, input.slotId)) return false
      if (
        seasonality.size > 0 &&
        !recipe.seasonality.some((ritu) => seasonality.has(ritu))
      ) {
        return false
      }
      return !MealSuggestionEngine.usesExcludedIngredient(recipe, excluded)
    })

    const sideDishes = input.recipes.filter((recipe) => {
      if (!DishRoleResolver.isSideDish(recipe)) return false
      if (
        seasonality.size > 0 &&
        !recipe.seasonality.some((ritu) => seasonality.has(ritu))
      ) {
        return false
      }
      return !MealSuggestionEngine.usesExcludedIngredient(recipe, excluded)
    })

    return eligibleMains.slice(0, limit).map((main) => {
      const pairings = MealSuggestionEngine.pairingsFor(main, sideDishes)
      return {
        mainCourse: main,
        sideDishes: pairings,
        reasonEn: MealSuggestionEngine.reasonEn(main, input.slotId, pairings),
        reasonNe: MealSuggestionEngine.reasonNe(pairings),
      }
    })
  }

  /**
   * Side dishes that go with this main course.
   *
   * Matching is on shared seasoning and staple ingredients rather than cuisine alone: achar
   * goes with dal bhat because both are tempered in mustard oil and jimbu, which is the
   * actual reason they are served together.
   */
  static pairingsFor(
    main: RegionRecipe,
    sideDishes: RegionRecipe[],
  ): RegionRecipe[] {
    const mainIngredients = new Set(
      main.ingredients.map((i) => i.ingredientId.toLowerCase()),
    )

    const scored: Array<{ side: RegionRecipe; score: number }> = []
    for (const side of sideDishes) {
      if (side.id === main.id) continue

      let score = 0
      for (const ingredient of side.ingredients) {
        if (mainIngredients.has(ingredient.ingredientId.toLowerCase())) score++
      }
      // Same category means a tarkari paired with another tarkari, which is not a pairing.
      // A penalty of 1 rather than more, so a genuinely strong shared-ingredient match still
      // survives: achar and dal bhat are both "dal"-adjacent but really go together.
      if (side.category === main.category) score -= 1

      if (score > 0) scored.push({ side, score })
    }

    scored.sort((a, b) => b.score - a.score)
    return scored.slice(0, 2).map((entry) => entry.side)
  }

  private static usesExcludedIngredient(
    recipe: RegionRecipe,
    excluded: ReadonlySet<string>,
  ): boolean {
    if (excluded.size === 0) return false
    return recipe.ingredients.some((i) => excluded.has(i.ingredientId))
  }

  private static reasonEn(
    main: RegionRecipe,
    slotId: string,
    sides: RegionRecipe[],
  ): string {
    let time = 'this time of day'
    switch (slotId) {
      case 'breakfast':
      case 'morning-dal-bhat':
      case 'morning':
        time = 'a morning main course'
        break
      case 'lunch':
      case 'midday':
        time = 'a midday main course'
        break
      case 'dinner':
      case 'night':
        time = 'an evening main course'
        break
      default:
        break
    }
    if (sides.length === 0) return `Fits ${time}.`
    return `Fits ${time}, with ${sides[0]!.titleEn} alongside.`
  }

  private static reasonNe(sides: RegionRecipe[]): string {
    if (sides.length === 0) return 'यो समयका लागि उपयुक्त मुख्य परिकार।'
    return `${sides[0]!.titleNe} सँगै खान मिल्ने मुख्य परिकार।`
  }
}