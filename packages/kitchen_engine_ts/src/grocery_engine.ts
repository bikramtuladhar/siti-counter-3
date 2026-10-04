import { toDevanagariDigits } from './nepali_calendar.js'
import { MarketCalculator } from './index.js'
import type { PlanRecipe, PlanIngredient } from './auto_plan.js'

export type MarketStallType = 'vegetables' | 'fruit' | 'meat_fish' | 'spices' | 'grains_staples'

export interface MarketStallInfo {
  id: MarketStallType
  nameEn: string
  nameNe: string
  shortNameNe: string
  icon: string
  sortOrder: number
}

export const MARKET_STALLS: Record<MarketStallType, MarketStallInfo> = {
  vegetables: {
    id: 'vegetables',
    nameEn: 'Vegetables',
    nameNe: 'तरकारी गल्ली (Vegetables)',
    shortNameNe: 'तरकारी',
    icon: '🥕',
    sortOrder: 0,
  },
  fruit: {
    id: 'fruit',
    nameEn: 'Fruit',
    nameNe: 'फलफूल (Fruit)',
    shortNameNe: 'फलफूल',
    icon: '🍎',
    sortOrder: 1,
  },
  meat_fish: {
    id: 'meat_fish',
    nameEn: 'Meat/Fish',
    nameNe: 'मासु तथा माछा (Meat & Fish)',
    shortNameNe: 'मासु/माछा',
    icon: '🍗',
    sortOrder: 2,
  },
  spices: {
    id: 'spices',
    nameEn: 'Spices',
    nameNe: 'मसला गल्ली (Spices)',
    shortNameNe: 'मसला',
    icon: '🌶️',
    sortOrder: 3,
  },
  grains_staples: {
    id: 'grains_staples',
    nameEn: 'Grains/Staples',
    nameNe: 'खाद्यान्न तथा दाल-चामल (Grains/Staples)',
    shortNameNe: 'खाद्यान्न',
    icon: '🌾',
    sortOrder: 4,
  },
}

export function resolveMarketStall(category?: string | null): MarketStallType {
  if (!category) return 'grains_staples'
  switch (category.toLowerCase().trim()) {
    case 'vegetables':
    case 'greens':
    case 'fermented':
      return 'vegetables'
    case 'fruits':
    case 'fruit':
      return 'fruit'
    case 'meat':
    case 'fish':
      return 'meat_fish'
    case 'spices':
    case 'aromatics':
    case 'seeds':
      return 'spices'
    case 'grains':
    case 'pulses':
    case 'flour':
    case 'oils':
    case 'dairy':
    case 'sweeteners':
    default:
      return 'grains_staples'
  }
}

export function formatVendorQuantity(params: {
  totalGrams: number
  standardUnit: string
  marketPackageGrams: number
  packagesToBuy: number
  preferNepali?: boolean
}): string {
  const { totalGrams, standardUnit, packagesToBuy, preferNepali = false } = params
  if (packagesToBuy <= 0) {
    return preferNepali ? `० ${toDevanagariDigits(0)}` : `0 ${standardUnit}`
  }

  const unitLower = standardUnit.toLowerCase().trim()
  const intGrams = Math.round(totalGrams)

  if (unitLower === 'pau') {
    if (intGrams >= 1000 && intGrams % 1000 === 0) {
      const kg = Math.round(intGrams / 1000)
      return preferNepali
        ? `${toDevanagariDigits(kg)} के.जी. (${toDevanagariDigits(packagesToBuy)} पाउ)`
        : `${kg} kg (${packagesToBuy} pau)`
    }
    return preferNepali
      ? `${toDevanagariDigits(packagesToBuy)} पाउ (${toDevanagariDigits(intGrams)} ग्राम)`
      : `${packagesToBuy} pau (${intGrams} g)`
  }

  if (unitLower === 'kg') {
    const kgVal = totalGrams / 1000.0
    const isWhole = kgVal === Math.round(kgVal)
    const formattedKg = isWhole ? Math.round(kgVal).toString() : kgVal.toFixed(1)
    return preferNepali
      ? `${toDevanagariDigits(formattedKg)} के.जी.`
      : `${formattedKg} kg`
  }

  if (unitLower === 'mana') {
    return preferNepali
      ? `${toDevanagariDigits(packagesToBuy)} माना (${toDevanagariDigits(intGrams)} ग्राम)`
      : `${packagesToBuy} mana (${intGrams} g)`
  }

  if (unitLower === 'bunch' || unitLower === 'muthi') {
    const unitEn = packagesToBuy === 1 ? 'bunch' : 'bunches'
    return preferNepali
      ? `${toDevanagariDigits(packagesToBuy)} मुठा (${toDevanagariDigits(intGrams)} ग्राम)`
      : `${packagesToBuy} ${unitEn} (${intGrams} g)`
  }

  if (unitLower === 'piece') {
    const unitEn = packagesToBuy === 1 ? 'piece' : 'pieces'
    return preferNepali
      ? `${toDevanagariDigits(packagesToBuy)} वटा (${toDevanagariDigits(intGrams)} ग्राम)`
      : `${packagesToBuy} ${unitEn} (${intGrams} g)`
  }

  if (unitLower === 'packet') {
    const unitEn = packagesToBuy === 1 ? 'packet' : 'packets'
    return preferNepali
      ? `${toDevanagariDigits(packagesToBuy)} प्याकेट (${toDevanagariDigits(intGrams)} ग्राम)`
      : `${packagesToBuy} ${unitEn} (${intGrams} g)`
  }

  if (unitLower === 'l') {
    return preferNepali
      ? `${toDevanagariDigits(packagesToBuy)} लिटर`
      : `${packagesToBuy} L`
  }

  if (intGrams >= 1000) {
    const kgVal = totalGrams / 1000.0
    const isWhole = kgVal === Math.round(kgVal)
    const formattedKg = isWhole ? Math.round(kgVal).toString() : kgVal.toFixed(1)
    return preferNepali
      ? `${toDevanagariDigits(formattedKg)} के.जी.`
      : `${formattedKg} kg`
  }
  return preferNepali
    ? `${toDevanagariDigits(intGrams)} ग्राम`
    : `${intGrams} g`
}

