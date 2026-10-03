/**
 * Common standard and regional allergen identifiers.
 */
export const AllergenCatalog = {
  // EU 14 Allergens
  celery: 'celery',
  gluten: 'gluten', // Cereals containing gluten (wheat, barley, rye, oats)
  crustaceans: 'crustaceans',
  eggs: 'eggs',
  fish: 'fish',
  lupin: 'lupin',
  milk: 'dairy', // Dairy / Milk
  molluscs: 'molluscs',
  mustard: 'mustard',
  nuts: 'nuts', // Tree nuts
  peanuts: 'peanuts',
  sesame: 'sesame',
  soy: 'soy',
  sulphites: 'sulphites',

  // Regional & South Asian / Himalayan Allergens
  buckwheat: 'buckwheat', // फापर (Fapar) - common Himalayan allergen
  mustardOil: 'mustard_oil', // तोरीको तेल (pungent erucic acid & mustard protein)
  fenugreek: 'fenugreek', // मेथी (Methi) - cross-reactive with peanut allergies
} as const

export type AllergenType = (typeof AllergenCatalog)[keyof typeof AllergenCatalog]

export type AllergySeverity = 'severe' | 'moderate' | 'mild'

export type DietaryRule =
  | 'vegetarian'
  | 'vegan'
  | 'lactoVegetarian'
  | 'jainVegetarian'
  | 'halal'
  | 'kosher'
  | 'hinduFasting'

export interface MemberAllergyProfile {
  allergen: string
  severity: AllergySeverity
  memberName?: string
}

export interface AllergenSourceInfo {
  allergen: string
  isHidden?: boolean
  explanation?: string
}

export interface SafeSubstitution {
  ingredientId: string
  nameEn: string
  nameNe: string
  notesEn: string
  notesNe: string
  allergens?: string[]
}

export interface SafetyConflict {
  ingredientId: string
  ingredientName: string
  allergen?: string
  severity?: AllergySeverity
  isDietaryViolation?: boolean
  dietaryRule?: DietaryRule
  isHiddenSource?: boolean
  reason: string
  suggestedSubstitutions: SafeSubstitution[]
}

export interface RecipeSafetyVerdict {
  isSafe: boolean
  isAllowedInAutoPlan: boolean
  hasSevereConflict: boolean
  hasHiddenAllergens: boolean
  conflicts: SafetyConflict[]
  primaryWarning?: string
}

