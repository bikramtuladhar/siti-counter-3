/**
 * Pure TypeScript Kitchen Engine for Siti Counter 3.0
 * Shared between Vue 3 Web and Cloudflare Workers API
 */
import { toDevanagariDigits } from './nepali_calendar.js'

export const UnitConverter = {
  // Mass in grams
  pauInGrams: 250.0,
  dharniInGrams: 2500.0,
  tolaInGrams: 11.6638,
  seerInGrams: 933.1,
  muthiInGrams: 50.0,

  // Volume in milliliters
  manaInMl: 568.0,
  metricCupInMl: 250.0,
  usCupInMl: 240.0,
  tablespoonInMl: 15.0,
  teaspoonInMl: 5.0,

  // Mass
  pauToGrams(pau: number): number {
    return pau * this.pauInGrams
  },

  gramsToPau(grams: number): number {
    return grams / this.pauInGrams
  },

  dharniToGrams(dharni: number): number {
    return dharni * this.dharniInGrams
  },

  gramsToDharni(grams: number): number {
    return grams / this.dharniInGrams
  },

  tolaToGrams(tola: number): number {
    return tola * this.tolaInGrams
  },

  gramsToTola(grams: number): number {
    return grams / this.tolaInGrams
  },

  seerToGrams(seer: number): number {
    return seer * this.seerInGrams
  },

  gramsToSeer(grams: number): number {
    return grams / this.seerInGrams
  },

  muthiToGrams(muthi: number): number {
    return muthi * this.muthiInGrams
  },

  gramsToMuthi(grams: number): number {
    return grams / this.muthiInGrams
  },

  // Volume
  manaToMl(mana: number): number {
    return mana * this.manaInMl
  },

  mlToMana(ml: number): number {
    return ml / this.manaInMl
  },

  metricCupToMl(cups: number): number {
    return cups * this.metricCupInMl
  },

  mlToMetricCup(ml: number): number {
    return ml / this.metricCupInMl
  },

  usCupToMl(cups: number): number {
    return cups * this.usCupInMl
  },

  mlToUsCup(ml: number): number {
    return ml / this.usCupInMl
  },

  tablespoonToMl(tbsp: number): number {
    return tbsp * this.tablespoonInMl
  },

  mlToTablespoon(ml: number): number {
    return ml / this.tablespoonInMl
  },

  teaspoonToMl(tsp: number): number {
    return tsp * this.teaspoonInMl
  },

  mlToTeaspoon(ml: number): number {
    return ml / this.teaspoonInMl
  },

  formatLocalUnit(grams: number, preferNepali = false): string {
    if (grams >= this.dharniInGrams) {
      const dharni = grams / this.dharniInGrams
      const formatted = dharni % 1 === 0 ? dharni.toFixed(0) : dharni.toFixed(1)
      return preferNepali ? `${formatted} धार्नी` : `${formatted} dharni`
    } else if (grams >= this.pauInGrams && grams % this.pauInGrams === 0) {
      const pau = Math.round(grams / this.pauInGrams)
      return preferNepali ? `${pau} पाउ` : `${pau} pau`
    } else if (grams >= 1000) {
      const kg = grams / 1000.0
      const formatted = kg % 1 === 0 ? kg.toFixed(0) : kg.toFixed(1)
      return preferNepali ? `${formatted} के.जी.` : `${formatted} kg`
    } else {
      return preferNepali ? `${Math.round(grams)} ग्राम` : `${Math.round(grams)} g`
    }
  }
}

export type PantryStatus = 'sufficient' | 'partiallyAvailable' | 'missing'

export interface IngredientPurchasePlan {
  ingredientId: string
  ingredientNameEn: string
  ingredientNameNe: string
  recipeRequiredGrams: number
  pantryAvailableGrams: number
  netNeededGrams: number
  vendorUnitLabelEn: string
  vendorUnitLabelNe: string
  packagesToBuy: number
  totalPurchasedGrams: number
  surplusGrams: number
  surplusSuggestionEn?: string
  surplusSuggestionNe?: string
  status: PantryStatus
}

export interface PurchaseRecommendation {
  ingredientName: string
  recipeQuantityGrams: number
  packageSizeGrams: number
  packagesToBuy: number
  totalPurchasedGrams: number
  surplusGrams: number
  surplusSuggestion?: string
}

