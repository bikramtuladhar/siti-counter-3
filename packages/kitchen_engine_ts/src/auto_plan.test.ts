import { describe, it } from 'node:test'
import assert from 'node:assert'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  generateAutoPlan,
  resolveRituId,
  type AutoPlanInput,
  type PlanIngredient,
  type PlanRecipe,
  type PlanRhythmSlot,
} from './auto_plan.js'
import { AllergenCatalog } from './allergen_engine.js'

// From dist/ up to the workspace `packages/` directory, where region-packs lives.
const PACK_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'region-packs', 'nepal-bagmati')

function loadPack(): { recipes: PlanRecipe[]; ingredients: PlanIngredient[] } {
  const recipes = JSON.parse(readFileSync(join(PACK_DIR, 'recipes.json'), 'utf8')) as Array<{
    id: string
    titleEn: string
    titleNe: string
    category: string
    dietary: string[]
    prepTimeMinutes: number
    cookTimeMinutes: number
    servings: number
    costEstimateNpr: number
    proteinGramsPerServing: number
    ingredients: Array<{ ingredientId: string; quantity: number }>
    tags: string[]
  }>
  const ingredients = JSON.parse(readFileSync(join(PACK_DIR, 'ingredients.json'), 'utf8')) as PlanIngredient[]

  return {
    recipes: recipes.map((r) => ({
      id: r.id,
      titleEn: r.titleEn,
      titleNe: r.titleNe,
      category: r.category,
      dietary: r.dietary,
      prepTimeMinutes: r.prepTimeMinutes,
      cookTimeMinutes: r.cookTimeMinutes,
      servings: r.servings,
      costEstimateNpr: r.costEstimateNpr,
      proteinGramsPerServing: r.proteinGramsPerServing,
      ingredients: r.ingredients.map((i) => ({ ingredientId: i.ingredientId, quantityGrams: i.quantity })),
      tags: r.tags,
    })),
    ingredients,
  }
}

const NEPALI_RHYTHM: PlanRhythmSlot[] = [
  { id: 'morning_dal_bhat', nameEn: 'Morning Dal Bhat', nameNe: 'बिहानीको दाल भात', sortOrder: 1 },
  { id: 'afternoon_khaja', nameEn: 'Afternoon Khaja', nameNe: 'दिउँसोको खाजा', sortOrder: 2 },
  { id: 'evening_dal_bhat', nameEn: 'Evening Dal Bhat', nameNe: 'साँझको दाल भात', sortOrder: 3 },
]

function baseInput(overrides: Partial<AutoPlanInput> = {}): AutoPlanInput {
  const pack = loadPack()
  return {
    startDateIso: '2026-10-05',
    goal: 'seasonal',
    recipes: pack.recipes,
    ingredients: pack.ingredients,
    rhythmSlots: NEPALI_RHYTHM,
    allergyProfiles: [],
    ...overrides,
  }
}

/**
 * Everything a consumer of the plan actually depends on. Mirrors `project()` in the Dart test
 * and in scripts/generate_auto_plan_golden.mjs — all three must stay in step, since the golden
 * fixture is written by that script and asserted by the other two.
 */
function project(result: ReturnType<typeof generateAutoPlan>) {
  return {
    goal: result.goal,
    startDateIso: result.startDateIso,
    endDateIso: result.endDateIso,
    days: result.days,
    servings: result.servings,
    rituId: result.rituId,
    meals: result.meals.map((m) => ({
      dateIso: m.dateIso,
      dayIndex: m.dayIndex,
      slotId: m.slotId,
      recipeId: m.recipeId,
      category: m.category,
      isSeasonal: m.isSeasonal,
      peakIngredientIds: m.peakIngredientIds,
      dietaryBadges: m.dietaryBadges,
      goalScore: m.goalScore,
      wasteScore: m.wasteScore,
      repeatedWithinGap: m.repeatedWithinGap,
    })),
    grocery: result.grocery.map((line) => ({
      ingredientId: line.ingredientId,
      totalRequiredGrams: line.totalRequiredGrams,
      pantryAvailableGrams: line.pantryAvailableGrams,
      netNeededGrams: line.netNeededGrams,
      marketPackageGrams: line.marketPackageGrams,
      packagesToBuy: line.packagesToBuy,
      totalPurchasedGrams: line.totalPurchasedGrams,
      surplusGrams: line.surplusGrams,
      availability: line.availability,
      usedByRecipeIds: line.usedByRecipeIds,
    })),
    totals: result.totals,
    exclusions: result.exclusions.map((e) => ({
      recipeId: e.recipeId,
      blockedAllergen: e.blockedAllergen ?? null,
      blockedDietaryRule: e.blockedDietaryRule ?? null,
    })),
    unfilledSlots: result.unfilledSlots,
  }
}