export const INGREDIENT_ALLERGENS: Record<string, AllergenSourceInfo[]> = {
  // Hidden sources (Critical Safety P0)
  hing: [
    {
      allergen: AllergenCatalog.gluten,
      isHidden: true,
      explanation:
        'Commercial compounded asafoetida (hing) typically contains wheat/maida flour as an anti-caking carrier.',
    },
  ],
  asafoetida: [
    {
      allergen: AllergenCatalog.gluten,
      isHidden: true,
      explanation:
        'Commercial compounded asafoetida (hing) typically contains wheat/maida flour as an anti-caking carrier.',
    },
  ],
  ghee: [
    {
      allergen: AllergenCatalog.milk,
      isHidden: true,
      explanation:
        'Clarified butter (ghee) is derived from cow or buffalo milk and contains trace dairy proteins (casein/whey).',
    },
  ],
  clarified_butter: [
    {
      allergen: AllergenCatalog.milk,
      isHidden: true,
      explanation: 'Clarified butter is a dairy product containing trace milk proteins.',
    },
  ],
  soy_sauce: [
    { allergen: AllergenCatalog.soy, isHidden: false },
    {
      allergen: AllergenCatalog.gluten,
      isHidden: true,
      explanation: 'Traditional brewed soy sauce is fermented with wheat mash.',
    },
  ],

  // Mustard & Mustard Oil
  mustard_oil: [
    { allergen: AllergenCatalog.mustard },
    { allergen: AllergenCatalog.mustardOil },
  ],
  mustard_seeds: [{ allergen: AllergenCatalog.mustard }],
  tori_ko_tel: [
    { allergen: AllergenCatalog.mustard },
    { allergen: AllergenCatalog.mustardOil },
  ],

  // Buckwheat (Fapar)
  buckwheat: [{ allergen: AllergenCatalog.buckwheat }],
  buckwheat_flour: [{ allergen: AllergenCatalog.buckwheat }],
  fapar: [{ allergen: AllergenCatalog.buckwheat }],
  fapar_pitho: [{ allergen: AllergenCatalog.buckwheat }],

  // Fenugreek (Methi)
  fenugreek: [
    {
      allergen: AllergenCatalog.fenugreek,
      explanation: 'Fenugreek seeds cross-react with peanut allergies.',
    },
  ],
  methi: [
    {
      allergen: AllergenCatalog.fenugreek,
      explanation: 'Fenugreek seeds cross-react with peanut allergies.',
    },
  ],

  // Peanuts
  peanut: [{ allergen: AllergenCatalog.peanuts }],
  peanuts: [{ allergen: AllergenCatalog.peanuts }],
  peanut_butter: [{ allergen: AllergenCatalog.peanuts }],
  badam: [{ allergen: AllergenCatalog.peanuts }],

  // Tree nuts
  cashew: [{ allergen: AllergenCatalog.nuts }],
  cashews: [{ allergen: AllergenCatalog.nuts }],
  kaju: [{ allergen: AllergenCatalog.nuts }],
  walnut: [{ allergen: AllergenCatalog.nuts }],
  walnuts: [{ allergen: AllergenCatalog.nuts }],
  okhar: [{ allergen: AllergenCatalog.nuts }],
  almond: [{ allergen: AllergenCatalog.nuts }],
  almonds: [{ allergen: AllergenCatalog.nuts }],
  pistachio: [{ allergen: AllergenCatalog.nuts }],
  pista: [{ allergen: AllergenCatalog.nuts }],

  // Dairy
  milk: [{ allergen: AllergenCatalog.milk }],
  dudh: [{ allergen: AllergenCatalog.milk }],
  paneer: [{ allergen: AllergenCatalog.milk }],
  curd: [{ allergen: AllergenCatalog.milk }],
  dahi: [{ allergen: AllergenCatalog.milk }],
  yogurt: [{ allergen: AllergenCatalog.milk }],
  butter: [{ allergen: AllergenCatalog.milk }],
  makhan: [{ allergen: AllergenCatalog.milk }],
  chhurpi: [{ allergen: AllergenCatalog.milk }],

  // Sesame
  sesame: [{ allergen: AllergenCatalog.sesame }],
  sesame_seeds: [{ allergen: AllergenCatalog.sesame }],
  til: [{ allergen: AllergenCatalog.sesame }],
  tahini: [{ allergen: AllergenCatalog.sesame }],

  // Gluten
  wheat_flour: [{ allergen: AllergenCatalog.gluten }],
  atta: [{ allergen: AllergenCatalog.gluten }],
  maida: [{ allergen: AllergenCatalog.gluten }],
  suji: [{ allergen: AllergenCatalog.gluten }],
  semolina: [{ allergen: AllergenCatalog.gluten }],
  barley: [{ allergen: AllergenCatalog.gluten }],
  jau: [{ allergen: AllergenCatalog.gluten }],
  oats: [{ allergen: AllergenCatalog.gluten }],

  // Soy
  tofu: [{ allergen: AllergenCatalog.soy }],
  soybean: [{ allergen: AllergenCatalog.soy }],
  bhatmas: [{ allergen: AllergenCatalog.soy }],

  // Eggs & Seafood
  egg: [{ allergen: AllergenCatalog.eggs }],
  eggs: [{ allergen: AllergenCatalog.eggs }],
  anda: [{ allergen: AllergenCatalog.eggs }],
  fish: [{ allergen: AllergenCatalog.fish }],
  machha: [{ allergen: AllergenCatalog.fish }],
  prawn: [{ allergen: AllergenCatalog.crustaceans }],
  shrimp: [{ allergen: AllergenCatalog.crustaceans }],
}

