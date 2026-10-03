import test from 'node:test'
import assert from 'node:assert/strict'
import { UnitConverter, MarketCalculator, AltitudeCalculator } from './index.js'

test('UnitConverter - Mass', () => {
  assert.equal(UnitConverter.pauToGrams(1), 250)
  assert.equal(UnitConverter.pauToGrams(4), 1000)
  assert.equal(UnitConverter.gramsToPau(500), 2)
  assert.equal(UnitConverter.dharniToGrams(1), 2500)
  assert.equal(UnitConverter.gramsToDharni(2500), 1)
  assert.ok(Math.abs(UnitConverter.tolaToGrams(1) - 11.66) < 0.01)
  assert.ok(Math.abs(UnitConverter.seerToGrams(1) - 933.1) < 0.1)
  assert.equal(UnitConverter.muthiToGrams(2), 100)
})

test('UnitConverter - Volume', () => {
  assert.equal(UnitConverter.manaToMl(1), 568)
  assert.equal(UnitConverter.metricCupToMl(1), 250)
  assert.equal(UnitConverter.usCupToMl(1), 240)
  assert.equal(UnitConverter.metricCupToMl(1) - UnitConverter.usCupToMl(1), 10)
  assert.equal(UnitConverter.tablespoonToMl(1), 15)
  assert.equal(UnitConverter.teaspoonToMl(1), 5)
})

test('UnitConverter - Formatting', () => {
  assert.equal(UnitConverter.formatLocalUnit(500), '2 pau')
  assert.equal(UnitConverter.formatLocalUnit(500, true), '2 पाउ')
  assert.equal(UnitConverter.formatLocalUnit(2500), '1 dharni')
  assert.equal(UnitConverter.formatLocalUnit(2500, true), '1 धार्नी')
  assert.equal(UnitConverter.formatLocalUnit(1200), '1.2 kg')
})

test('MarketCalculator', () => {
  const result = MarketCalculator.calculatePurchase({
    ingredientName: 'Tomato',
    recipeQuantityGrams: 750,
    standardPackageGrams: 1000,
    alreadyHaveGrams: 0
  })

  assert.equal(result.packagesToBuy, 1)
  assert.equal(result.totalPurchasedGrams, 1000)
  assert.equal(result.surplusGrams, 250)
  assert.ok(result.surplusSuggestion?.includes('tomato achar'))
})

test('AltitudeCalculator', () => {
  const bp = AltitudeCalculator.boilingPointCelsius(1400)
  assert.ok(Math.abs(bp - 95.0) < 0.5)
  assert.equal(AltitudeCalculator.adjustSitiCount(5, 1400), 6)
  assert.equal(AltitudeCalculator.adjustSitiCount(5, 100), 5)
})