export const MarketCalculator = {
  formatVendorUnits(grams: number, preferNepali = false): string {
    if (grams >= 1000 && grams % 1000 === 0) {
      const kg = Math.round(grams / 1000)
      const pau = Math.round(grams / 250)
      return preferNepali
        ? `${toDevanagariDigits(kg)} के.जी. (${toDevanagariDigits(pau)} पाउ)`
        : `${kg} kg (${pau} pau)`
    }
    if (grams >= 250 && grams % 250 === 0) {
      const pau = Math.round(grams / 250)
      return preferNepali
        ? `${toDevanagariDigits(pau)} पाउ (${toDevanagariDigits(grams)} ग्राम)`
        : `${pau} pau (${grams} g)`
    }
    return preferNepali
      ? `${toDevanagariDigits(Math.round(grams))} ग्राम`
      : `${Math.round(grams)} g`
  },

  getSurplusSuggestion(
    ingredientName: string,
    surplusGrams: number
  ): { en?: string; ne?: string } {
    const lower = ingredientName.toLowerCase()
    if (surplusGrams >= 150) {
      if (lower.includes('tomato') || lower.includes('गोलभेडा')) {
        return {
          en: `Leftover ${Math.round(surplusGrams)}g tomatoes make fresh fire-roasted tomato achar (गोलभेडाको अचार)`,
          ne: `बाँकी ${Math.round(surplusGrams)} ग्राम गोलभेडा: पोलेको गोलभेडाको ताजा अचार बनाउन उत्तम`
        }
      }
      if (lower.includes('potato') || lower.includes('आलु')) {
        return {
          en: `Leftover ${Math.round(surplusGrams)}g potatoes can be used for tomorrow's aloo paratha or tarkari`,
          ne: `बाँकी ${Math.round(surplusGrams)} ग्राम आलु: भोलिको आलु पराठा वा खाजा बनाउन प्रयोग गर्नुहोस्`
        }
      }
      if (lower.includes('radish') || lower.includes('मूला')) {
        return {
          en: `Leftover ${Math.round(surplusGrams)}g radish: Slice and sun-dry for fermented radish achar (मूलाको चाना/अचार)`,
          ne: `बाँकी ${Math.round(surplusGrams)} ग्राम मूला: चाना बनाएर घाममा सुकाई स्वादिष्ट अचार बनाउनुहोस्`
        }
      }
      if (lower.includes('cauliflower') || lower.includes('काउली')) {
        return {
          en: `Leftover ${Math.round(surplusGrams)}g cauliflower: Pair with green peas for tomorrow's curry`,
          ne: `बाँकी ${Math.round(surplusGrams)} ग्राम काउली: भोलिको लागि केराउसँग तरकारी बनाउनुहोस्`
        }
      }
      if (lower.includes('spinach') || lower.includes('पालुङ्गो') || lower.includes('saag') || lower.includes('साग')) {
        return {
          en: 'Cook remaining greens within 2 days or wilt for gundruk fermentation',
          ne: 'बाँकी साग २ दिनभित्र पकाउनुहोस् वा गुन्द्रुक बनाउन ओइलाउनुहोस्'
        }
      }
      if (lower.includes('ginger') || lower.includes('अदुवा') || lower.includes('garlic') || lower.includes('लसुन')) {
        return {
          en: 'Store leftover peeled paste in clean jar with oil and salt',
          ne: 'बाँकी अदुवा-लसुनको पेस्टमा थोरै तेल र नुन मोलेर सिसाको बट्टामा राख्नुहोस्'
        }
      }
    }
    return {}
  },

  calculatePurchase(params: {
    ingredientName: string
    recipeQuantityGrams: number
    standardPackageGrams: number
    alreadyHaveGrams?: number
  }): PurchaseRecommendation {
    const {
      ingredientName,
      recipeQuantityGrams,
      standardPackageGrams,
      alreadyHaveGrams = 0
    } = params

    const netNeeded = Math.max(0, recipeQuantityGrams - alreadyHaveGrams)

    if (netNeeded === 0) {
      return {
        ingredientName,
        recipeQuantityGrams,
        packageSizeGrams: standardPackageGrams,
        packagesToBuy: 0,
        totalPurchasedGrams: 0,
        surplusGrams: alreadyHaveGrams - recipeQuantityGrams
      }
    }

    const packagesToBuy = Math.ceil(netNeeded / standardPackageGrams)
    const totalPurchasedGrams = packagesToBuy * standardPackageGrams
    const totalAvailable = alreadyHaveGrams + totalPurchasedGrams
    const surplusGrams = totalAvailable - recipeQuantityGrams

    const suggestionObj = this.getSurplusSuggestion(ingredientName, surplusGrams)

    return {
      ingredientName,
      recipeQuantityGrams,
      packageSizeGrams: standardPackageGrams,
      packagesToBuy,
      totalPurchasedGrams,
      surplusGrams,
      surplusSuggestion: suggestionObj.en
    }
  },

  calculatePurchasePlan(params: {
    ingredientId: string
    nameEn: string
    nameNe: string
    recipeQuantityGrams: number
    standardPackageGrams: number
    pantryAvailableGrams?: number
  }): IngredientPurchasePlan {
    const {
      ingredientId,
      nameEn,
      nameNe,
      recipeQuantityGrams,
      standardPackageGrams,
      pantryAvailableGrams = 0
    } = params

    const netNeededGrams = Math.max(0, recipeQuantityGrams - pantryAvailableGrams)

    let status: PantryStatus
    if (netNeededGrams === 0) {
      status = 'sufficient'
    } else if (pantryAvailableGrams > 0) {
      status = 'partiallyAvailable'
    } else {
      status = 'missing'
    }

    const packagesToBuy = netNeededGrams > 0
      ? Math.ceil(netNeededGrams / standardPackageGrams)
      : 0
    const totalPurchasedGrams = packagesToBuy * standardPackageGrams
    const totalAvailable = pantryAvailableGrams + totalPurchasedGrams
    const surplusGrams = Math.max(0, totalAvailable - recipeQuantityGrams)

    const suggestion = this.getSurplusSuggestion(nameEn, surplusGrams)

    return {
      ingredientId,
      ingredientNameEn: nameEn,
      ingredientNameNe: nameNe,
      recipeRequiredGrams: recipeQuantityGrams,
      pantryAvailableGrams,
      netNeededGrams,
      vendorUnitLabelEn: this.formatVendorUnits(totalPurchasedGrams, false),
      vendorUnitLabelNe: this.formatVendorUnits(totalPurchasedGrams, true),
      packagesToBuy,
      totalPurchasedGrams,
      surplusGrams,
      surplusSuggestionEn: suggestion.en,
      surplusSuggestionNe: suggestion.ne,
      status
    }
  }
}