export interface GroceryItem {
  ingredientId: string
  nameEn: string
  nameNe: string
  category: string
  stall: MarketStallType
  standardUnit: string
  totalRequiredGrams: number
  pantryAvailableGrams: number
  netNeededGrams: number
  marketPackageGrams: number
  packagesToBuy: number
  totalPurchasedGrams: number
  surplusGrams: number
  vendorUnitLabelEn: string
  vendorUnitLabelNe: string
  surplusSuggestionEn?: string
  surplusSuggestionNe?: string
  availability: string
  storageDays: number
  usedByRecipeIds: string[]
  usedByRecipeTitlesEn: string[]
  usedByRecipeTitlesNe: string[]
  isSufficientInPantry: boolean
}

export interface GroceryStallGroup {
  stall: MarketStallType
  nameEn: string
  nameNe: string
  shortNameNe: string
  icon: string
  items: GroceryItem[]
}

export interface GroceryListResult {
  items: GroceryItem[]
  stalls: GroceryStallGroup[]
  totalItems: number
  totalItemsToBuy: number
  totalPantryCoveredItems: number
  totalPurchasedGrams: number
  totalSurplusGrams: number
}

export interface GroceryPlanMealInput {
  recipeId: string
  servings: number
  recipeTitleEn?: string
  recipeTitleNe?: string
  dateIso?: string
  slotId?: string
}

