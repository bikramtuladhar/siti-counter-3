import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  WasteEngine,
  TrackedLeftover,
  MealConsumptionLog,
  MemberDietaryProfile,
  ConsumptionEngine,
} from './index.js';

describe('WasteEngine Shelf-Life & Expiration Tests', () => {
  const now = new Date(2026, 9, 5, 12, 0, 0); // October 5, 2026, 12:00 (Month is 0-indexed in JS)

  it('refrigerated shelf-life varies by dish type', () => {
    assert.equal(
      WasteEngine.getBaseShelfLifeHours({
        dishCategory: 'dal',
        storage: 'refrigerated',
        climate: 'temperate',
      }),
      48
    );

    // Cooked rice has shorter refrigerated life due to spore-forming bacteria
    assert.equal(
      WasteEngine.getBaseShelfLifeHours({
        dishCategory: 'bhat',
        storage: 'refrigerated',
        climate: 'temperate',
      }),
      36
    );

    assert.equal(
      WasteEngine.getBaseShelfLifeHours({
        dishCategory: 'roti',
        storage: 'refrigerated',
        climate: 'temperate',
      }),
      72
    );
  });

  it('room temperature shelf-life is climate sensitive', () => {
    // Hot summer / monsoon
    assert.equal(
      WasteEngine.getBaseShelfLifeHours({
        dishCategory: 'dal',
        storage: 'roomTemperature',
        climate: 'hotSummer',
      }),
      8
    );

    // Cool winter
    assert.equal(
      WasteEngine.getBaseShelfLifeHours({
        dishCategory: 'dal',
        storage: 'roomTemperature',
        climate: 'coolWinter',
      }),
      20
    );
  });

  it('calculates correct urgency and "Eat First" status based on remaining hours', () => {
    // Prepared 2 hours ago, refrigerated (48 hrs total) -> fresh
    const fresh = WasteEngine.calculateExpiry({
      preparedAt: new Date(now.getTime() - 2 * 3600 * 1000),
      dishCategory: 'dal',
      storage: 'refrigerated',
      now,
    });
    assert.equal(fresh.urgency, 'fresh');
    assert.equal(fresh.isEatFirst, false);

    // Prepared 40 hours ago, refrigerated (8 hrs remaining) -> eatSoon
    const eatSoon = WasteEngine.calculateExpiry({
      preparedAt: new Date(now.getTime() - 40 * 3600 * 1000),
      dishCategory: 'dal',
      storage: 'refrigerated',
      now,
    });
    assert.equal(eatSoon.urgency, 'eatSoon');
    assert.equal(eatSoon.isEatFirst, true);

    // Prepared 46 hours ago, refrigerated (2 hrs remaining) -> urgent
    const urgent = WasteEngine.calculateExpiry({
      preparedAt: new Date(now.getTime() - 46 * 3600 * 1000),
      dishCategory: 'dal',
      storage: 'refrigerated',
      now,
    });
    assert.equal(urgent.urgency, 'urgent');
    assert.equal(urgent.isEatFirst, true);

    // Prepared 50 hours ago -> expired
    const expired = WasteEngine.calculateExpiry({
      preparedAt: new Date(now.getTime() - 50 * 3600 * 1000),
      dishCategory: 'dal',
      storage: 'refrigerated',
      now,
    });
    assert.equal(expired.urgency, 'expired');
    assert.equal(expired.isEatFirst, false);
  });
});