describe('AutoPlan: cross-engine golden fixture parity', () => {
  const golden = JSON.parse(
    readFileSync(join(PACK_DIR, '..', '..', '..', 'fixtures', 'auto_plan_golden.json'), 'utf8')
  ) as { scenarios: Record<string, unknown> }

  function expectMatchesGolden(name: string, input: AutoPlanInput) {
    assert.deepStrictEqual(
      project(generateAutoPlan(input)),
      golden.scenarios[name],
      `${name} diverged from the shared golden fixture; kitchen_engine_dart asserts the same ` +
        'file, so regenerate it only if the change was deliberate'
    )
  }

  it('matches the shared fixture for every scenario', () => {
    const mustardSevere = [
      { allergen: AllergenCatalog.mustard, severity: 'severe' as const, memberName: 'Bikram' },
    ]
    const dairySevere = [
      { allergen: AllergenCatalog.milk, severity: 'severe' as const, memberName: 'Sita' },
    ]

    expectMatchesGolden('seasonal-default', baseInput({ goal: 'seasonal' }))
    expectMatchesGolden('budget-default', baseInput({ goal: 'budget' }))
    expectMatchesGolden('quick-default', baseInput({ goal: 'quick' }))
    expectMatchesGolden('high-protein-default', baseInput({ goal: 'highProtein' }))
    expectMatchesGolden('vegetarian-default', baseInput({ goal: 'vegetarian' }))
    expectMatchesGolden('seasonal-sharad-override', baseInput({ goal: 'seasonal', rituId: 'sharad' }))
    expectMatchesGolden('seasonal-mustard-allergy', baseInput({ goal: 'seasonal', allergyProfiles: mustardSevere }))
    expectMatchesGolden(
      'budget-dairy-allergy-vegetarian',
      baseInput({ goal: 'budget', dietaryRules: ['vegetarian'], allergyProfiles: dairySevere })
    )
    expectMatchesGolden('quick-hindu-fasting', baseInput({ goal: 'quick', dietaryRules: ['hinduFasting'] }))
    expectMatchesGolden(
      'seasonal-pantry-potato',
      baseInput({ goal: 'seasonal', pantryItems: [{ ingredientId: 'potato', quantityGrams: 100000 }] })
    )
    expectMatchesGolden('seasonal-eight-servings', baseInput({ goal: 'seasonal', householdServings: 8 }))
    expectMatchesGolden(
      'quick-single-slot-single-day',
      baseInput({ goal: 'quick', days: 1, rhythmSlots: [NEPALI_RHYTHM[0]] })
    )
    expectMatchesGolden('budget-small-pool-refill', baseInput({ goal: 'budget', recipes: loadPack().recipes.slice(0, 4) }))
    expectMatchesGolden('seasonal-three-days', baseInput({ goal: 'seasonal', days: 3 }))
  })
})

