/**
 * Pure TypeScript Kitchen Engine for Siti Counter 3.0
 * Shared between Vue 3 Web and Cloudflare Workers API
 */

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

    let surplusSuggestion: string | undefined
    const lowerName = ingredientName.toLowerCase()
    if (surplusGrams >= 200) {
      if (lowerName.includes('tomato') || lowerName.includes('गोलभेडा')) {
        surplusSuggestion = 'Leftover tomatoes make fresh tomato achar (गोलभेडाको अचार)'
      } else if (lowerName.includes('potato') || lowerName.includes('आलु')) {
        surplusSuggestion = "Leftover potatoes can be used for tomorrow's khaja or aloo paratha"
      } else if (lowerName.includes('spinach') || lowerName.includes('पालुङ्गो')) {
        surplusSuggestion = 'Cook remaining spinach within 2 days to prevent wilting'
      }
    }

    return {
      ingredientName,
      recipeQuantityGrams,
      packageSizeGrams: standardPackageGrams,
      packagesToBuy,
      totalPurchasedGrams,
      surplusGrams,
      surplusSuggestion
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
