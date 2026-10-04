import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  resolveMarketStall,
  formatVendorQuantity,
  generateGroceryList,
  exportGroceryListText,
  MARKET_STALLS,
} from './grocery_engine.js'
import type { PlanRecipe, PlanIngredient } from './auto_plan.js'

const __dirname = dirname(fileURLToPath(import.meta.url))

function loadPack() {
  const packDir = resolve(__dirname, '../../region-packs/nepal-bagmati')
  const recipesRaw = JSON.parse(readFileSync(resolve(packDir, 'recipes.json'), 'utf-8'))
  const ingredientsRaw = JSON.parse(readFileSync(resolve(packDir, 'ingredients.json'), 'utf-8'))

  const recipes: PlanRecipe[] = recipesRaw.map((r: any) => ({
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
    ingredients: r.ingredients.map((ri: any) => ({
      ingredientId: ri.ingredientId,
      quantityGrams: ri.quantity,
    })),
    tags: r.tags ?? [],
  }))

  const ingredients: PlanIngredient[] = ingredientsRaw.map((i: any) => ({
    id: i.id,
    nameEn: i.nameEn,
    nameNe: i.nameNe,
    marketPackageGrams: i.marketPackageGrams,
    storageDays: i.storageDays,
    availability: i.availability,
  }))

  const ingredientCategories: Record<string, string> = {}
  const ingredientStandardUnits: Record<string, string> = {}
  for (const i of ingredientsRaw) {
    ingredientCategories[i.id] = i.category
    ingredientStandardUnits[i.id] = i.standardUnit
  }

  return { recipes, ingredients, ingredientCategories, ingredientStandardUnits }
}

describe('TypeScript GroceryEngine: Stall Resolution', () => {
  it('resolves wet market stalls from categories accurately', () => {
    assert.equal(resolveMarketStall('vegetables'), 'vegetables')
    assert.equal(resolveMarketStall('greens'), 'vegetables')
    assert.equal(resolveMarketStall('fermented'), 'vegetables')

    assert.equal(resolveMarketStall('fruits'), 'fruit')
    assert.equal(resolveMarketStall('fruit'), 'fruit')

    assert.equal(resolveMarketStall('meat'), 'meat_fish')
    assert.equal(resolveMarketStall('fish'), 'meat_fish')

    assert.equal(resolveMarketStall('spices'), 'spices')
    assert.equal(resolveMarketStall('aromatics'), 'spices')
    assert.equal(resolveMarketStall('seeds'), 'spices')

    assert.equal(resolveMarketStall('grains'), 'grains_staples')
    assert.equal(resolveMarketStall('pulses'), 'grains_staples')
    assert.equal(resolveMarketStall('flour'), 'grains_staples')
    assert.equal(resolveMarketStall('oils'), 'grains_staples')
    assert.equal(resolveMarketStall('dairy'), 'grains_staples')
    assert.equal(resolveMarketStall('sweeteners'), 'grains_staples')
    assert.equal(resolveMarketStall(null), 'grains_staples')
    assert.equal(resolveMarketStall('unknown'), 'grains_staples')
  })

  it('verifies stall metadata properties', () => {
    assert.equal(MARKET_STALLS.vegetables.id, 'vegetables')
    assert.equal(MARKET_STALLS.vegetables.icon, '🥕')
    assert.equal(MARKET_STALLS.fruit.icon, '🍎')
    assert.equal(MARKET_STALLS.meat_fish.icon, '🍗')
    assert.equal(MARKET_STALLS.spices.icon, '🌶️')
    assert.equal(MARKET_STALLS.grains_staples.icon, '🌾')

    assert.equal(MARKET_STALLS.vegetables.nameEn, 'Vegetables')
    assert.ok(MARKET_STALLS.vegetables.nameNe.includes('तरकारी'))
    assert.ok(MARKET_STALLS.spices.nameNe.includes('मसला'))
    assert.ok(MARKET_STALLS.grains_staples.nameNe.includes('खाद्यान्न'))
  })
})