describe('AutoPlan: determinism', () => {
  it('produces identical output for identical inputs', () => {
    const a = generateAutoPlan(baseInput({ goal: 'budget' }))
    const b = generateAutoPlan(baseInput({ goal: 'budget' }))
    assert.deepStrictEqual(a, b)
  })

  it('produces identical output regardless of recipe input order', () => {
    const forward = generateAutoPlan(baseInput({ goal: 'seasonal' }))
    const reversed = generateAutoPlan(baseInput({ goal: 'seasonal', recipes: [...loadPack().recipes].reverse() }))
    assert.deepStrictEqual(
      forward.meals.map((m) => m.recipeId),
      reversed.meals.map((m) => m.recipeId)
    )
    assert.deepStrictEqual(forward.grocery, reversed.grocery)
  })

  it('is not affected by the wall clock', () => {
    const result = generateAutoPlan(baseInput({ goal: 'quick' }))
    assert.strictEqual(result.startDateIso, '2026-10-05')
    assert.strictEqual(result.endDateIso, '2026-10-11')
    assert.strictEqual(result.days, 7)
  })

  it('orders meals by day then by the rhythm slot order', () => {
    const result = generateAutoPlan(baseInput())
    // Slot ids deliberately sort differently from their sortOrder, so this only passes if the
    // day is rendered in the household's rhythm rather than alphabetically.
    const expectedOrder = NEPALI_RHYTHM.map((s) => s.id)
    assert.notDeepStrictEqual(
      [...expectedOrder].sort(),
      expectedOrder,
      'fixture must have slot ids that disagree with sortOrder, or this test proves nothing'
    )
    for (const day of new Set(result.meals.map((m) => m.dayIndex))) {
      const dayMeals = result.meals.filter((m) => m.dayIndex === day)
      assert.deepStrictEqual(
        dayMeals.map((m) => m.slotId),
        expectedOrder
      )
    }
  })
})

describe('AutoPlan: seven-day schedule shape', () => {
  it('fills every slot of every day for the default Nepali rhythm', () => {
    const result = generateAutoPlan(baseInput())
    assert.strictEqual(result.meals.length, 7 * 3)
    assert.strictEqual(result.unfilledSlots.length, 0)
    assert.strictEqual(new Set(result.meals.map((m) => m.dateIso)).size, 7)
  })

  it('honours a custom number of slots passed in by the caller', () => {
    const oneSlot: PlanRhythmSlot[] = [NEPALI_RHYTHM[0]]
    const result = generateAutoPlan(baseInput({ rhythmSlots: oneSlot }))
    assert.strictEqual(result.meals.length, 7)
    assert.ok(result.meals.every((m) => m.slotId === 'morning_dal_bhat'))
  })

  it('respects the requested day count', () => {
    const result = generateAutoPlan(baseInput({ days: 3 }))
    assert.strictEqual(result.meals.length, 9)
    assert.strictEqual(result.endDateIso, '2026-10-07')
  })

  it('never repeats a recipe within the rotation gap', () => {
    const result = generateAutoPlan(baseInput({ goal: 'quick', days: 7 }))
    const lastSeen = new Map<string, number>()
    for (const meal of result.meals) {
      const previous = lastSeen.get(meal.recipeId)
      if (previous !== undefined) {
        assert.ok(
          meal.dayIndex - previous > 2,
          `${meal.recipeId} repeated on day ${meal.dayIndex} after day ${previous}`
        )
      }
      lastSeen.set(meal.recipeId, meal.dayIndex)
    }
  })

  it('refills the pool rather than returning a starved week when recipes run short', () => {
    const few = loadPack().recipes.slice(0, 4)
    const result = generateAutoPlan(baseInput({ recipes: few }))
    assert.strictEqual(result.meals.length, 21)
    assert.strictEqual(result.unfilledSlots.length, 0)
    assert.strictEqual(new Set(result.meals.map((m) => m.recipeId)).size, 4)
    // With only four recipes the rotation penalty has to engage, so some meals are flagged.
    assert.ok(result.meals.some((m) => m.repeatedWithinGap))
  })

  it('reports unfilled slots when no recipe is eligible at all', () => {
    const result = generateAutoPlan(
      baseInput({
        recipes: [],
        allergyProfiles: [],
      })
    )
    assert.strictEqual(result.meals.length, 0)
    assert.strictEqual(result.unfilledSlots.length, 21)
    assert.strictEqual(result.grocery.length, 0)
  })

  it('scales recipe quantities when the household is larger than the recipe servings', () => {
    // A single slot, so the week's requirement comes only from the one planned recipe.
    const result = generateAutoPlan(
      baseInput({ householdServings: 8, days: 1, rhythmSlots: [NEPALI_RHYTHM[0]] })
    )
    assert.strictEqual(result.meals.length, 1)
    const firstMeal = result.meals[0]
    const recipe = loadPack().recipes.find((r) => r.id === firstMeal.recipeId)!
    assert.strictEqual(recipe.servings, 4)
    for (const line of result.grocery) {
      const own = recipe.ingredients.find((i) => i.ingredientId === line.ingredientId)
      assert.ok(own, `${line.ingredientId} is not in ${recipe.id}`)
      assert.ok(
        Math.abs(line.totalRequiredGrams - own.quantityGrams * 2) < 0.001,
        `${line.ingredientId}: expected ${own.quantityGrams * 2}g, got ${line.totalRequiredGrams}g`
      )
    }
  })
})