export const SUBSTITUTION_CATALOG: Record<string, SafeSubstitution[]> = {
  hing: [
    {
      ingredientId: 'pure_hing_resin',
      nameEn: 'Pure Compounded-Free Asafoetida Resin',
      nameNe: 'शुद्ध हिङ (गहुँरहित)',
      notesEn: '100% pure raw resin dissolved in hot water or ghee; contains zero wheat starch.',
      notesNe: 'गहुँको पिठो नमिसिएको शुद्ध प्राकृतिक हिङ।',
    },
    {
      ingredientId: 'ginger_cumin_mix',
      nameEn: 'Fresh Ginger + Cumin Seed Blend',
      nameNe: 'अदुवा र जिराको धुलो',
      notesEn: 'Mimics the digestive and sulfurous warmth of hing without any gluten.',
      notesNe: 'पाचन सहयोगी र हिङको जस्तै स्वाद दिने सुरक्षित विकल्प।',
    },
  ],
  ghee: [
    {
      ingredientId: 'mustard_oil',
      nameEn: 'Cold-Pressed Mustard Oil',
      nameNe: 'तोरीको तेल',
      notesEn: 'Authentic Nepali high-smoke point cooking oil, 100% dairy-free.',
      notesNe: 'डेयरी-रहित शुद्ध परम्परागत नेपाली तेल।',
      allergens: [AllergenCatalog.mustard, AllergenCatalog.mustardOil],
    },
    {
      ingredientId: 'sunflower_oil',
      nameEn: 'Refined Sunflower Oil',
      nameNe: 'सूर्यमुखी तेल',
      notesEn: 'Neutral taste, completely free of dairy and mustard allergens.',
      notesNe: 'कुनै पनि एलर्जी नभएको तटस्थ तेल।',
    },
  ],
  mustard_oil: [
    {
      ingredientId: 'sunflower_oil',
      nameEn: 'Sunflower Oil',
      nameNe: 'सूर्यमुखी तेल',
      notesEn: 'Safe alternative for mustard allergy.',
      notesNe: 'तोरीको एलर्जी भएकाहरूका लागि सुरक्षित।',
    },
  ],
  peanut_butter: [
    {
      ingredientId: 'sunflower_seed_butter',
      nameEn: 'Sunflower Seed Butter (SunButter)',
      nameNe: 'सूर्यमुखी दानाको बटर',
      notesEn: 'Nut-free, peanut-free creamy substitute with rich roasted flavor.',
      notesNe: 'बदाम एलर्जी नहुने सुरक्षित विकल्प।',
    },
  ],
  paneer: [
    {
      ingredientId: 'firm_tofu',
      nameEn: 'Firm Tofu',
      nameNe: 'टोफु (भटमास पनिर)',
      notesEn: '100% plant-based dairy-free protein cube.',
      notesNe: 'डेयरी-रहित भटमासबाट बनेको पनिर।',
      allergens: [AllergenCatalog.soy],
    },
    {
      ingredientId: 'chickpea_paneer',
      nameEn: 'Chickpea Flour Tofu (Shan Tofu)',
      nameNe: 'चनाको पनिर (शान टोफु)',
      notesEn: 'Dairy-free, soy-free protein made from besan (gram flour).',
      notesNe: 'डेयरी र भटमास दुवै नभएको चनाको पिठोबाट बन्ने प्रोटिन।',
    },
  ],
  soy_sauce: [
    {
      ingredientId: 'coconut_aminos',
      nameEn: 'Coconut Aminos',
      nameNe: 'नरिवल अमिनोज',
      notesEn: 'Naturally soy-free, gluten-free savory seasoning.',
      notesNe: 'भटमास र ग्लुटेन दुवै नभएको प्राकृतिक सस।',
    },
  ],
  wheat_flour: [
    {
      ingredientId: 'rice_flour',
      nameEn: 'Rice Flour',
      nameNe: 'चामलको पिठो',
      notesEn: 'Gluten-free traditional flour.',
      notesNe: 'ग्लुटेन-रहित चामलको पिठो।',
    },
    {
      ingredientId: 'millet_flour',
      nameEn: 'Finger Millet Flour (Kodo)',
      nameNe: 'कोदोको पिठो',
      notesEn: 'Nutrient-rich, gluten-free ancient grain.',
      notesNe: 'ग्लुटेन-रहित पौष्टिक कोदोको पिठो।',
    },
  ],
  onion: [
    {
      ingredientId: 'cabbage_ginger',
      nameEn: 'Finely Chopped Cabbage + Fresh Ginger',
      nameNe: 'मसिनो बन्दा र अदुवा',
      notesEn: 'Provides texture and aroma for Jain and Vrata fasting dishes.',
      notesNe: 'जैन तथा व्रतका लागि प्याजको सुरक्षित विकल्प।',
    },
  ],
  garlic: [
    {
      ingredientId: 'pure_hing',
      nameEn: 'Pure Gluten-Free Hing Pinch',
      nameNe: 'शुद्ध हिङको थोरै धुलो',
      notesEn: 'Gives pungent allium depth without onion or garlic bulbs.',
      notesNe: 'लसुन-प्याज बिना स्वाद दिने विकल्प।',
    },
  ],
}

const MEAT_FISH_INGREDIENTS = new Set([
  'mutton',
  'khasi_ko_masu',
  'goat_meat',
  'chicken',
  'kukhura_ko_masu',
  'buff',
  'ranga_ko_masu',
  'pork',
  'sungur_ko_masu',
  'fish',
  'machha',
  'sukuti_machha',
  'sidra',
  'egg',
  'eggs',
  'anda',
  'prawn',
  'shrimp',
  'crab',
])

