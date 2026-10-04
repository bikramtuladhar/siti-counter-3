import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Yield factors', () {
    test('rice triples in weight; spinach halves; unknown is 1.0', () {
      expect(NutritionEngine.yieldFor('rice'), 3.0);
      expect(NutritionEngine.yieldFor('spinach'), 0.5);
      expect(NutritionEngine.yieldFor('mystery'), 1.0);
    });

    test('cooked density = raw density / yield', () {
      final cooked = NutritionEngine.cookedPer100g('rice');
      expect(cooked.kcal, closeTo(345 / 3, 1e-9));
      expect(cooked.proteinG, closeTo(6.8 / 3, 1e-9));
      final spinach = NutritionEngine.cookedPer100g('spinach');
      expect(spinach.proteinG, closeTo(4.0, 1e-9));
    });
  });

  group('Batch nutrition', () {
    test('nutrients come from raw weight, cooked weight from yield', () {
      final b = NutritionEngine.computeBatch(const [
        BatchIngredient('rice', 200),
        BatchIngredient('lentil', 100),
      ]);
      expect(b.totals.grams, closeTo(200 * 3 + 100 * 2.5, 1e-9));
      expect(b.totals.proteinG, closeTo(2 * 6.8 + 25.1, 1e-9));
      expect(b.foodGroups, {'grains', 'pulses'});
    });

    test('weighed cooked yield overrides the estimate', () {
      final b = NutritionEngine.computeBatch(
        const [BatchIngredient('rice', 200)],
        cookedYieldGrams: 500,
      );
      expect(b.totals.grams, 500);
      expect(b.totals.kcal, closeTo(690, 1e-9));
    });

    test('oil adds energy but is not a food group; unknowns are reported', () {
      final b = NutritionEngine.computeBatch(const [
        BatchIngredient('mustard-oil', 10),
        BatchIngredient('dragonfruit', 50),
      ]);
      expect(b.foodGroups, isEmpty);
      expect(b.totals.kcal, closeTo(90, 1e-9));
      expect(b.unknownIngredients, ['dragonfruit']);
    });

    test('portion scales by cooked grams', () {
      final b = NutritionEngine.computeBatch(const [BatchIngredient('rice', 100)]);
      final p = b.portion(150); // half the 300 g batch
      expect(p.kcal, closeTo(172.5, 1e-9));
      expect(b.portion(0).kcal, 0);
    });
  });

  group('Member views', () {
    const adult = MemberDietaryProfile(memberId: 'a', name: 'Asha');
    const child = MemberDietaryProfile(
      memberId: 'c',
      name: 'Chhori',
      role: 'Child',
      nutritionProfile: 'child',
    );

    PortionIntake dalBhat() {
      final b = NutritionEngine.computeBatch(const [
        BatchIngredient('rice', 100),
        BatchIngredient('lentil', 50),
        BatchIngredient('spinach', 100),
      ]);
      return PortionIntake(
        nutrients: b.totals,
        foodGroups: b.foodGroups,
        seasonalFraction: 0.5,
      );
    }

    test('child view carries food groups and no numbers or calories', () {
      final v = NutritionEngine.buildMemberView(member: child, intakes: [dalBhat()]);
      expect(v.showsNumbers, isFalse);
      expect(v.estimatedKcalPerDay, isNull);
      expect(v.bars, isEmpty);
      expect(v.foodGroupsCovered, ['grains', 'pulses', 'vegetables']);
    });

    test('adult view has protein, fibre and seasonal bars within 0..1', () {
      final v = NutritionEngine.buildMemberView(
        member: adult,
        intakes: List.filled(14, dalBhat()),
      );
      expect(v.showsNumbers, isTrue);
      expect(v.bars.map((b) => b.key), ['protein', 'fiber', 'seasonal']);
      for (final b in v.bars) {
        expect(b.fraction, inInclusiveRange(0.0, 1.0));
      }
      expect(v.bars.last.fraction, closeTo(0.5, 1e-9));
      expect(v.estimatedKcalPerDay, isNotNull);
    });

    test('over-target is "abundant", never an alert, and fraction caps at 1', () {
      final big = PortionIntake(
        nutrients: const NutrientTotals(grams: 1000, proteinG: 5000, fiberG: 5000),
      );
      final v = NutritionEngine.buildMemberView(member: adult, intakes: [big]);
      expect(v.bars.first.fraction, 1.0);
      expect(v.bars.first.level, 'abundant');
    });

    test('empty intake gives calm warming-up bars, not errors', () {
      final v = NutritionEngine.buildMemberView(member: adult, intakes: const []);
      expect(v.bars.every((b) => b.level == 'warming-up'), isTrue);
      expect(v.estimatedKcalPerDay, isNull);
    });

    test('pregnancy has a higher protein target than everyday', () {
      final intake = PortionIntake(
        nutrients: const NutrientTotals(grams: 100, proteinG: 175),
      );
      const preg = MemberDietaryProfile(
        memberId: 'p',
        name: 'Pema',
        nutritionProfile: 'pregnancy',
      );
      final e = NutritionEngine.buildMemberView(member: adult, intakes: [intake]);
      final p = NutritionEngine.buildMemberView(member: preg, intakes: [intake]);
      expect(p.bars.first.fraction, lessThan(e.bars.first.fraction));
    });
  });
}