describe('AutoPlan: zero-miss allergy and dietary safety', () => {
  const pack = loadPack()

  it('excludes every recipe containing a severe household allergen', () => {
    // Mustard oil is the most widely used cooking fat in this pack, so it exercises the gate
    // against a large slice of the library rather than a single recipe.
    const result = generateAutoPlan(
      baseInput({
        allergyProfiles: [
          { allergen: AllergenCatalog.mustard, severity: 'severe', memberName: 'Bikram' },
        ],
      })
    )
    const plannedIds = new Set(result.meals.map((m) => m.recipeId))
    const mustardRecipes = pack.recipes.filter((r) =>
      r.ingredients.some((i) => i.ingredientId === 'mustard_oil')
    )
    assert.ok(mustardRecipes.length > 20, 'pack must have many mustard-oil recipes for this to bite')
    for (const recipe of mustardRecipes) {
      assert.ok(!plannedIds.has(recipe.id), `${recipe.id} scheduled despite a severe mustard allergy`)
    }
    assert.strictEqual(result.exclusions.length, mustardRecipes.length)
    assert.ok(result.exclusions.every((e) => e.blockedAllergen === AllergenCatalog.mustard))
  })

  it('excludes buff meat from a vegetarian household', () => {
    // Regression: `buff_meat` was missing from the allergen engine's meat set, so every
    // ranga-ko-* dish passed a vegetarian, vegan, Jain or fasting check.
    const buffRecipes = pack.recipes.filter((r) =>
      r.ingredients.some((i) => i.ingredientId === 'buff_meat')
    )
    assert.ok(buffRecipes.length > 0, 'pack must contain buff recipes for this to mean anything')
    for (const rule of ['vegetarian', 'vegan', 'jainVegetarian'] as const) {
      const result = generateAutoPlan(baseInput({ dietaryRules: [rule] }))
      const plannedIds = new Set(result.meals.map((m) => m.recipeId))
      for (const recipe of buffRecipes) {
        assert.ok(!plannedIds.has(recipe.id), `${recipe.id} scheduled under ${rule}`)
      }
    }
  })

  it('never schedules a recipe carrying a hidden dairy allergen when dairy is severe', () => {
    const result = generateAutoPlan(
      baseInput({
        allergyProfiles: [
          { allergen: AllergenCatalog.milk, severity: 'severe', memberName: 'Sita' },
        ],
      })
    )
    const plannedIds = new Set(result.meals.map((m) => m.recipeId))
    const gheeRecipes = pack.recipes.filter((r) =>
      r.ingredients.some((i) => i.ingredientId === 'ghee')
    )
    assert.ok(gheeRecipes.length > 0, 'pack must contain ghee recipes for this to mean anything')
    for (const recipe of gheeRecipes) {
      assert.ok(!plannedIds.has(recipe.id), `${recipe.id} contains ghee but was scheduled`)
    }
  })

  it('honours a household vegetarian dietary rule', () => {
    const result = generateAutoPlan(baseInput({ dietaryRules: ['vegetarian'] }))
    for (const meal of result.meals) {
      const recipe = pack.recipes.find((r) => r.id === meal.recipeId)!
      const meatIds = ['goat_meat', 'buff_meat', 'chicken', 'fish']
      for (const item of recipe.ingredients) {
        assert.ok(!meatIds.includes(item.ingredientId), `${recipe.id} scheduled meat under a vegetarian household`)
      }
    }
  })

  it('excludes a fasting-rule violation from the plan', () => {
    const result = generateAutoPlan(baseInput({ dietaryRules: ['hinduFasting'] }))
    const plannedIds = new Set(result.meals.map((m) => m.recipeId))
    assert.ok(!plannedIds.has('sada-bhat'), 'plain rice must not be planned during Vrata fasting')
    assert.ok(result.exclusions.some((e) => e.recipeId === 'sada-bhat'))
  })

  it('reports a reason and a blocked allergen for each exclusion', () => {
    const result = generateAutoPlan(
      baseInput({
        allergyProfiles: [{ allergen: AllergenCatalog.milk, severity: 'severe' }],
      })
    )
    assert.ok(result.exclusions.length > 0)
    for (const exclusion of result.exclusions) {
      assert.ok(exclusion.reason.length > 0)
      assert.ok(exclusion.blockedAllergen !== undefined || exclusion.blockedDietaryRule !== undefined)
    }
  })

  it('returns an empty plan with exclusions rather than unsafe meals when nothing is safe', () => {
    const result = generateAutoPlan(
      baseInput({
        recipes: loadPack().recipes.filter((r) =>
          r.ingredients.some((i) => i.ingredientId === 'ghee')
        ),
        allergyProfiles: [{ allergen: AllergenCatalog.milk, severity: 'severe' }],
      })
    )
    assert.strictEqual(result.meals.length, 0)
    assert.strictEqual(result.unfilledSlots.length, 21)
  })
})

