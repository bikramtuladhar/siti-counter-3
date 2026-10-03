import { describe, it } from 'node:test'
import assert from 'node:assert'
import {
  AllergenCatalog,
  getAllergensForIngredient,
  checkRecipeSafety,
  getSafeSubstitutions,
  filterRecipesForAutoPlan,
  MemberAllergyProfile,
} from './allergen_engine.js'

describe('TypeScript AllergenEngine - Catalog & Hidden Sources', () => {
  it('detects hidden gluten in compounded hing (asafoetida)', () => {
    const allergens = getAllergensForIngredient('hing')
    assert.strictEqual(allergens.length > 0, true)
    const hiddenGluten = allergens.find(
      (a) => a.allergen === AllergenCatalog.gluten && a.isHidden === true
    )
    assert.ok(hiddenGluten, 'Hing must have hidden gluten source recorded')
  })

  it('detects hidden dairy in ghee (clarified butter)', () => {
    const allergens = getAllergensForIngredient('ghee')
    assert.strictEqual(allergens.length > 0, true)
    const hiddenDairy = allergens.find(
      (a) => a.allergen === AllergenCatalog.milk && a.isHidden === true
    )
    assert.ok(hiddenDairy, 'Ghee must have hidden dairy source recorded')
  })

  it('detects soy and hidden gluten in soy sauce', () => {
    const allergens = getAllergensForIngredient('soy_sauce')
    assert.ok(allergens.some((a) => a.allergen === AllergenCatalog.soy))
    assert.ok(
      allergens.some(
        (a) => a.allergen === AllergenCatalog.gluten && a.isHidden === true
      )
    )
  })

  it('detects regional allergens: buckwheat, mustard oil, fenugreek', () => {
    const fapar = getAllergensForIngredient('fapar')
    assert.ok(fapar.some((a) => a.allergen === AllergenCatalog.buckwheat))

    const tori = getAllergensForIngredient('tori_ko_tel')
    assert.ok(tori.some((a) => a.allergen === AllergenCatalog.mustard))
    assert.ok(tori.some((a) => a.allergen === AllergenCatalog.mustardOil))

    const methi = getAllergensForIngredient('methi')
    assert.ok(methi.some((a) => a.allergen === AllergenCatalog.fenugreek))
  })
})

describe('Gate 2: TypeScript Zero-Miss Test Suite for Severe Allergens', () => {
  it('Zero false negatives: Peanut allergy strictly blocks peanuts, peanut butter, badam', () => {
    const allergyProfiles: MemberAllergyProfile[] = [
      {
        allergen: AllergenCatalog.peanuts,
        severity: 'severe',
        memberName: 'Bikram',
      },
    ]

    // Safe recipe
    const safeVerdict = checkRecipeSafety({
      ingredientIds: ['rice', 'lentils', 'spinach', 'turmeric'],
      allergyProfiles,
    })
    assert.strictEqual(safeVerdict.isSafe, true)
    assert.strictEqual(safeVerdict.isAllowedInAutoPlan, true)
    assert.strictEqual(safeVerdict.conflicts.length, 0)

    // Recipe with peanuts
    const peanutVerdict = checkRecipeSafety({
      ingredientIds: ['chickpeas', 'badam', 'onion'],
      allergyProfiles,
    })
    assert.strictEqual(peanutVerdict.isSafe, false)
    assert.strictEqual(peanutVerdict.isAllowedInAutoPlan, false)
    assert.strictEqual(peanutVerdict.hasSevereConflict, true)
    assert.ok(
      peanutVerdict.conflicts.some((c) => c.allergen === AllergenCatalog.peanuts)
    )

    // Recipe with peanut butter
    const pbVerdict = checkRecipeSafety({
      ingredientIds: ['toast', 'peanut_butter'],
      allergyProfiles,
    })
    assert.strictEqual(pbVerdict.isSafe, false)
    assert.strictEqual(pbVerdict.isAllowedInAutoPlan, false)
    assert.strictEqual(pbVerdict.hasSevereConflict, true)
  })

  it('Zero false negatives: Severe Gluten allergy catches hidden hing and soy sauce', () => {
    const glutenProfiles: MemberAllergyProfile[] = [
      {
        allergen: AllergenCatalog.gluten,
        severity: 'severe',
        memberName: 'Aayush',
      },
    ]

    // Recipe with hing (common Nepali dal tadka)
    const dalTadkaVerdict = checkRecipeSafety({
      ingredientIds: ['musuro_dal', 'tomato', 'cumin', 'hing'],
      allergyProfiles: glutenProfiles,
    })
    assert.strictEqual(dalTadkaVerdict.isSafe, false)
    assert.strictEqual(dalTadkaVerdict.isAllowedInAutoPlan, false)
    assert.strictEqual(dalTadkaVerdict.hasSevereConflict, true)
    assert.strictEqual(dalTadkaVerdict.hasHiddenAllergens, true)
    assert.ok(
      dalTadkaVerdict.conflicts.some(
        (c) => c.ingredientId === 'hing' && c.isHiddenSource === true
      )
    )
  })

  it('Zero false negatives: Severe Dairy allergy catches hidden ghee and paneer', () => {
    const dairyProfiles: MemberAllergyProfile[] = [
      {
        allergen: AllergenCatalog.milk,
        severity: 'severe',
        memberName: 'Sita',
      },
    ]

    const khichdiVerdict = checkRecipeSafety({
      ingredientIds: ['rice', 'mung_dal', 'ghee', 'salt'],
      allergyProfiles: dairyProfiles,
    })
    assert.strictEqual(khichdiVerdict.isSafe, false)
    assert.strictEqual(khichdiVerdict.isAllowedInAutoPlan, false)
    assert.strictEqual(khichdiVerdict.hasSevereConflict, true)
    assert.strictEqual(khichdiVerdict.hasHiddenAllergens, true)
  })
})

