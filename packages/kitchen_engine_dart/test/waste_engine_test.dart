import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('WasteEngine Shelf-Life & Expiration Tests', () {
    final now = DateTime(2026, 10, 5, 12, 0); // Monday noon

    test('refrigerated shelf-life varies by dish type', () {
      expect(
        WasteEngine.getBaseShelfLifeHours(
          dishCategory: 'dal',
          storage: StorageCondition.refrigerated,
          climate: ClimateZone.temperate,
        ),
        equals(48),
      );

      // Cooked rice has shorter refrigerated life due to spore-forming bacteria
      expect(
        WasteEngine.getBaseShelfLifeHours(
          dishCategory: 'bhat',
          storage: StorageCondition.refrigerated,
          climate: ClimateZone.temperate,
        ),
        equals(36),
      );

      expect(
        WasteEngine.getBaseShelfLifeHours(
          dishCategory: 'roti',
          storage: StorageCondition.refrigerated,
          climate: ClimateZone.temperate,
        ),
        equals(72),
      );
    });

    test('room temperature shelf-life is climate sensitive', () {
      // Hot summer / monsoon
      expect(
        WasteEngine.getBaseShelfLifeHours(
          dishCategory: 'dal',
          storage: StorageCondition.roomTemperature,
          climate: ClimateZone.hotSummer,
        ),
        equals(8),
      );

      // Cool winter
      expect(
        WasteEngine.getBaseShelfLifeHours(
          dishCategory: 'dal',
          storage: StorageCondition.roomTemperature,
          climate: ClimateZone.coolWinter,
        ),
        equals(20),
      );
    });

    test('calculates correct urgency and "Eat First" status based on remaining hours', () {
      // Prepared 2 hours ago, refrigerated (48 hrs total) -> fresh
      final fresh = WasteEngine.calculateExpiry(
        preparedAt: now.subtract(const Duration(hours: 2)),
        dishCategory: 'dal',
        storage: StorageCondition.refrigerated,
        now: now,
      );
      expect(fresh.urgency, equals(LeftoverUrgency.fresh));
      expect(fresh.isEatFirst, isFalse);

      // Prepared 40 hours ago, refrigerated (8 hrs remaining) -> eatSoon
      final eatSoon = WasteEngine.calculateExpiry(
        preparedAt: now.subtract(const Duration(hours: 40)),
        dishCategory: 'dal',
        storage: StorageCondition.refrigerated,
        now: now,
      );
      expect(eatSoon.urgency, equals(LeftoverUrgency.eatSoon));
      expect(eatSoon.isEatFirst, isTrue);

      // Prepared 46 hours ago, refrigerated (2 hrs remaining) -> urgent
      final urgent = WasteEngine.calculateExpiry(
        preparedAt: now.subtract(const Duration(hours: 46)),
        dishCategory: 'dal',
        storage: StorageCondition.refrigerated,
        now: now,
      );
      expect(urgent.urgency, equals(LeftoverUrgency.urgent));
      expect(urgent.isEatFirst, isTrue);

      // Prepared 50 hours ago -> expired
      final expired = WasteEngine.calculateExpiry(
        preparedAt: now.subtract(const Duration(hours: 50)),
        dishCategory: 'dal',
        storage: StorageCondition.refrigerated,
        now: now,
      );
      expect(expired.urgency, equals(LeftoverUrgency.expired));
      expect(expired.isEatFirst, isFalse);
    });
  });

  group('Automatic Leftover Creation from Meal Logs', () {
    const testMembers = [
      MemberDietaryProfile(memberId: 'm1', name: 'Bikram', portionMultiplier: 1.0, preferredVesselId: 'plate', defaultVesselCount: 1.0),
      MemberDietaryProfile(memberId: 'm2', name: 'Srijana', portionMultiplier: 0.8, preferredVesselId: 'katori', defaultVesselCount: 2.0),
    ];

    test('creates leftover when cooked yield exceeds consumed portions', () {
      final now = DateTime(2026, 10, 5, 19, 0);
      // bikram: 400g * 1.0 = 400g
      // srijana: 150g * 2 * 0.8 = 240g
      // total consumed = 640g
      // batch yield = 1200g -> excess = 560g (~2 servings)
      final log = ConsumptionEngine.logUsualMeal(
        recipeId: 'masoor-dal',
        recipeTitle: 'Masoor Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members: testMembers,
        batchYieldGrams: 1200.0,
      );

      final leftover = WasteEngine.createFromMealLog(
        log: log,
        now: now,
      );

      expect(leftover, isNotNull);
      expect(leftover!.recipeId, equals('masoor-dal'));
      expect(leftover.remainingGrams, equals(560.0));
      expect(leftover.servingsRemaining, equals(2));
      expect(leftover.isConsumed, isFalse);
    });

    test('honors explicit leftoverGrams on meal log', () {
      final now = DateTime(2026, 10, 5, 19, 0);
      final log = ConsumptionEngine.logUsualMeal(
        recipeId: 'tarkari',
        recipeTitle: 'Aloo Gobi Tarkari',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members: testMembers,
        leftoverGrams: 300.0,
      );

      final leftover = WasteEngine.createFromMealLog(
        log: log,
        now: now,
      );

      expect(leftover, isNotNull);
      expect(leftover!.remainingGrams, equals(300.0));
      expect(leftover.servingsRemaining, equals(1));
    });

    test('ignores scraps below 50 grams', () {
      final now = DateTime(2026, 10, 5, 19, 0);
      final log = ConsumptionEngine.logUsualMeal(
        recipeId: 'tarkari',
        recipeTitle: 'Tarkari',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members: testMembers,
        leftoverGrams: 30.0, // negligible scrap
      );

      final leftover = WasteEngine.createFromMealLog(
        log: log,
        now: now,
      );

      expect(leftover, isNull);
    });

    test('returns null when no leftovers are left', () {
      final now = DateTime(2026, 10, 5, 19, 0);
      final log = ConsumptionEngine.logUsualMeal(
        recipeId: 'tarkari',
        recipeTitle: 'Tarkari',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now,
        members: testMembers,
        leftoverGrams: 0.0,
      );

      final leftover = WasteEngine.createFromMealLog(
        log: log,
        now: now,
      );

      expect(leftover, isNull);
    });
  });

  group('Waste Insights & Recurring Pattern Analytics', () {
    const fourMembers = [
      MemberDietaryProfile(memberId: 'm1', name: 'Bikram', portionMultiplier: 1.0, preferredVesselId: 'bowl', defaultVesselCount: 1.0),
      MemberDietaryProfile(memberId: 'm2', name: 'Srijana', portionMultiplier: 1.0, preferredVesselId: 'bowl', defaultVesselCount: 1.0),
      MemberDietaryProfile(memberId: 'm3', name: 'Aayush', portionMultiplier: 1.0, preferredVesselId: 'bowl', defaultVesselCount: 1.0),
      MemberDietaryProfile(memberId: 'm4', name: 'Guest', portionMultiplier: 1.0, preferredVesselId: 'bowl', defaultVesselCount: 1.0),
    ];

    test('detects recurring over-portioning on specific weekdays', () {
      // Week 1 Monday (Oct 5, 2026): Prepared 1500g (~6 servings), consumed 1000g (~4 servings), leftover 500g
      final mon1 = DateTime(2026, 10, 5, 19, 30);
      final log1 = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal',
        recipeTitle: 'Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: mon1,
        members: fourMembers,
        batchYieldGrams: 1500.0,
        leftoverGrams: 500.0,
      );

      // Week 2 Monday (Oct 12, 2026): Same recurring over-portioning
      final mon2 = DateTime(2026, 10, 12, 19, 30);
      final log2 = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal',
        recipeTitle: 'Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: mon2,
        members: fourMembers,
        batchYieldGrams: 1500.0,
        leftoverGrams: 500.0,
      );

      final insights = WasteEngine.analyzeWastePatterns([log1, log2]);

      expect(insights.length, equals(1));
      final insight = insights.first;
      expect(insight.recipeId, equals('dal'));
      expect(insight.dayOfWeek, equals(1)); // Monday
      expect(insight.dayNameEn, equals('Monday'));
      expect(insight.dayNameNe, equals('सोमबार'));
      expect(insight.occurrences, equals(2));
      expect(insight.recommendedServings, equals(4.0));
      expect(
        insight.insightEn,
        equals('Dal is often left over on Mondays; try 4 servings instead of 6.'),
      );
      expect(
        insight.insightNe,
        equals('सोमबार Dal प्रायः बाँकी रहने गर्छ; ६ भागको सट्टा ४ भाग पकाउनुहोस्।'),
      );
      expect(insight.estimatedMonthlySavingsNpr, greaterThan(0));
    });

    test('ignores isolated single instances when minimumOccurrences is 2', () {
      final mon1 = DateTime(2026, 10, 5, 19, 30);
      final log1 = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal',
        recipeTitle: 'Dal',
        mealSlot: 'evening-dal-bhat',
        consumedAt: mon1,
        members: fourMembers,
        batchYieldGrams: 1500.0,
        leftoverGrams: 500.0,
      );

      final insights = WasteEngine.analyzeWastePatterns([log1]);
      expect(insights, isEmpty);
    });
  });

  group('Household Waste Summary & Calm Feedback', () {
    final now = DateTime(2026, 10, 5, 12, 0);

    test('summarizes active, eat-first, and consumed leftovers', () {
      final leftovers = [
        // 1 active fresh
        TrackedLeftover(
          id: 'l1',
          recipeId: 'dal',
          titleEn: 'Dal',
          titleNe: 'दाल',
          servingsRemaining: 2,
          remainingGrams: 400.0,
          preparedAt: now.subtract(const Duration(hours: 10)),
          useByDate: now.add(const Duration(hours: 24)),
        ),
        // 1 active urgent ("Eat First")
        TrackedLeftover(
          id: 'l2',
          recipeId: 'rice',
          titleEn: 'Rice',
          titleNe: 'भात',
          servingsRemaining: 1,
          remainingGrams: 200.0,
          preparedAt: now.subtract(const Duration(hours: 34)),
          useByDate: now.add(const Duration(hours: 2)), // 2 hours remaining
        ),
        // 1 successfully consumed
        TrackedLeftover(
          id: 'l3',
          recipeId: 'curry',
          titleEn: 'Curry',
          titleNe: 'तरकारी',
          servingsRemaining: 1,
          remainingGrams: 250.0,
          preparedAt: now.subtract(const Duration(hours: 48)),
          useByDate: now.subtract(const Duration(hours: 12)),
          isConsumed: true,
          consumedAt: now.subtract(const Duration(hours: 24)),
        ),
      ];

      final summary = WasteEngine.calculateWasteSummary(
        leftovers: leftovers,
        now: now,
      );

      expect(summary.totalLeftoversTracked, equals(3));
      expect(summary.activeLeftoversCount, equals(2));
      expect(summary.eatFirstCount, equals(1));
      expect(summary.consumedCount, equals(1));
      expect(summary.totalGramsSaved, equals(250.0));
      expect(summary.wastePreventionRate, equals(100.0));
      expect(summary.gentleFeedbackEn, contains('needs eating first'));
    });
  });
}