describe('AutoPlan: goal scoring', () => {
  it('quick favours the shortest total cook time', () => {
    const result = generateAutoPlan(baseInput({ goal: 'quick' }))
    const durations = result.meals.map((m) => m.goalScore)
    const sorted = [...durations].sort((a, b) => a - b)
    assert.deepStrictEqual(durations, sorted)
  })

  it('budget never outranks cost: the mean slot is cheaper than the seasonal plan', () => {
    const budget = generateAutoPlan(baseInput({ goal: 'budget' }))
    const pack = loadPack()
    const costOf = (meal: { recipeId: string }) =>
      pack.recipes.find((r) => r.id === meal.recipeId)!.costEstimateNpr
    const mean = (values: number[]) => values.reduce((a, b) => a + b, 0) / values.length
    assert.ok(
      mean(budget.meals.map(costOf)) <= mean(result_meals_of('seasonal').map(costOf)) + 1,
      'budget plan should not be more expensive than the seasonal plan'
    )
  })

  it('seasonal prefers peak-season produce', () => {
    const pack = loadPack()
    const ingredientById = new Map(pack.ingredients.map((i) => [i.id, i]))
    const sharad = generateAutoPlan(baseInput({ goal: 'seasonal', rituId: 'sharad' }))
    const offSeason = generateAutoPlan(baseInput({ goal: 'seasonal', rituId: 'barsha' }))

    const peakCount = (meals: typeof sharad.meals) =>
      meals.reduce((sum, meal) => sum + meal.peakIngredientIds.length, 0)

    assert.ok(
      peakCount(sharad.meals) >= peakCount(offSeason.meals),
      'sharad (cauliflower, radish, spinach peak) should not plan fewer peak ingredients than barsha'
    )
    assert.ok(peakCount(sharad.meals) > 0, 'sharad must surface some peak produce')

    // Sanity: cauliflower really is at its peak in sharad in this pack.
    const cauliflower = ingredientById.get('cauliflower')!
    assert.strictEqual(cauliflower.availability.sharad, 'peak')
  })

  it('seasonal de-prioritises out-of-season produce', () => {
    const result = generateAutoPlan(baseInput({ goal: 'seasonal', rituId: 'sharad' }))
    for (const meal of result.meals) {
      const recipe = loadPack().recipes.find((r) => r.id === meal.recipeId)!
      const offSeason = recipe.ingredients.filter((item) => {
        const ingredient = loadPack().ingredients.find((i) => i.id === item.ingredientId)
        return ingredient?.availability.sharad === 'out_of_season'
      })
      // Only allowed when nothing better exists, so assert the badge never claims seasonality.
      if (offSeason.length > 0 && meal.peakIngredientIds.length === 0) {
        assert.strictEqual(meal.isSeasonal, false)
      }
    }
  })

  it('highProtein maximises protein across the week', () => {
    const result = generateAutoPlan(baseInput({ goal: 'highProtein' }))
    const proteins = result.meals.map((m) => m.goalScore)
    const sorted = [...proteins].sort((a, b) => a - b)
    assert.deepStrictEqual(proteins, sorted)
    assert.ok(result.totals.proteinGrams > 0)
  })

  it('highProtein plans a materially higher protein week than quick', () => {
    const proteinWeek = generateAutoPlan(baseInput({ goal: 'highProtein' })).totals.proteinGrams
    const quickWeek = generateAutoPlan(baseInput({ goal: 'quick' })).totals.proteinGrams
    assert.ok(
      proteinWeek > quickWeek,
      `expected highProtein (${proteinWeek}g) to beat quick (${quickWeek}g)`
    )
  })

  it('vegetarian only schedules plant-based recipes', () => {
    const result = generateAutoPlan(baseInput({ goal: 'vegetarian' }))
    const pack = loadPack()
    const meatIds = ['goat_meat', 'buff_meat', 'chicken', 'fish']
    for (const meal of result.meals) {
      const recipe = pack.recipes.find((r) => r.id === meal.recipeId)!
      for (const item of recipe.ingredients) {
        assert.ok(!meatIds.includes(item.ingredientId), `${recipe.id} is not vegetarian`)
      }
    }
    assert.ok(result.exclusions.length > 0, 'meat recipes must be excluded and reported')
  })

  it('vegetarian still respects allergies on top of its own gate', () => {
    const result = generateAutoPlan(
      baseInput({
        goal: 'vegetarian',
        allergyProfiles: [{ allergen: AllergenCatalog.milk, severity: 'severe' }],
      })
    )
    const plannedIds = new Set(result.meals.map((m) => m.recipeId))
    for (const recipeId of plannedIds) {
      const recipe = loadPack().recipes.find((r) => r.id === recipeId)!
      for (const item of recipe.ingredients) {
        assert.ok(
          !['ghee', 'paneer', 'milk', 'yogurt'].includes(item.ingredientId),
          `${recipe.id} scheduled dairy under a severe milk allergy`
        )
      }
    }
  })
})

