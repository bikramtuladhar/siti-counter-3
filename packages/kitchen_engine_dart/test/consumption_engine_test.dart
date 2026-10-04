import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ConsumptionEngine - Calibrated Vessels & Household Customization', () {
    test('provides standard calibrated vessels with volume and grams', () {
      final vessels = CalibratedVessel.standardVessels;
      expect(vessels.length, greaterThanOrEqualTo(6));

      final katori = vessels.firstWhere((v) => v.id == 'katori');
      expect(katori.volumeMl, equals(150.0));
      expect(katori.standardGrams, equals(150.0));
      expect(katori.type, equals(VesselType.katori));

      final plate = vessels.firstWhere((v) => v.id == 'plate');
      expect(plate.volumeMl, equals(400.0));

      final ladle = vessels.firstWhere((v) => v.id == 'ladle');
      expect(ladle.volumeMl, equals(60.0));

      final roti = vessels.firstWhere((v) => v.id == 'roti');
      expect(roti.standardGrams, equals(40.0));
    });

    test('household calibration overrides vessel volume without affecting other vessels', () {
      const profile = HouseholdVesselProfile(
        customVolumes: {'katori': 180.0, 'ladle': 75.0},
      );

      final katori = profile.getEffectiveVessel('katori');
      expect(katori.volumeMl, equals(180.0));
      expect(katori.standardGrams, equals(180.0));

      final ladle = profile.getEffectiveVessel('ladle');
      expect(ladle.volumeMl, equals(75.0));

      // Uncalibrated plate uses standard 400.0
      final plate = profile.getEffectiveVessel('plate');
      expect(plate.volumeMl, equals(400.0));
    });
  });

  group('ConsumptionEngine - One-Tap Usual Meal Logging', () {
    final members = [
      const MemberDietaryProfile(
        memberId: 'm1',
        name: 'Bikram',
        role: 'Adult',
        nutritionProfile: 'everyday',
        portionMultiplier: 1.0,
        preferredVesselId: 'plate',
        defaultVesselCount: 1.0, // 1 plate (400g)
      ),
      const MemberDietaryProfile(
        memberId: 'm2',
        name: 'Grandmother',
        role: 'Elderly',
        nutritionProfile: 'elderly',
        portionMultiplier: 0.8,
        preferredVesselId: 'katori',
        defaultVesselCount: 2.0, // 2 katori (300g * 0.8 = 240g)
      ),
      const MemberDietaryProfile(
        memberId: 'm3',
        name: 'Aayush',
        role: 'Child',
        nutritionProfile: 'child',
        portionMultiplier: 0.6,
        preferredVesselId: 'katori',
        defaultVesselCount: 1.0, // 1 katori (150g * 0.6 = 90g)
      ),
    ];

    test('logs usual dinner with one tap confirmation', () {
      final log = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal-bhat-tarkari',
        recipeTitle: 'Dal Bhat Tarkari',
        mealSlot: 'evening-dal-bhat',
        members: members,
      );

      expect(log.loggedAsUsual, isTrue);
      expect(log.recipeId, equals('dal-bhat-tarkari'));
      expect(log.memberPortions.length, equals(3));
      expect(log.totalServings, closeTo(2.4, 0.01)); // 1.0 + 0.8 + 0.6 = 2.4

      final bikram = log.memberPortions.firstWhere((p) => p.memberId == 'm1');
      expect(bikram.calculatedGrams, equals(400.0));
      expect(bikram.ateUsual, isTrue);
      expect(bikram.skipped, isFalse);

      final child = log.memberPortions.firstWhere((p) => p.memberId == 'm3');
      expect(child.calculatedGrams, closeTo(90.0, 0.1));
      expect(child.ateUsual, isTrue);
    });

    test('logs adjusted meal when members eat more/less or skip', () {
      final log = ConsumptionEngine.logAdjustedMeal(
        recipeId: 'kalo-dal',
        recipeTitle: 'Kathmandu Kalo Dal',
        mealSlot: 'morning-dal-bhat',
        members: members,
        adjustments: {
          'm1': (vesselId: 'plate', vesselCount: 1.5, skipped: false, notes: 'Extra serving'),
          'm2': (vesselId: 'katori', vesselCount: 0.0, skipped: true, notes: 'Ekadashi fasting'),
          // m3 left default
        },
      );

      expect(log.loggedAsUsual, isFalse);
      final bikram = log.memberPortions.firstWhere((p) => p.memberId == 'm1');
      expect(bikram.calculatedGrams, equals(600.0)); // 1.5 * 400g = 600g
      expect(bikram.ateUsual, isFalse);
      expect(bikram.notes, equals('Extra serving'));

      final grandmother = log.memberPortions.firstWhere((p) => p.memberId == 'm2');
      expect(grandmother.skipped, isTrue);
      expect(grandmother.calculatedGrams, equals(0.0));
      expect(grandmother.notes, equals('Ekadashi fasting'));

      final child = log.memberPortions.firstWhere((p) => p.memberId == 'm3');
      expect(child.ateUsual, isTrue);
    });
  });

  group('ConsumptionEngine - Outside Food & Weekly Non-Shaming Summary', () {
    test('quick adds outside snacks and computes calm weekly summary', () {
      final now = DateTime(2026, 10, 15, 12, 0);
      final snack = ConsumptionEngine.quickAddOutsideFood(
        memberId: 'm1',
        memberName: 'Bikram',
        foodName: 'Buff Momo',
        mealSlot: 'afternoon-khaja',
        portionSize: 'medium',
        estimatedCalories: 380,
        consumedAt: now,
        tags: ['street-food', 'khaja'],
      );
      expect(snack.foodName, equals('Buff Momo'));
      expect(snack.tags, contains('street-food'));

      final members = [
        const MemberDietaryProfile(
          memberId: 'm1',
          name: 'Bikram',
          role: 'Adult',
          nutritionProfile: 'everyday',
        ),
        const MemberDietaryProfile(
          memberId: 'm3',
          name: 'Aayush',
          role: 'Child',
          nutritionProfile: 'child',
        ),
      ];

      final weekStart = DateTime(2026, 10, 11);
      final weekEnd = DateTime(2026, 10, 17);

      final meal1 = ConsumptionEngine.logUsualMeal(
        recipeId: 'dal-bhat',
        recipeTitle: 'Dal Bhat',
        mealSlot: 'morning-dal-bhat',
        consumedAt: now,
        members: members,
      );

      final meal2 = ConsumptionEngine.logUsualMeal(
        recipeId: 'aloo-gobi',
        recipeTitle: 'Aloo Gobi',
        mealSlot: 'evening-dal-bhat',
        consumedAt: now.add(const Duration(hours: 6)),
        members: members,
      );

      final summary = ConsumptionEngine.calculateWeeklySummary(
        weekStart: weekStart,
        weekEnd: weekEnd,
        mealLogs: [meal1, meal2],
        outsideLogs: [snack],
        members: members,
      );

      expect(summary.totalMealsLogged, equals(2));
      expect(summary.totalOutsideSnacksLogged, equals(1));
      expect(summary.usualComplianceRate, equals(100.0));

      final bikramSummary = summary.memberSummaries.firstWhere((s) => s.memberId == 'm1');
      expect(bikramSummary.mealsLogged, equals(2));
      expect(bikramSummary.snacksLogged, equals(1));
      expect(bikramSummary.estimatedCalories, isNotNull);

      // Section 8 & 11: Children are NEVER shown calorie counts
      final childSummary = summary.memberSummaries.firstWhere((s) => s.memberId == 'm3');
      expect(childSummary.mealsLogged, equals(2));
      expect(childSummary.estimatedCalories, isNull); // Protected from calorie counting!
      expect(childSummary.gentleFeedback, contains('पोषण'));
    });
  });
}