const ANIMAL_DAIRY_INGREDIENTS = new Set([
  'ghee',
  'clarified_butter',
  'milk',
  'dudh',
  'curd',
  'dahi',
  'yogurt',
  'paneer',
  'butter',
  'makhan',
  'chhurpi',
  'malai',
  'cream',
  'khoa',
  'khuwa',
])

const ROOT_VEGETABLES_JAIN = new Set([
  'potato',
  'alu',
  'onion',
  'pyaz',
  'garlic',
  'lasun',
  'ginger',
  'aduwa',
  'radish',
  'mula',
  'carrot',
  'gajar',
  'beetroot',
  'chukandar',
  'sweet_potato',
  'sakarkhanda',
  'taro',
  'pindalu',
  'colocasia',
])

const HINDU_FASTING_FORBIDDEN = new Set([
  'rice',
  'chamal',
  'bhat',
  'wheat_flour',
  'atta',
  'maida',
  'suji',
  'barley',
  'jau',
  'corn',
  'makai',
  'millet',
  'kodo',
  'lentils',
  'dal',
  'musuro_dal',
  'mas_ko_dal',
  'chana_dal',
  'rahar_dal',
  'soybean',
  'bhatmas',
  'onion',
  'pyaz',
  'garlic',
  'lasun',
])

export function normalizeKey(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .trim()
}

export function getAllergensForIngredient(
  ingredientId: string,
  declaredAllergens: string[] = []
): AllergenSourceInfo[] {
  const normalized = normalizeKey(ingredientId)
  const results: AllergenSourceInfo[] = []
  const seen = new Set<string>()

  if (INGREDIENT_ALLERGENS[normalized]) {
    for (const info of INGREDIENT_ALLERGENS[normalized]) {
      if (!seen.has(info.allergen)) {
        seen.add(info.allergen)
        results.push(info)
      }
    }
  }

  for (const allergen of declaredAllergens) {
    const norm = allergen.toLowerCase().trim()
    if (!seen.has(norm)) {
      seen.add(norm)
      results.push({ allergen: norm, isHidden: false })
    }
  }

  return results
}

function checkDietaryViolation(
  normId: string,
  rawName: string,
  rule: DietaryRule
): string | null {
  switch (rule) {
    case 'vegetarian':
    case 'lactoVegetarian':
      if (MEAT_FISH_INGREDIENTS.has(normId)) {
        return `${rawName} is meat, fish, or poultry, violating vegetarian diet.`
      }
      break

    case 'vegan':
      if (MEAT_FISH_INGREDIENTS.has(normId)) {
        return `${rawName} is an animal product, violating vegan diet.`
      }
      if (ANIMAL_DAIRY_INGREDIENTS.has(normId)) {
        return `${rawName} is an animal dairy product, violating vegan diet.`
      }
      break

    case 'jainVegetarian':
      if (MEAT_FISH_INGREDIENTS.has(normId)) {
        return `${rawName} violates Jain vegetarian diet.`
      }
      if (ROOT_VEGETABLES_JAIN.has(normId)) {
        return `${rawName} is an underground root vegetable, strictly prohibited in Jain diet.`
      }
      break

    case 'halal':
      if (
        normId.includes('pork') ||
        normId.includes('sungur') ||
        normId.includes('alcohol') ||
        normId.includes('wine')
      ) {
        return `${rawName} violates Halal dietary rules.`
      }
      break

    case 'kosher':
      if (
        normId.includes('pork') ||
        normId.includes('shellfish') ||
        normId.includes('prawn') ||
        normId.includes('crab')
      ) {
        return `${rawName} violates Kosher dietary rules.`
      }
      break

    case 'hinduFasting':
      if (MEAT_FISH_INGREDIENTS.has(normId)) {
        return `${rawName} is not permitted during Vrata / Ekadashi fasting.`
      }
      if (HINDU_FASTING_FORBIDDEN.has(normId)) {
        return `${rawName} is a forbidden grain, pulse, or allium during Hindu fasting.`
      }
      break
  }
  return null
}