export function generateGroceryList(params: {
  meals: GroceryPlanMealInput[]
  recipes: PlanRecipe[]
  ingredients: PlanIngredient[]
  pantryAvailableGrams?: Record<string, number>
  rituId?: string
  ingredientCategories?: Record<string, string>
  ingredientStandardUnits?: Record<string, string>
}): GroceryListResult {
  const {
    meals,
    recipes,
    ingredients,
    pantryAvailableGrams = {},
    rituId = 'sharad',
    ingredientCategories = {},
    ingredientStandardUnits = {},
  } = params

  const recipeById = new Map<string, PlanRecipe>()
  for (const r of recipes) {
    recipeById.set(r.id, r)
  }

  const ingredientById = new Map<string, PlanIngredient>()
  for (const i of ingredients) {
    ingredientById.set(i.id, i)
  }

  const requiredGrams = new Map<string, number>()
  const usedByRecipeIds = new Map<string, Set<string>>()
  const usedByTitlesEn = new Map<string, Set<string>>()
  const usedByTitlesNe = new Map<string, Set<string>>()

  for (const meal of meals) {
    const recipe = recipeById.get(meal.recipeId)
    if (!recipe) continue

    const servings = meal.servings > 0 ? meal.servings : recipe.servings
    const scale = servings / recipe.servings

    for (const ing of recipe.ingredients) {
      const grams = ing.quantityGrams * scale
      requiredGrams.set(ing.ingredientId, (requiredGrams.get(ing.ingredientId) ?? 0) + grams)

      if (!usedByRecipeIds.has(ing.ingredientId)) {
        usedByRecipeIds.set(ing.ingredientId, new Set())
        usedByTitlesEn.set(ing.ingredientId, new Set())
        usedByTitlesNe.set(ing.ingredientId, new Set())
      }
      usedByRecipeIds.get(ing.ingredientId)!.add(recipe.id)

      const titleEn = meal.recipeTitleEn ?? recipe.titleEn
      const titleNe = meal.recipeTitleNe ?? recipe.titleNe
      usedByTitlesEn.get(ing.ingredientId)!.add(titleEn)
      usedByTitlesNe.get(ing.ingredientId)!.add(titleNe)
    }
  }

  const sortedIngredientIds = Array.from(requiredGrams.keys()).sort()
  const items: GroceryItem[] = []

  for (const ingId of sortedIngredientIds) {
    const totalReq = Math.round((requiredGrams.get(ingId) ?? 0) * 10) / 10
    const ingMeta = ingredientById.get(ingId)
    const pantryGrams = Math.max(0, pantryAvailableGrams[ingId] ?? 0)
    const netNeeded = Math.max(0, totalReq - pantryGrams)

    const marketPkgGrams = ingMeta && ingMeta.marketPackageGrams > 0 ? ingMeta.marketPackageGrams : 250
    const packagesToBuy = netNeeded > 0 ? Math.ceil(netNeeded / marketPkgGrams) : 0
    const totalPurchased = packagesToBuy * marketPkgGrams
    const surplus = Math.max(0, pantryGrams + totalPurchased - totalReq)

    const category = ingredientCategories[ingId] ?? 'vegetables'
    const standardUnit = ingredientStandardUnits[ingId] ?? (marketPkgGrams >= 1000 ? 'kg' : 'pau')
    const stall = resolveMarketStall(category)

    const nameEn = ingMeta?.nameEn ?? ingId
    const nameNe = ingMeta?.nameNe ?? ingId

    const vendorEn = formatVendorQuantity({
      totalGrams: totalPurchased > 0 ? totalPurchased : totalReq,
      standardUnit,
      marketPackageGrams: marketPkgGrams,
      packagesToBuy: packagesToBuy > 0 ? packagesToBuy : 0,
      preferNepali: false,
    })

    const vendorNe = formatVendorQuantity({
      totalGrams: totalPurchased > 0 ? totalPurchased : totalReq,
      standardUnit,
      marketPackageGrams: marketPkgGrams,
      packagesToBuy: packagesToBuy > 0 ? packagesToBuy : 0,
      preferNepali: true,
    })

    const suggestion = MarketCalculator.getSurplusSuggestion(nameEn, surplus)
    const availability = ingMeta?.availability?.[rituId] ?? 'available'

    items.push({
      ingredientId: ingId,
      nameEn,
      nameNe,
      category,
      stall,
      standardUnit,
      totalRequiredGrams: totalReq,
      pantryAvailableGrams: Math.round(pantryGrams * 10) / 10,
      netNeededGrams: Math.round(netNeeded * 10) / 10,
      marketPackageGrams: marketPkgGrams,
      packagesToBuy,
      totalPurchasedGrams: Math.round(totalPurchased * 10) / 10,
      surplusGrams: Math.round(surplus * 10) / 10,
      vendorUnitLabelEn: vendorEn,
      vendorUnitLabelNe: vendorNe,
      surplusSuggestionEn: suggestion.en,
      surplusSuggestionNe: suggestion.ne,
      availability,
      storageDays: ingMeta?.storageDays ?? 7,
      usedByRecipeIds: Array.from(usedByRecipeIds.get(ingId) ?? []).sort(),
      usedByRecipeTitlesEn: Array.from(usedByTitlesEn.get(ingId) ?? []).sort(),
      usedByRecipeTitlesNe: Array.from(usedByTitlesNe.get(ingId) ?? []).sort(),
      isSufficientInPantry: netNeeded === 0,
    })
  }

  const stallsInOrder: MarketStallType[] = ['vegetables', 'fruit', 'meat_fish', 'spices', 'grains_staples']
  const stallGroups: GroceryStallGroup[] = []

  for (const stallType of stallsInOrder) {
    const stallItems = items.filter((i) => i.stall === stallType)
    if (stallItems.length > 0) {
      stallItems.sort((a, b) => {
        if (a.isSufficientInPantry !== b.isSufficientInPantry) {
          return a.isSufficientInPantry ? 1 : -1
        }
        return a.nameEn.localeCompare(b.nameEn)
      })

      const info = MARKET_STALLS[stallType]
      stallGroups.push({
        stall: stallType,
        nameEn: info.nameEn,
        nameNe: info.nameNe,
        shortNameNe: info.shortNameNe,
        icon: info.icon,
        items: stallItems,
      })
    }
  }

  const itemsToBuy = items.filter((i) => !i.isSufficientInPantry).length
  const pantryCovered = items.filter((i) => i.isSufficientInPantry).length
  const totalPurchasedSum = items.reduce((sum, i) => sum + i.totalPurchasedGrams, 0)
  const totalSurplusSum = items.reduce((sum, i) => sum + i.surplusGrams, 0)

  return {
    items,
    stalls: stallGroups,
    totalItems: items.length,
    totalItemsToBuy: itemsToBuy,
    totalPantryCoveredItems: pantryCovered,
    totalPurchasedGrams: Math.round(totalPurchasedSum * 10) / 10,
    totalSurplusGrams: Math.round(totalSurplusSum * 10) / 10,
  }
}