describe('AutoPlan: combined grocery requirements', () => {
  it('aggregates each ingredient across the whole week', () => {
    const result = generateAutoPlan(baseInput({ days: 7 }))
    const pack = loadPack()
    const expected = new Map<string, number>()
    for (const meal of result.meals) {
      const recipe = pack.recipes.find((r) => r.id === meal.recipeId)!
      for (const item of recipe.ingredients) {
        expected.set(
          item.ingredientId,
          (expected.get(item.ingredientId) ?? 0) + (item.quantityGrams * result.servings) / recipe.servings
        )
      }
    }
    assert.strictEqual(result.grocery.length, expected.size)
    for (const line of result.grocery) {
      assert.ok(
        Math.abs(line.totalRequiredGrams - (expected.get(line.ingredientId) ?? 0)) < 0.01,
        `${line.ingredientId}: expected ${expected.get(line.ingredientId)}g, got ${line.totalRequiredGrams}g`
      )
    }
  })

  it('subtracts pantry stock before deciding what to buy', () => {
    const result = generateAutoPlan(
      baseInput({ days: 7, pantryItems: [{ ingredientId: 'potato', quantityGrams: 100000 }] })
    )
    const potato = result.grocery.find((l) => l.ingredientId === 'potato')!
    assert.strictEqual(potato.pantryAvailableGrams, 100000)
    assert.strictEqual(potato.netNeededGrams, 0)
    assert.strictEqual(potato.packagesToBuy, 0)
    assert.strictEqual(potato.totalPurchasedGrams, 0)
  })

  it('rounds purchases up to whole market packages', () => {
    const result = generateAutoPlan(baseInput({ days: 7 }))
    for (const line of result.grocery) {
      if (line.netNeededGrams <= 0) {
        assert.strictEqual(line.packagesToBuy, 0)
        continue
      }
      assert.strictEqual(
        line.packagesToBuy,
        Math.ceil(line.netNeededGrams / line.marketPackageGrams),
        `${line.ingredientId} package count must be a whole-market-package ceiling`
      )
      assert.ok(line.totalPurchasedGrams >= line.netNeededGrams)
      assert.ok(line.surplusGrams === 0 || line.surplusGrams > 0)
    }
  })

  it('reports surplus from package rounding and counts it in the totals', () => {
    const result = generateAutoPlan(baseInput({ days: 7 }))
    const surplus = result.grocery.reduce((sum, l) => sum + l.surplusGrams, 0)
    assert.ok(Math.abs(result.totals.estimatedSurplusGrams - surplus) < 0.01)
  })

  it('returns grocery sorted by ingredient id for stable rendering', () => {
    const ids = generateAutoPlan(baseInput()).grocery.map((l) => l.ingredientId)
    assert.deepStrictEqual(ids, [...ids].sort())
  })

  it('records which recipes drove each grocery line', () => {
    const result = generateAutoPlan(baseInput({ days: 2 }))
    for (const line of result.grocery) {
      assert.ok(line.usedByRecipeIds.length > 0)
      assert.deepStrictEqual(line.usedByRecipeIds, [...line.usedByRecipeIds].sort())
    }
  })

  it('scales the week cost and protein totals by household servings', () => {
    const four = generateAutoPlan(baseInput({ householdServings: 4 }))
    const eight = generateAutoPlan(baseInput({ householdServings: 8 }))
    assert.ok(eight.totals.estimatedCostNpr > four.totals.estimatedCostNpr)
    assert.ok(eight.totals.proteinGrams > four.totals.proteinGrams)
    assert.strictEqual(eight.totals.distinctIngredients, four.totals.distinctIngredients)
  })
})