export const AltitudeCalculator = {
  boilingPointCelsius(elevationMeters: number): number {
    if (elevationMeters <= 0) return 100.0
    return 100.0 - elevationMeters / 285.0
  },

  adjustSitiCount(baseSiti: number, elevationMeters: number): number {
    if (elevationMeters < 800) return baseSiti
    if (elevationMeters < 1800) {
      return baseSiti >= 3 ? baseSiti + 1 : baseSiti
    }
    return Math.round(baseSiti * 1.3)
  },

  altitudeExplanation(originalSiti: number, adjustedSiti: number, elevationMeters: number): string {
    if (originalSiti === adjustedSiti) {
      return `At ${Math.round(elevationMeters)} m: standard cooking pressure`
    }
    return `At ${Math.round(elevationMeters)} m: ${adjustedSiti} siti instead of ${originalSiti} (water boils at ${this.boilingPointCelsius(elevationMeters).toFixed(1)}°C)`
  }
}

export * from './nepali_calendar.js';
export * from './allergen_engine.js';
export * from './auto_plan.js';
export * from './grocery_engine.js';
export * from './sync_engine.js';
export * from './region_pack_manager.js';
export * from './consumption_engine.js';
export * from './nutrition_engine.js';
export * from './waste_engine.js';
export * from './crew_engine.js';
export * from './assistant_engine.js';
export * from './voice_engine.js';
export * from './signal_engine.js';
export * from './allergen_card_engine.js';
export * from './smart_display_engine.js';
export * from './fuel_engine.js';
export * from './subscription_engine.js';
export * from './retailer_handoff_engine.js';
export * from './community_engine.js';
export * from './ocr_engine.js';
export * from './party_planner_engine.js';
export * from './launch_gate_monitor.js';
export * from './multi_dish_kitchen_engine.js';
export * from './companion_display_engine.js';
export * from './meal_role_engine.js';