describe('Automatic Leftover Creation from Meal Logs', () => {
  const testMembers: MemberDietaryProfile[] = [
    { memberId: 'm1', name: 'Bikram', portionMultiplier: 1.0, preferredVesselId: 'plate', defaultVesselCount: 1.0 },
    { memberId: 'm2', name: 'Srijana', portionMultiplier: 0.8, preferredVesselId: 'katori', defaultVesselCount: 2.0 },
  ];

  it('creates leftover when cooked yield exceeds consumed portions', () => {
    const now = new Date(2026, 9, 5, 19, 0, 0);
    // bikram: 400g * 1.0 = 400g
    // srijana: 150g * 2 * 0.8 = 240g
    // total consumed = 640g
    // batch yield = 1200g -> excess = 560g (~2 servings)
    const log = ConsumptionEngine.logUsualMeal({
      recipeId: 'masoor-dal',
      recipeTitle: 'Masoor Dal',
      mealSlot: 'evening-dal-bhat',
      consumedAt: now.toISOString(),
      members: testMembers,
      batchYieldGrams: 1200.0,
    });

    const leftover = WasteEngine.createFromMealLog({
      log,
      now,
    });

    assert.ok(leftover);
    assert.equal(leftover.recipeId, 'masoor-dal');
    assert.equal(leftover.remainingGrams, 560.0);
    assert.equal(leftover.servingsRemaining, 2);
    assert.equal(leftover.isConsumed, false);
  });

  it('honors explicit leftoverGrams on meal log', () => {
    const now = new Date(2026, 9, 5, 19, 0, 0);
    const log = ConsumptionEngine.logUsualMeal({
      recipeId: 'tarkari',
      recipeTitle: 'Aloo Gobi Tarkari',
      mealSlot: 'evening-dal-bhat',
      consumedAt: now.toISOString(),
      members: testMembers,
      leftoverGrams: 300.0,
    });

    const leftover = WasteEngine.createFromMealLog({
      log,
      now,
    });

    assert.ok(leftover);
    assert.equal(leftover.remainingGrams, 300.0);
    assert.equal(leftover.servingsRemaining, 1);
  });

  it('ignores scraps below 50 grams', () => {
    const now = new Date(2026, 9, 5, 19, 0, 0);
    const log = ConsumptionEngine.logUsualMeal({
      recipeId: 'tarkari',
      recipeTitle: 'Tarkari',
      mealSlot: 'evening-dal-bhat',
      consumedAt: now.toISOString(),
      members: testMembers,
      leftoverGrams: 30.0, // negligible scrap
    });

    const leftover = WasteEngine.createFromMealLog({
      log,
      now,
    });

    assert.equal(leftover, null);
  });

  it('returns null when no leftovers are left', () => {
    const now = new Date(2026, 9, 5, 19, 0, 0);
    const log = ConsumptionEngine.logUsualMeal({
      recipeId: 'tarkari',
      recipeTitle: 'Tarkari',
      mealSlot: 'evening-dal-bhat',
      consumedAt: now.toISOString(),
      members: testMembers,
      leftoverGrams: 0.0,
    });

    const leftover = WasteEngine.createFromMealLog({
      log,
      now,
    });

    assert.equal(leftover, null);
  });
});

