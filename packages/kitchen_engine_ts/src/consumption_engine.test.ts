import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import {
  ConsumptionEngine,
  HouseholdVesselProfile,
  STANDARD_VESSELS,
  MemberDietaryProfile,
  isChildOrBaby,
} from './consumption_engine.js'

describe('ConsumptionEngine TypeScript Parity Tests', () => {
  describe('Calibrated Vessels & Household Customization', () => {
    it('provides standard calibrated vessels with volume and grams', () => {
      const vessels = STANDARD_VESSELS
      assert.ok(vessels.length >= 7)

      const katori = vessels.find((v) => v.id === 'katori')
      assert.ok(katori)
      assert.equal(katori.volumeMl, 150.0)
      assert.equal(katori.standardGrams, 150.0)
      assert.equal(katori.nameEn, 'Katori (Small Bowl)')
      assert.equal(katori.nameNe, 'कचौरा / कटोरी')

      const roti = vessels.find((v) => v.id === 'roti')
      assert.ok(roti)
      assert.equal(roti.standardGrams, 40.0)
    })

    it('household calibration overrides vessel volume without affecting other vessels', () => {
      // Household customizes their steel katori to 180 ml
      const profile = new HouseholdVesselProfile({ katori: 180.0 })

      const effectiveKatori = profile.getEffectiveVessel('katori')
      assert.equal(effectiveKatori.volumeMl, 180.0)
      assert.equal(effectiveKatori.standardGrams, 180.0)
      assert.equal(effectiveKatori.isCustom, true)

      // Unmodified vessels remain at default standard
      const plate = profile.getEffectiveVessel('plate')
      assert.equal(plate.volumeMl, 400.0)
      assert.equal(plate.isCustom, undefined)
    })
  })

  describe('One-Tap Usual Meal Logging', () => {
    const members: MemberDietaryProfile[] = [
      {
        memberId: 'm1',
        name: 'Bikram',
        role: 'Adult',
        nutritionProfile: 'everyday',
        portionMultiplier: 1.0,
        preferredVesselId: 'plate',
        defaultVesselCount: 1.0,
      },
      {
        memberId: 'm2',
        name: 'Srijana',
        role: 'Adult',
        nutritionProfile: 'everyday',
        portionMultiplier: 0.8,
        preferredVesselId: 'katori',
        defaultVesselCount: 2.0,
      },
      {
        memberId: 'm3',
        name: 'Aayush',
        role: 'Child',
        nutritionProfile: 'child',
        portionMultiplier: 0.5,
        preferredVesselId: 'katori',
        defaultVesselCount: 1.0,
      },
    ]

    it('logs usual dinner with one tap confirmation', () => {
      const now = new Date('2026-10-15T19:30:00Z')
      const log = ConsumptionEngine.logUsualMeal({
        recipeId: 'dal-bhat-tarkari',
        recipeTitle: 'Dal Bhat Tarkari',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members,
        batchYieldGrams: 1600.0,
        leftoverGrams: 200.0,
      })

      assert.equal(log.recipeId, 'dal-bhat-tarkari')
      assert.equal(log.loggedAsUsual, true)
      assert.equal(log.memberPortions.length, 3)

      // Bikram: 1 plate (400g) * 1.0 = 400g
      const bikram = log.memberPortions.find((p) => p.memberId === 'm1')
      assert.ok(bikram)
      assert.equal(bikram.vesselCount, 1.0)
      assert.equal(bikram.calculatedGrams, 400.0)
      assert.equal(bikram.ateUsual, true)

      // Srijana: 2 katori (150g * 2 = 300g) * 0.8 = 240g
      const srijana = log.memberPortions.find((p) => p.memberId === 'm2')
      assert.ok(srijana)
      assert.equal(srijana.vesselCount, 2.0)
      assert.equal(srijana.calculatedGrams, 240.0)
      assert.equal(srijana.ateUsual, true)

      // Total servings = 1.0 + 0.8 + 0.5 = 2.3
      assert.ok(Math.abs(log.totalServings - 2.3) < 0.001)
    })

    it('logs adjusted meal when members eat more/less or skip', () => {
      const now = new Date('2026-10-15T19:30:00Z')
      const log = ConsumptionEngine.logAdjustedMeal({
        recipeId: 'dal-bhat-tarkari',
        recipeTitle: 'Dal Bhat Tarkari',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members,
        adjustments: {
          m1: {
            vesselId: 'plate',
            vesselCount: 1.5,
            notes: 'Second helping of bhat',
          },
          m2: {
            vesselId: 'katori',
            vesselCount: 0,
            skipped: true,
            notes: 'Ate khaja late',
          },
        },
      })

      assert.equal(log.loggedAsUsual, false)

      const bikram = log.memberPortions.find((p) => p.memberId === 'm1')
      assert.ok(bikram)
      assert.equal(bikram.vesselCount, 1.5)
      assert.equal(bikram.calculatedGrams, 600.0) // 400 * 1.5
      assert.equal(bikram.ateUsual, false)
      assert.equal(bikram.notes, 'Second helping of bhat')

      const srijana = log.memberPortions.find((p) => p.memberId === 'm2')
      assert.ok(srijana)
      assert.equal(srijana.skipped, true)
      assert.equal(srijana.calculatedGrams, 0.0)

      const child = log.memberPortions.find((p) => p.memberId === 'm3')
      assert.ok(child)
      assert.equal(child.ateUsual, true)
    })
  })

  describe('Outside Food & Weekly Non-Shaming Summary', () => {
    it('quick adds outside snacks and computes calm weekly summary', () => {
      const now = new Date('2026-10-15T12:00:00Z')
      const snack = ConsumptionEngine.quickAddOutsideFood({
        memberId: 'm1',
        memberName: 'Bikram',
        foodName: 'Buff Momo',
        mealSlot: 'afternoon-khaja',
        portionSize: 'medium',
        estimatedCalories: 380,
        consumedAt: now,
        tags: ['street-food', 'khaja'],
      })

      assert.equal(snack.foodName, 'Buff Momo')
      assert.ok(snack.tags.includes('street-food'))

      const members: MemberDietaryProfile[] = [
        {
          memberId: 'm1',
          name: 'Bikram',
          role: 'Adult',
          nutritionProfile: 'everyday',
        },
        {
          memberId: 'm3',
          name: 'Aayush',
          role: 'Child',
          nutritionProfile: 'child',
        },
      ]

      const weekStart = new Date('2026-10-11T00:00:00Z')
      const weekEnd = new Date('2026-10-17T23:59:59Z')

      const meal1 = ConsumptionEngine.logUsualMeal({
        recipeId: 'dal-bhat',
        recipeTitle: 'Dal Bhat',
        mealSlot: 'morning-dal-bhat',
        consumedAt: now,
        members,
      })

      const meal2 = ConsumptionEngine.logUsualMeal({
        recipeId: 'aloo-gobi',
        recipeTitle: 'Aloo Gobi',
        mealSlot: 'evening-dal-bhat',
        consumedAt: new Date('2026-10-15T18:00:00Z'),
        members,
      })

      const summary = ConsumptionEngine.calculateWeeklySummary({
        weekStart,
        weekEnd,
        mealLogs: [meal1, meal2],
        outsideLogs: [snack],
        members,
      })

      assert.equal(summary.totalMealsLogged, 2)
      assert.equal(summary.totalOutsideSnacksLogged, 1)
      assert.equal(summary.usualComplianceRate, 100.0)

      const bikramSummary = summary.memberSummaries.find((s) => s.memberId === 'm1')
      assert.ok(bikramSummary)
      assert.equal(bikramSummary.mealsLogged, 2)
      assert.equal(bikramSummary.snacksLogged, 1)
      assert.notEqual(bikramSummary.estimatedCalories, null)

      // Section 8 & 11: Children are NEVER shown calorie counts
      const childSummary = summary.memberSummaries.find((s) => s.memberId === 'm3')
      assert.ok(childSummary)
      assert.equal(childSummary.mealsLogged, 2)
      assert.equal(childSummary.estimatedCalories, null) // Protected from calorie counting!
      assert.ok(childSummary.gentleFeedback.includes('पोषण'))
    })
  })
})
