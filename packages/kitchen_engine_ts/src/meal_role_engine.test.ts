import { describe, it } from 'node:test'
import assert from 'node:assert'
import { MealSuggestionEngine, DishRoleResolver } from './meal_role_engine.js'
import type { RegionRecipe } from './region_pack_manager.js'

function makeRecipe(overrides: Partial<RegionRecipe> & { id: string }): RegionRecipe {
  return {
    titleEn: overrides.id,
    titleNe: overrides.id,
    category: 'dal',
    cuisine: 'nepali',
    dietary: [],
    prepTimeMinutes: 10,
    cookTimeMinutes: 20,
    servings: 4,
    difficulty: 'easy',
    ingredients: [],
    steps: [],
    seasonality: [],
    tags: [],
    ...overrides,
  } as RegionRecipe
}

const allTimes = ['morning', 'midday', 'evening', 'night']

describe('MealSuggestionEngine TypeScript Parity Tests', () => {
  it('never returns a side-dish-only recipe as the meal', () => {
    const recipes = [
      makeRecipe({ id: 'dal_bhat', dishRoles: ['mainCourse'], mealTimes: allTimes }),
      makeRecipe({
        id: 'achar',
        category: 'achar',
        dishRoles: ['sideDish'],
        mealTimes: allTimes,
      }),
    ]

    const out = MealSuggestionEngine.suggest({ recipes, slotId: 'dinner' })

    assert.deepStrictEqual(
      out.map((s) => s.mainCourse.id),
      ['dal_bhat'],
    )
  })

  it('attaches a side dish to a main rather than offering it alone', () => {
    const recipes = [
      makeRecipe({
        id: 'dal_bhat',
        dishRoles: ['mainCourse'],
        mealTimes: allTimes,
        ingredients: [{ ingredientId: 'rice', quantity: 1, unit: 'cup' }],
      }),
      makeRecipe({
        id: 'achar',
        category: 'achar',
        dishRoles: ['sideDish'],
        mealTimes: allTimes,
        ingredients: [{ ingredientId: 'rice', quantity: 1, unit: 'cup' }],
      }),
    ]

    const out = MealSuggestionEngine.suggest({ recipes, slotId: 'dinner' })

    assert.strictEqual(out.length, 1)
    assert.deepStrictEqual(
      out[0].sideDishes.map((d) => d.id),
      ['achar'],
    )
  })

  it('excludes an evening-only main course from breakfast', () => {
    const masu = makeRecipe({
      id: 'masu',
      category: 'masu',
      mealTimes: ['midday', 'evening', 'night'],
    })

    assert.strictEqual(DishRoleResolver.canBePlannedIn(masu, 'breakfast'), false)
    assert.strictEqual(DishRoleResolver.canBePlannedIn(masu, 'dinner'), true)
  })

  it('treats an undeclared role as a main course', () => {
    const plain = makeRecipe({ id: 'plain', mealTimes: allTimes })
    assert.strictEqual(DishRoleResolver.isMainCourse(plain), true)
  })

  it('removes an excluded ingredient from mains and accompaniments', () => {
    const recipes = [
      makeRecipe({
        id: 'dal_bhat',
        dishRoles: ['mainCourse'],
        mealTimes: allTimes,
        ingredients: [{ ingredientId: 'mustard', quantity: 1, unit: 'tbsp' }],
      }),
      makeRecipe({
        id: 'achar',
        category: 'achar',
        dishRoles: ['sideDish'],
        mealTimes: allTimes,
        ingredients: [{ ingredientId: 'mustard', quantity: 1, unit: 'tbsp' }],
      }),
      makeRecipe({
        id: 'tarkari',
        dishRoles: ['mainCourse'],
        mealTimes: allTimes,
        ingredients: [{ ingredientId: 'pumpkin', quantity: 1, unit: 'kg' }],
      }),
    ]

    const out = MealSuggestionEngine.suggest({
      recipes,
      slotId: 'dinner',
      excludedIngredientIds: new Set(['mustard']),
    })

    assert.deepStrictEqual(
      out.map((s) => s.mainCourse.id),
      ['tarkari'],
    )
    assert.strictEqual(out[0].sideDishes.length, 0)
  })

  it('ranks the dish closest to the slot time budget first', () => {
    const quick = makeRecipe({
      id: 'quick',
      mealTimes: allTimes,
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
    })
    const moderate = makeRecipe({
      id: 'moderate',
      mealTimes: allTimes,
      prepTimeMinutes: 20,
      cookTimeMinutes: 30,
    })
    const verySlow = makeRecipe({
      id: 'very_slow',
      mealTimes: allTimes,
      prepTimeMinutes: 30,
      cookTimeMinutes: 120,
    })
    // Worst-first, so a pass proves ranking rather than pack order.
    const recipes = [verySlow, moderate, quick]

    assert.strictEqual(
      MealSuggestionEngine.suggest({ recipes, slotId: 'breakfast' })[0].mainCourse.id,
      'quick',
    )
    assert.strictEqual(
      MealSuggestionEngine.suggest({ recipes, slotId: 'dinner' })[0].mainCourse.id,
      'moderate',
    )
  })

  it('ranks deterministically', () => {
    const recipes = [
      makeRecipe({ id: 'zebra', mealTimes: ['morning'] }),
      makeRecipe({ id: 'apple', mealTimes: ['morning'] }),
    ]

    assert.deepStrictEqual(
      MealSuggestionEngine.suggest({ recipes, slotId: 'breakfast' }).map((s) => s.mainCourse.id),
      ['apple', 'zebra'],
    )
  })

  it('returns nothing when the limit is zero', () => {
    const recipes = [makeRecipe({ id: 'dal_bhat', mealTimes: allTimes })]
    assert.deepStrictEqual(MealSuggestionEngine.suggest({ recipes, slotId: 'dinner', limit: 0 }), [])
  })
})