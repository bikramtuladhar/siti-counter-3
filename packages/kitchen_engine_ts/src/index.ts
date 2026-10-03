/**
 * Pure TypeScript Kitchen Engine for Siti Counter 3.0
 * Shared between Vue 3 Web and Cloudflare Workers API
 */

export const UnitConverter = {
  pauInGrams: 250,
  dharniInGrams: 2500,

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
  }
}
