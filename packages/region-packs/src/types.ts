export interface RegionPackManifest {
  id: string;
  version: string;
  name: string;
  country: string;
  countryCode: string;
  region: string;
  status: 'draft' | 'community' | 'verified';
  elevationMeters: number;
  currency: {
    code: string;
    symbol: string;
    numberFormat: 'lakh-crore' | 'western';
  };
  languages: string[];
  defaultLanguage: string;
  calendar: 'bikram-sambat' | 'gregorian';
  seasonSystem: 'six-ritus' | 'four-seasons';
  units: {
    market: string[];
    standard: 'metric' | 'imperial';
  };
  defaultMealRhythm: Array<{
    id: string;
    name: string;
    time: string;
  }>;
}

export type RituAvailability = 'peak' | 'in_season' | 'available' | 'limited' | 'out_of_season';

export interface Ingredient {
  id: string;
  nameEn: string;
  nameNe: string;
  aliases: string[];
  category: 'vegetables' | 'greens' | 'pulses' | 'grains' | 'flour' | 'aromatics' | 'spices' | 'oils' | 'dairy' | 'meat' | 'fruits' | 'fermented' | 'seeds' | 'sweeteners';
  standardUnit: string;
  marketPackageGrams: number;
  storageDays: number;
  allergens: string[];
  availability: Record<string, RituAvailability>;
}

export interface RecipeStep {
  stepNumber: number;
  instructionEn: string;
  instructionNe: string;
  timerMinutes?: number;
  whistles?: number;
}

export interface PressureCookerProfile {
  enabled: boolean;
  recommendedWhistles: number;
  altitudeWhistleOffsetKathmandu: number;
  heatLevel: 'low' | 'medium' | 'high';
  releaseType: 'natural' | 'quick';
}

export interface Recipe {
  id: string;
  titleEn: string;
  titleNe: string;
  category: 'dal' | 'bhat' | 'tarkari' | 'saag' | 'masu' | 'achar' | 'khaja' | 'roti_mithai' | 'soup' | 'beverage';
  cuisine: string;
  dietary: string[];
  prepTimeMinutes: number;
  cookTimeMinutes: number;
  servings: number;
  difficulty: 'easy' | 'medium' | 'hard';
  pressureCooker: PressureCookerProfile;
  elevationBand: {
    testedElevationMeters: number;
    boilingPointCelsius: number;
    waterMultiplier: number;
  };
  ingredients: Array<{
    ingredientId: string;
    quantity: number;
    unit: string;
    notes?: string;
  }>;
  steps: RecipeStep[];
  seasonality: string[];
  pairingIds?: string[];
  tags: string[];
}

export interface Festival {
  id: string;
  nameEn: string;
  nameNe: string;
  tithi: string;
  approxGregorianMonth: string;
  descriptionEn: string;
  descriptionNe: string;
  foodTraditions: {
    keyDishes: string[];
    fastingRules?: string;
    significance: string;
  };
}

export interface RituSeason {
  id: string;
  name: string;
  monthsBS: string[];
  monthsGregorian: string[];
  signatureProduce: string[];
}

export interface SeasonalityData {
  regionId: string;
  ritus: RituSeason[];
}

export interface RegionPack {
  manifest: RegionPackManifest;
  seasonality: SeasonalityData;
  ingredients: Ingredient[];
  recipes: Recipe[];
  festivals: Festival[];
}