describe('Waste Insights & Recurring Pattern Analytics', () => {
  const fourMembers: MemberDietaryProfile[] = [
    { memberId: 'm1', name: 'Bikram', portionMultiplier: 1.0, preferredVesselId: 'bowl', defaultVesselCount: 1.0 },
    { memberId: 'm2', name: 'Srijana', portionMultiplier: 1.0, preferredVesselId: 'bowl', defaultVesselCount: 1.0 },
    { memberId: 'm3', name: 'Aayush', portionMultiplier: 1.0, preferredVesselId: 'bowl', defaultVesselCount: 1.0 },
    { memberId: 'm4', name: 'Guest', portionMultiplier: 1.0, preferredVesselId: 'bowl', defaultVesselCount: 1.0 },
  ];

  it('detects recurring over-portioning on specific weekdays', () => {
    // Week 1 Monday (Oct 5, 2026): Prepared 1500g (~6 servings), consumed 1000g (~4 servings), leftover 500g
    const mon1 = new Date(2026, 9, 5, 19, 30, 0);
    const log1 = ConsumptionEngine.logUsualMeal({
      recipeId: 'dal',
      recipeTitle: 'Dal',
      mealSlot: 'evening-dal-bhat',
      consumedAt: mon1.toISOString(),
      members: fourMembers,
      batchYieldGrams: 1500.0,
      leftoverGrams: 500.0,
    });

    // Week 2 Monday (Oct 12, 2026): Same recurring over-portioning
    const mon2 = new Date(2026, 9, 12, 19, 30, 0);
    const log2 = ConsumptionEngine.logUsualMeal({
      recipeId: 'dal',
      recipeTitle: 'Dal',
      mealSlot: 'evening-dal-bhat',
      consumedAt: mon2.toISOString(),
      members: fourMembers,
      batchYieldGrams: 1500.0,
      leftoverGrams: 500.0,
    });

    const insights = WasteEngine.analyzeWastePatterns([log1, log2]);

    assert.equal(insights.length, 1);
    const insight = insights[0];
    assert.equal(insight.recipeId, 'dal');
    assert.equal(insight.dayOfWeek, 1); // Monday
    assert.equal(insight.dayNameEn, 'Monday');
    assert.equal(insight.dayNameNe, 'सोमबार');
    assert.equal(insight.occurrences, 2);
    assert.equal(insight.recommendedServings, 4.0);
    assert.equal(insight.insightEn, 'Dal is often left over on Mondays; try 4 servings instead of 6.');
    assert.equal(insight.insightNe, 'सोमबार Dal प्रायः बाँकी रहने गर्छ; ६ भागको सट्टा ४ भाग पकाउनुहोस्।');
    assert.ok(insight.estimatedMonthlySavingsNpr > 0);
  });

  it('ignores isolated single instances when minimumOccurrences is 2', () => {
    const mon1 = new Date(2026, 9, 5, 19, 30, 0);
    const log1 = ConsumptionEngine.logUsualMeal({
      recipeId: 'dal',
      recipeTitle: 'Dal',
      mealSlot: 'evening-dal-bhat',
      consumedAt: mon1.toISOString(),
      members: fourMembers,
      batchYieldGrams: 1500.0,
      leftoverGrams: 500.0,
    });

    const insights = WasteEngine.analyzeWastePatterns([log1]);
    assert.equal(insights.length, 0);
  });
});

describe('Household Waste Summary & Calm Feedback', () => {
  const now = new Date(2026, 9, 5, 12, 0, 0);

  it('summarizes active, eat-first, and consumed leftovers', () => {
    const leftovers: TrackedLeftover[] = [
      // 1 active fresh
      {
        id: 'l1',
        recipeId: 'dal',
        titleEn: 'Dal',
        titleNe: 'दाल',
        servingsRemaining: 2,
        remainingGrams: 400.0,
        preparedAt: new Date(now.getTime() - 10 * 3600 * 1000),
        useByDate: new Date(now.getTime() + 24 * 3600 * 1000),
        storageCondition: 'refrigerated',
        isConsumed: false,
        isDiscarded: false,
      },
      // 1 active urgent ("Eat First")
      {
        id: 'l2',
        recipeId: 'rice',
        titleEn: 'Rice',
        titleNe: 'भात',
        servingsRemaining: 1,
        remainingGrams: 200.0,
        preparedAt: new Date(now.getTime() - 34 * 3600 * 1000),
        useByDate: new Date(now.getTime() + 2 * 3600 * 1000), // 2 hours remaining
        storageCondition: 'refrigerated',
        isConsumed: false,
        isDiscarded: false,
      },
      // 1 successfully consumed
      {
        id: 'l3',
        recipeId: 'curry',
        titleEn: 'Curry',
        titleNe: 'तरकारी',
        servingsRemaining: 1,
        remainingGrams: 250.0,
        preparedAt: new Date(now.getTime() - 48 * 3600 * 1000),
        useByDate: new Date(now.getTime() - 12 * 3600 * 1000),
        storageCondition: 'refrigerated',
        isConsumed: true,
        consumedAt: new Date(now.getTime() - 24 * 3600 * 1000),
        isDiscarded: false,
      },
    ];

    const summary = WasteEngine.calculateWasteSummary({
      leftovers,
      now,
    });

    assert.equal(summary.totalLeftoversTracked, 3);
    assert.equal(summary.activeLeftoversCount, 2);
    assert.equal(summary.eatFirstCount, 1);
    assert.equal(summary.consumedCount, 1);
    assert.equal(summary.totalGramsSaved, 250.0);
    assert.equal(summary.wastePreventionRate, 100.0);
    assert.ok(summary.gentleFeedbackEn.includes('needs eating first'));
  });
});