describe('TypeScript GroceryEngine: Vendor Unit Formatting', () => {
  it('formats pau units correctly in English and Devanagari', () => {
    assert.equal(
      formatVendorQuantity({
        totalGrams: 250,
        standardUnit: 'pau',
        marketPackageGrams: 250,
        packagesToBuy: 1,
        preferNepali: false,
      }),
      '1 pau (250 g)',
    )
    assert.equal(
      formatVendorQuantity({
        totalGrams: 250,
        standardUnit: 'pau',
        marketPackageGrams: 250,
        packagesToBuy: 1,
        preferNepali: true,
      }),
      '१ पाउ (२५० ग्राम)',
    )

    assert.equal(
      formatVendorQuantity({
        totalGrams: 1000,
        standardUnit: 'pau',
        marketPackageGrams: 250,
        packagesToBuy: 4,
        preferNepali: false,
      }),
      '1 kg (4 pau)',
    )
    assert.equal(
      formatVendorQuantity({
        totalGrams: 1000,
        standardUnit: 'pau',
        marketPackageGrams: 250,
        packagesToBuy: 4,
        preferNepali: true,
      }),
      '१ के.जी. (४ पाउ)',
    )
  })

  it('formats kg units correctly', () => {
    assert.equal(
      formatVendorQuantity({
        totalGrams: 2000,
        standardUnit: 'kg',
        marketPackageGrams: 1000,
        packagesToBuy: 2,
        preferNepali: false,
      }),
      '2 kg',
    )
    assert.equal(
      formatVendorQuantity({
        totalGrams: 2000,
        standardUnit: 'kg',
        marketPackageGrams: 1000,
        packagesToBuy: 2,
        preferNepali: true,
      }),
      '२ के.जी.',
    )
  })

  it('formats mana units (grains/pulses) correctly', () => {
    assert.equal(
      formatVendorQuantity({
        totalGrams: 800,
        standardUnit: 'mana',
        marketPackageGrams: 400,
        packagesToBuy: 2,
        preferNepali: false,
      }),
      '2 mana (800 g)',
    )
    assert.equal(
      formatVendorQuantity({
        totalGrams: 800,
        standardUnit: 'mana',
        marketPackageGrams: 400,
        packagesToBuy: 2,
        preferNepali: true,
      }),
      '२ माना (८०० ग्राम)',
    )
  })

  it('formats bunch / muthi units correctly', () => {
    assert.equal(
      formatVendorQuantity({
        totalGrams: 250,
        standardUnit: 'bunch',
        marketPackageGrams: 250,
        packagesToBuy: 1,
        preferNepali: false,
      }),
      '1 bunch (250 g)',
    )
    assert.equal(
      formatVendorQuantity({
        totalGrams: 500,
        standardUnit: 'muthi',
        marketPackageGrams: 250,
        packagesToBuy: 2,
        preferNepali: true,
      }),
      '२ मुठा (५०० ग्राम)',
    )
  })

  it('formats piece, packet, and liter units', () => {
    assert.equal(
      formatVendorQuantity({
        totalGrams: 1600,
        standardUnit: 'piece',
        marketPackageGrams: 800,
        packagesToBuy: 2,
        preferNepali: false,
      }),
      '2 pieces (1600 g)',
    )
    assert.equal(
      formatVendorQuantity({
        totalGrams: 200,
        standardUnit: 'packet',
        marketPackageGrams: 200,
        packagesToBuy: 1,
        preferNepali: true,
      }),
      '१ प्याकेट (२०० ग्राम)',
    )
    assert.equal(
      formatVendorQuantity({
        totalGrams: 910,
        standardUnit: 'l',
        marketPackageGrams: 910,
        packagesToBuy: 1,
        preferNepali: true,
      }),
      '१ लिटर',
    )
  })
})

