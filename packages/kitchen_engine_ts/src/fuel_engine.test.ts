import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  CookingFuelSession,
  LpgCylinderState,
  FuelEngine,
  PowerCutRecipeItem,
} from './fuel_engine.js';

describe('FuelEngine TypeScript Parity Tests', () => {
  it('calculates session gas consumption by flame intensity and burner count', () => {
    // 30 mins on high flame: 200 g/hr -> 100 g
    const sessionHigh = new CookingFuelSession({
      sessionId: 's-1',
      recipeName: 'Dal Bhat',
      startTime: new Date(),
      durationMinutes: 30,
      flameIntensity: 'high',
      burnerCount: 1,
    });
    assert.ok(Math.abs(sessionHigh.gasConsumedGrams - 100.0) < 0.1);

    // 60 mins on medium flame: 130 g/hr -> 130 g
    const sessionMed = new CookingFuelSession({
      sessionId: 's-2',
      recipeName: 'Khasiko Masu',
      startTime: new Date(),
      durationMinutes: 60,
      flameIntensity: 'medium',
      burnerCount: 1,
    });
    assert.ok(Math.abs(sessionMed.gasConsumedGrams - 130.0) < 0.1);

    // 30 mins on 2 burners with low flame: 70 * 2 = 140 g/hr -> 70 g
    const sessionLowTwo = new CookingFuelSession({
      sessionId: 's-3',
      recipeName: 'Tea & Snacks',
      startTime: new Date(),
      durationMinutes: 30,
      flameIntensity: 'low',
      burnerCount: 2,
    });
    assert.ok(Math.abs(sessionLowTwo.gasConsumedGrams - 70.0) < 0.1);
  });

  it('updates cylinder remaining gas and percentage correctly', () => {
    const cylinder = LpgCylinderState.newCylinder({
      type: 'standard14_2',
      brand: 'Sugam Gas',
    });

    assert.equal(cylinder.initialNetGasKg, 14.2);
    assert.equal(cylinder.remainingGasKg, 14.2);
    assert.equal(cylinder.percentageRemaining, 100);

    const updated = cylinder.recordConsumption(1000.0);
    assert.ok(Math.abs(updated.remainingGasKg - 13.2) < 0.01);
    assert.ok(Math.abs(updated.percentageRemaining - (13.2 / 14.2) * 100) < 0.1);
  });

  it('calibrates cylinder from gross scale reading', () => {
    const cylinder = LpgCylinderState.newCylinder({
      tareWeightKg: 15.3,
    });

    // Gross weight 19.3 kg -> 19.3 - 15.3 = 4.0 kg net gas
    const calibrated = cylinder.calibrateFromGrossWeight(19.3);
    assert.ok(Math.abs(calibrated.remainingGasKg - 4.0) < 0.01);
  });

  it('predicts depletion and handles refill urgency thresholds', () => {
    // Normal level: 10 kg
    const cylNormal = new LpgCylinderState({
      id: 'c-1',
      installationDate: new Date(),
      initialNetGasKg: 14.2,
      remainingGasKg: 10.0,
      tareWeightKg: 15.3,
    });
    const forecastNormal = FuelEngine.predictDepletion({ cylinder: cylNormal });
    assert.equal(forecastNormal.urgency, 'normal');
    assert.equal(forecastNormal.isRefillNeeded, false);

    // Order soon level: 1.0 kg remaining (~3.57 days)
    const cylOrderSoon = new LpgCylinderState({
      id: 'c-2',
      installationDate: new Date(),
      initialNetGasKg: 14.2,
      remainingGasKg: 1.0,
      tareWeightKg: 15.3,
    });
    const forecastOrderSoon = FuelEngine.predictDepletion({ cylinder: cylOrderSoon });
    assert.equal(forecastOrderSoon.urgency, 'order_soon');
    assert.equal(forecastOrderSoon.isRefillNeeded, true);
    assert.ok(forecastOrderSoon.refillAlertMessageEn.includes('Refill Reminder'));
    assert.ok(forecastOrderSoon.refillAlertMessageNe.includes('रिफिल रिमाइन्डर'));

    // Critical level: 0.35 kg (~1.25 days)
    const cylCritical = new LpgCylinderState({
      id: 'c-3',
      installationDate: new Date(),
      initialNetGasKg: 14.2,
      remainingGasKg: 0.35,
      tareWeightKg: 15.3,
    });
    const forecastCritical = FuelEngine.predictDepletion({ cylinder: cylCritical });
    assert.equal(forecastCritical.urgency, 'critical');
    assert.equal(forecastCritical.isRefillNeeded, true);

    // Empty level: 0.0 kg
    const cylEmpty = new LpgCylinderState({
      id: 'c-4',
      installationDate: new Date(),
      initialNetGasKg: 14.2,
      remainingGasKg: 0.0,
      tareWeightKg: 15.3,
    });
    const forecastEmpty = FuelEngine.predictDepletion({ cylinder: cylEmpty });
    assert.equal(forecastEmpty.urgency, 'empty');
    assert.equal(forecastEmpty.isRefillNeeded, true);
  });

  it('filters recipes for power-cut and gas-saving modes', () => {
    const recipes: PowerCutRecipeItem[] = [
      { id: '1', nameEn: 'Chiura Dahi', nameNe: 'चिउरा दही', powerProfile: 'no_cook', cookTimeMinutes: 5, isGasSaver: true },
      { id: '2', nameEn: 'Quick Dal', nameNe: 'दाल', powerProfile: 'gas_pressure_cooker', cookTimeMinutes: 15, isGasSaver: true },
      { id: '3', nameEn: 'Slow Meat Stew', nameNe: 'मासु', powerProfile: 'gas_pressure_cooker', cookTimeMinutes: 50, isGasSaver: false },
      { id: '4', nameEn: 'Induction Curry', nameNe: 'करी', powerProfile: 'electric_appliance', cookTimeMinutes: 20 },
    ];

    const powerCut = FuelEngine.filterForPowerCut({ recipes });
    assert.equal(powerCut.length, 3);
    assert.equal(powerCut.some((r) => r.id === '4'), false);

    const noCook = FuelEngine.filterForPowerCut({ recipes, noCookOnly: true });
    assert.equal(noCook.length, 1);
    assert.equal(noCook[0].id, '1');

    const gasSavers = FuelEngine.filterForPowerCut({ recipes, gasSaverOnly: true });
    assert.equal(gasSavers.length, 2);
    assert.deepEqual(gasSavers.map((r) => r.id), ['1', '2']);
  });
});