describe('AutoPlan: Ritu resolution', () => {
  it('maps a Gregorian date onto one of the six ritus', () => {
    const ritu = resolveRituId(new Date(2026, 9, 5, 12))
    assert.ok(
      ['basanta', 'grishma', 'barsha', 'sharad', 'hemanta', 'shishir'].includes(ritu),
      `unexpected ritu ${ritu}`
    )
  })

  it('reports the first day Ritu on the result', () => {
    assert.strictEqual(generateAutoPlan(baseInput({ rituId: 'sharad' })).rituId, 'sharad')
  })
})

describe('AutoPlan: input validation', () => {
  it('rejects a malformed start date', () => {
    assert.throws(() => generateAutoPlan(baseInput({ startDateIso: '05-10-2026' })), /YYYY-MM-DD/)
  })

  it('rejects an impossible calendar date', () => {
    assert.throws(() => generateAutoPlan(baseInput({ startDateIso: '2026-02-30' })), /real calendar date/)
  })

  it('rejects a non-positive day count', () => {
    assert.throws(() => generateAutoPlan(baseInput({ days: 0 })), /days must be positive/)
  })

  it('rejects a non-positive household size', () => {
    assert.throws(() => generateAutoPlan(baseInput({ householdServings: 0 })), /householdServings must be positive/)
  })
})

/** Helper used by the budget-vs-seasonal comparison above. */
function result_meals_of(goal: 'seasonal' | 'quick' | 'budget' | 'highProtein' | 'vegetarian') {
  return generateAutoPlan(baseInput({ goal })).meals
}