describe('TypeScript GroceryEngine: Generation from Planned Meals', () => {
  const { recipes, ingredients, ingredientCategories, ingredientStandardUnits } = loadPack()

  it('aggregates ingredients across multiple planned meals for a week', () => {
    const meals = [
      { recipeId: 'aloo-gobi-tarkari', servings: 4 },
      { recipeId: 'aloo-tama-bodi', servings: 4 },
      { recipeId: 'kalo-dal-jimbu', servings: 4 },
    ]

    const result = generateGroceryList({
      meals,
      recipes,
      ingredients,
      ingredientCategories,
      ingredientStandardUnits,
    })

    assert.ok(result.totalItems > 0)
    assert.ok(result.stalls.length > 0)

    const potato = result.items.find((i) => i.ingredientId === 'potato')
    assert.ok(potato)
    assert.equal(potato.usedByRecipeIds.length, 2)
    assert.equal(potato.stall, 'vegetables')
    assert.ok(potato.totalRequiredGrams > 0)
    assert.ok(potato.packagesToBuy > 0)
    assert.equal(potato.isSufficientInPantry, false)
  })

  it('subtracts pantry quantities and marks sufficient items', () => {
    const meals = [{ recipeId: 'kalo-dal-jimbu', servings: 4 }]
    const pantryAvailableGrams = {
      kalo_dal: 1000.0,
      ghee: 500.0,
    }

    const result = generateGroceryList({
      meals,
      recipes,
      ingredients,
      pantryAvailableGrams,
      ingredientCategories,
      ingredientStandardUnits,
    })

    const kaloDal = result.items.find((i) => i.ingredientId === 'kalo_dal')
    assert.ok(kaloDal)
    assert.equal(kaloDal.isSufficientInPantry, true)
    assert.equal(kaloDal.netNeededGrams, 0)
    assert.equal(kaloDal.packagesToBuy, 0)

    const ghee = result.items.find((i) => i.ingredientId === 'ghee')
    assert.ok(ghee)
    assert.equal(ghee.isSufficientInPantry, true)
    assert.equal(ghee.packagesToBuy, 0)

    const jimbu = result.items.find((i) => i.ingredientId === 'jimbu')
    assert.ok(jimbu)
    assert.equal(jimbu.isSufficientInPantry, false)
    assert.ok(jimbu.packagesToBuy > 0)

    assert.ok(result.totalPantryCoveredItems >= 2)
  })

  it('orders stalls in standard Haat Bazaar walking order', () => {
    const meals = [
      { recipeId: 'khasiko-masu-jhol', servings: 4 },
      { recipeId: 'aloo-gobi-tarkari', servings: 4 },
      { recipeId: 'kalo-dal-jimbu', servings: 4 },
    ]

    const result = generateGroceryList({
      meals,
      recipes,
      ingredients,
      ingredientCategories,
      ingredientStandardUnits,
    })

    const stallIds = result.stalls.map((s) => s.stall)
    const vegIdx = stallIds.indexOf('vegetables')
    const meatIdx = stallIds.indexOf('meat_fish')
    const spiceIdx = stallIds.indexOf('spices')
    const grainsIdx = stallIds.indexOf('grains_staples')

    assert.ok(vegIdx !== -1)
    assert.ok(meatIdx !== -1)
    assert.ok(spiceIdx !== -1)
    assert.ok(grainsIdx !== -1)

    assert.ok(vegIdx < meatIdx)
    assert.ok(meatIdx < spiceIdx)
    assert.ok(spiceIdx < grainsIdx)
  })

  it('calculates surplus and generates surplus recommendations', () => {
    const meals = [{ recipeId: 'aloo-gobi-tarkari', servings: 6 }]

    const result = generateGroceryList({
      meals,
      recipes,
      ingredients,
      ingredientCategories,
      ingredientStandardUnits,
    })

    const tomato = result.items.find((i) => i.ingredientId === 'tomato')
    assert.ok(tomato)
    assert.ok(tomato.surplusGrams >= 150)
    assert.ok(tomato.surplusSuggestionEn?.includes('tomato achar'))
  })

  it('exports clean localized plain text for WhatsApp, Viber, or SMS', () => {
    const meals = [
      { recipeId: 'aloo-gobi-tarkari', servings: 4 },
      { recipeId: 'kalo-dal-jimbu', servings: 4 },
    ]

    const result = generateGroceryList({
      meals,
      recipes,
      ingredients,
      pantryAvailableGrams: { kalo_dal: 500.0 },
      ingredientCategories,
      ingredientStandardUnits,
    })

    const textNe = exportGroceryListText(result, { preferNepali: true })
    assert.ok(textNe.includes('🛒 सिटि काउन्टर - हप्ताको किनमेल सूची'))
    assert.ok(textNe.includes('तरकारी गल्ली'))
    assert.ok(textNe.includes('आलु'))
    assert.ok(textNe.includes('सिटि काउन्टर ३.०'))
    assert.ok(!textNe.includes('कालो दाल'))

    const textEn = exportGroceryListText(result, {
      preferNepali: false,
      includePantryCovered: true,
    })
    assert.ok(textEn.includes('🛒 Siti Counter - Weekly Grocery List'))
    assert.ok(textEn.includes('Vegetables:'))
    assert.ok(textEn.includes('Potato'))
    assert.ok(textEn.includes('[✓] Black Urad Lentils'))
    assert.ok(textEn.includes('Generated by Siti Counter 3.0'))
  })
})