describe('TypeScript Dietary Rules Enforcement', () => {
  it('Vegetarian rule blocks meat, poultry, and fish', () => {
    const vegVerdict = checkRecipeSafety({
      ingredientIds: ['khasi_ko_masu', 'onion', 'ginger', 'oil'],
      allergyProfiles: [],
      dietaryRules: ['vegetarian'],
    })
    assert.strictEqual(vegVerdict.isSafe, false)
    assert.strictEqual(vegVerdict.isAllowedInAutoPlan, false)
    assert.ok(vegVerdict.conflicts.some((c) => c.isDietaryViolation))
  })

  it('Vegan rule blocks meat and dairy products including ghee', () => {
    const veganVerdict = checkRecipeSafety({
      ingredientIds: ['rice', 'spinach', 'ghee'],
      allergyProfiles: [],
      dietaryRules: ['vegan'],
    })
    assert.strictEqual(veganVerdict.isSafe, false)
    assert.strictEqual(veganVerdict.isAllowedInAutoPlan, false)
    assert.ok(
      veganVerdict.conflicts.some(
        (c) => c.ingredientId === 'ghee' && c.isDietaryViolation
      )
    )
  })

  it('Jain vegetarian rule strictly blocks root vegetables (potato, onion, garlic)', () => {
    const jainVerdict = checkRecipeSafety({
      ingredientIds: ['potato', 'cauliflower', 'tomato', 'cumin'],
      allergyProfiles: [],
      dietaryRules: ['jainVegetarian'],
    })
    assert.strictEqual(jainVerdict.isSafe, false)
    assert.strictEqual(jainVerdict.isAllowedInAutoPlan, false)
  })

  it('Hindu fasting (Vrata/Ekadashi) blocks grains and pulses, permits potato and buckwheat', () => {
    const forbiddenVerdict = checkRecipeSafety({
      ingredientIds: ['rice', 'musuro_dal', 'ghee'],
      allergyProfiles: [],
      dietaryRules: ['hinduFasting'],
    })
    assert.strictEqual(forbiddenVerdict.isSafe, false)
    assert.strictEqual(forbiddenVerdict.isAllowedInAutoPlan, false)

    const fastingPancakeVerdict = checkRecipeSafety({
      ingredientIds: ['buckwheat_flour', 'potato', 'ghee', 'rock_salt'],
      allergyProfiles: [],
      dietaryRules: ['hinduFasting'],
    })
    assert.strictEqual(fastingPancakeVerdict.isSafe, true)
    assert.strictEqual(fastingPancakeVerdict.isAllowedInAutoPlan, true)
  })
})

describe('TypeScript Safe Substitutions Engine', () => {
  it('suggests pure resin or ginger-cumin blend for hing', () => {
    const subs = getSafeSubstitutions('hing', [
      { allergen: AllergenCatalog.gluten, severity: 'severe' },
    ])
    assert.strictEqual(subs.length > 0, true)
    assert.ok(subs.some((s) => s.ingredientId === 'pure_hing_resin'))
    assert.ok(subs.some((s) => s.ingredientId === 'ginger_cumin_mix'))
  })

  it('suggests sunflower seed butter for peanut butter', () => {
    const subs = getSafeSubstitutions('peanut_butter', [
      { allergen: AllergenCatalog.peanuts, severity: 'severe' },
    ])
    assert.strictEqual(subs.length > 0, true)
    assert.ok(subs.some((s) => s.ingredientId === 'sunflower_seed_butter'))
  })

  it('avoids suggesting substitutes that introduce an active allergen', () => {
    const subs = getSafeSubstitutions('ghee', [
      { allergen: AllergenCatalog.milk, severity: 'severe' },
      { allergen: AllergenCatalog.mustard, severity: 'severe' },
    ])
    // Mustard oil must NOT be suggested because member is mustard-allergic
    assert.strictEqual(
      subs.some((s) => s.ingredientId === 'mustard_oil'),
      false
    )
    assert.ok(subs.some((s) => s.ingredientId === 'sunflower_oil'))
  })
})

describe('TypeScript Deterministic Auto-Plan Recipe Filter', () => {
  it('strictly removes recipes with severe conflicts from auto-plan list', () => {
    const recipes = [
      { id: 'dal_bhat', ingredients: ['rice', 'musuro_dal', 'ghee'] },
      { id: 'peanut_chutney', ingredients: ['peanuts', 'tomato', 'chili'] },
      { id: 'fapar_roti', ingredients: ['buckwheat_flour', 'water', 'salt'] },
      { id: 'steamed_veggies', ingredients: ['carrot', 'cauliflower', 'salt'] },
    ]

    const filtered = filterRecipesForAutoPlan({
      recipes,
      getIngredients: (r) => r.ingredients,
      allergyProfiles: [
        { allergen: AllergenCatalog.peanuts, severity: 'severe' },
        { allergen: AllergenCatalog.milk, severity: 'severe' },
      ],
    })

    const remainingIds = filtered.map((r) => r.id)
    assert.strictEqual(remainingIds.includes('peanut_chutney'), false)
    assert.strictEqual(remainingIds.includes('dal_bhat'), false)
    assert.ok(remainingIds.includes('fapar_roti'))
    assert.ok(remainingIds.includes('steamed_veggies'))
  })
})