export function getSafeSubstitutions(
  ingredientId: string,
  memberAllergies: MemberAllergyProfile[],
  dietaryRules: DietaryRule[] = []
): SafeSubstitution[] {
  const normId = normalizeKey(ingredientId)
  const candidates = SUBSTITUTION_CATALOG[normId] ?? []
  const activeAllergenSet = new Set(
    memberAllergies.map((p) => p.allergen.toLowerCase().trim())
  )

  const safeList: SafeSubstitution[] = []

  for (const candidate of candidates) {
    const candidateAllergens = (candidate.allergens ?? []).map((a) =>
      a.toLowerCase().trim()
    )
    if (candidateAllergens.some((a) => activeAllergenSet.has(a))) {
      continue
    }

    let violatesDiet = false
    for (const rule of dietaryRules) {
      if (
        checkDietaryViolation(candidate.ingredientId, candidate.nameEn, rule) !==
        null
      ) {
        violatesDiet = true
        break
      }
    }

    if (!violatesDiet) {
      safeList.push(candidate)
    }
  }

  return safeList
}

export function checkRecipeSafety({
  ingredientIds,
  declaredIngredientAllergens,
  allergyProfiles,
  dietaryRules = [],
}: {
  ingredientIds: string[]
  declaredIngredientAllergens?: Record<string, string[]>
  allergyProfiles: MemberAllergyProfile[]
  dietaryRules?: DietaryRule[]
}): RecipeSafetyVerdict {
  const conflicts: SafetyConflict[] = []
  let hasSevere = false
  let hasHidden = false

  const memberAllergies = new Map<string, MemberAllergyProfile>()
  for (const profile of allergyProfiles) {
    memberAllergies.set(profile.allergen.toLowerCase().trim(), profile)
  }

  for (const rawIngredient of ingredientIds) {
    const normId = normalizeKey(rawIngredient)
    const declared =
      declaredIngredientAllergens?.[rawIngredient] ??
      declaredIngredientAllergens?.[normId] ??
      []

    const allergenSources = getAllergensForIngredient(normId, declared)

    // Check Allergen Conflicts
    for (const source of allergenSources) {
      if (memberAllergies.has(source.allergen)) {
        const profile = memberAllergies.get(source.allergen)!
        const isSevere = profile.severity === 'severe'
        if (isSevere) {
          hasSevere = true
        }
        if (source.isHidden) {
          hasHidden = true
        }

        const memberDesc = profile.memberName
          ? ` for ${profile.memberName}`
          : ''
        const hiddenPrefix = source.isHidden ? '[HIDDEN ALLERGEN] ' : ''
        const reason = `${hiddenPrefix}${rawIngredient} contains ${source.allergen}${memberDesc}.${
          source.explanation ? ` ${source.explanation}` : ''
        }`

        conflicts.push({
          ingredientId: rawIngredient,
          ingredientName: rawIngredient,
          allergen: source.allergen,
          severity: profile.severity,
          isHiddenSource: source.isHidden,
          reason,
          suggestedSubstitutions: getSafeSubstitutions(
            normId,
            allergyProfiles,
            dietaryRules
          ),
        })
      }
    }

    // Check Dietary Rule Violations
    for (const rule of dietaryRules) {
      const violationReason = checkDietaryViolation(normId, rawIngredient, rule)
      if (violationReason !== null) {
        hasSevere = true
        conflicts.push({
          ingredientId: rawIngredient,
          ingredientName: rawIngredient,
          isDietaryViolation: true,
          dietaryRule: rule,
          reason: violationReason,
          suggestedSubstitutions: getSafeSubstitutions(
            normId,
            allergyProfiles,
            dietaryRules
          ),
        })
      }
    }
  }

  const isSafe = conflicts.length === 0
  const isAllowedInAutoPlan = !hasSevere

  let primaryWarning: string | undefined
  if (hasSevere) {
    primaryWarning =
      '🚨 DANGER: Contains severe allergens or dietary violations. Auto-planning blocked.'
  } else if (conflicts.length > 0) {
    primaryWarning =
      '⚠️ Warning: Contains mild or moderate allergens. Review safe substitutions.'
  }

  return {
    isSafe,
    isAllowedInAutoPlan,
    hasSevereConflict: hasSevere,
    hasHiddenAllergens: hasHidden,
    conflicts,
    primaryWarning,
  }
}

export function filterRecipesForAutoPlan<T>({
  recipes,
  getIngredients,
  declaredIngredientAllergens,
  allergyProfiles,
  dietaryRules = [],
}: {
  recipes: T[]
  getIngredients: (recipe: T) => string[]
  declaredIngredientAllergens?: Record<string, string[]>
  allergyProfiles: MemberAllergyProfile[]
  dietaryRules?: DietaryRule[]
}): T[] {
  return recipes.filter((recipe) => {
    const ingredients = getIngredients(recipe)
    const verdict = checkRecipeSafety({
      ingredientIds: ingredients,
      declaredIngredientAllergens,
      allergyProfiles,
      dietaryRules,
    })
    return verdict.isAllowedInAutoPlan
  })
}
