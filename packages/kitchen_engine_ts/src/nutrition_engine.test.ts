import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { NutritionEngine, PortionIntake } from './nutrition_engine.js'
import { MemberDietaryProfile } from './consumption_engine.js'

const close = (a: number, b: number) => assert.ok(Math.abs(a - b) < 1e-9, `${a} !~ ${b}`)

const adult: MemberDietaryProfile = {
  memberId: 'a',
  name: 'Asha',
  role: 'Adult',
  nutritionProfile: 'everyday',
  portionMultiplier: 1,
  preferredVesselId: 'plate',
  defaultVesselCount: 1,
}
const child: MemberDietaryProfile = {
  ...adult,
  memberId: 'c',
  name: 'Chhori',
  role: 'Child',
  nutritionProfile: 'child',
}

function dalBhat(): PortionIntake {
  const b = NutritionEngine.computeBatch([
    { ingredientId: 'rice', rawGrams: 100 },
    { ingredientId: 'lentil', rawGrams: 50 },
    { ingredientId: 'spinach', rawGrams: 100 },
  ])
  return { nutrients: b.totals, foodGroups: b.foodGroups, seasonalFraction: 0.5 }
}

describe('NutritionEngine TypeScript Parity Tests', () => {
  describe('Yield factors', () => {
    it('rice triples, spinach halves, unknown is 1.0', () => {
      assert.equal(NutritionEngine.yieldFor('rice'), 3.0)
      assert.equal(NutritionEngine.yieldFor('spinach'), 0.5)
      assert.equal(NutritionEngine.yieldFor('mystery'), 1.0)
    })
    it('cooked density = raw density / yield', () => {
      close(NutritionEngine.cookedPer100g('rice').kcal, 345 / 3)
      close(NutritionEngine.cookedPer100g('spinach').proteinG, 4.0)
    })
  })

  describe('Batch nutrition', () => {
    it('nutrients from raw weight, cooked weight from yield', () => {
      const b = NutritionEngine.computeBatch([
        { ingredientId: 'rice', rawGrams: 200 },
        { ingredientId: 'lentil', rawGrams: 100 },
      ])
      close(b.totals.grams, 200 * 3 + 100 * 2.5)
      close(b.totals.proteinG, 2 * 6.8 + 25.1)
      assert.deepEqual([...b.foodGroups].sort(), ['grains', 'pulses'])
    })
    it('weighed cooked yield overrides the estimate', () => {
      const b = NutritionEngine.computeBatch([{ ingredientId: 'rice', rawGrams: 200 }], 500)
      assert.equal(b.totals.grams, 500)
      close(b.totals.kcal, 690)
    })
    it('oil is not a food group; unknowns reported', () => {
      const b = NutritionEngine.computeBatch([
        { ingredientId: 'mustard-oil', rawGrams: 10 },
        { ingredientId: 'dragonfruit', rawGrams: 50 },
      ])
      assert.equal(b.foodGroups.length, 0)
      close(b.totals.kcal, 90)
      assert.deepEqual(b.unknownIngredients, ['dragonfruit'])
    })
    it('portion scales by cooked grams', () => {
      const b = NutritionEngine.computeBatch([{ ingredientId: 'rice', rawGrams: 100 }])
      close(NutritionEngine.portion(b, 150).kcal, 172.5)
      assert.equal(NutritionEngine.portion(b, 0).kcal, 0)
    })
  })

  describe('Member views', () => {
    it('child view: food groups only, no numbers or calories', () => {
      const v = NutritionEngine.buildMemberView(child, [dalBhat()])
      assert.equal(v.showsNumbers, false)
      assert.equal(v.estimatedKcalPerDay, null)
      assert.equal(v.bars.length, 0)
      assert.deepEqual(v.foodGroupsCovered, ['grains', 'pulses', 'vegetables'])
    })
    it('adult view: three bars within 0..1', () => {
      const v = NutritionEngine.buildMemberView(adult, Array(14).fill(dalBhat()))
      assert.deepEqual(v.bars.map((b) => b.key), ['protein', 'fiber', 'seasonal'])
      for (const b of v.bars) assert.ok(b.fraction >= 0 && b.fraction <= 1)
      close(v.bars[2].fraction, 0.5)
      assert.notEqual(v.estimatedKcalPerDay, null)
    })
    it('over-target is abundant and caps at 1', () => {
      const big: PortionIntake = {
        nutrients: { grams: 1000, kcal: 0, proteinG: 5000, fiberG: 5000, carbsG: 0, fatG: 0 },
      }
      const v = NutritionEngine.buildMemberView(adult, [big])
      assert.equal(v.bars[0].fraction, 1)
      assert.equal(v.bars[0].level, 'abundant')
    })
    it('empty intake is warming-up, not an error', () => {
      const v = NutritionEngine.buildMemberView(adult, [])
      assert.ok(v.bars.every((b) => b.level === 'warming-up'))
      assert.equal(v.estimatedKcalPerDay, null)
    })
    it('pregnancy has a higher protein target than everyday', () => {
      const intake: PortionIntake = {
        nutrients: { grams: 100, kcal: 0, proteinG: 175, fiberG: 0, carbsG: 0, fatG: 0 },
      }
      const preg = { ...adult, nutritionProfile: 'pregnancy' }
      const e = NutritionEngine.buildMemberView(adult, [intake])
      const p = NutritionEngine.buildMemberView(preg, [intake])
      assert.ok(p.bars[0].fraction < e.bars[0].fraction)
    })
  })
})
