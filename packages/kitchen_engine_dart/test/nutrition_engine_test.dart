import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  verifyIdMatching();
  verifyPerRecipeBatches();
  verifyUsdaImport();
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

/// Regression coverage for the ingredient-id mismatch between packs and the composition table.
void verifyIdMatching() {
  group('NutritionEngine ingredient id matching', () {
    test('matches an id that only differs by separator', () {
      // The packs write snake_case, the table kebab-case.
      expect(NutritionEngine.compositionFor('mustard_oil'), isNotNull);
      expect(NutritionEngine.compositionFor('mustard-oil'), isNotNull);
      expect(NutritionEngine.compositionFor('wheat_flour')?.id, 'wheat-flour');
    });

    test('matches a genuinely different name through an alias', () {
      expect(NutritionEngine.compositionFor('kalo_dal')?.id, 'black-lentil');
      expect(NutritionEngine.compositionFor('palungo')?.id, 'spinach');
    });

    test('is case insensitive', () {
      expect(NutritionEngine.compositionFor('Mustard_Oil'), isNotNull);
    });

    test('still returns null for an unknown ingredient', () {
      expect(NutritionEngine.compositionFor('unobtainium'), isNull);
      expect(NutritionEngine.hasCompositionFor('unobtainium'), isFalse);
    });

    test('normalisation folds separators and case only', () {
      expect(NutritionEngine.normalizeIngredientId('  Mustard_Oil '), 'mustard-oil');
      expect(NutritionEngine.normalizeIngredientId('rice'), 'rice');
    });

    test('yield factors resolve through the same normalisation', () {
      // An unmatched yield silently became 1.0, so cooked weights were quietly wrong.
      expect(NutritionEngine.yieldFor('rice'), 3.0);
      expect(NutritionEngine.yieldFor('mustard_oil'), 1.0);
      expect(NutritionEngine.yieldFor('unobtainium'), 1.0);
    });

    test('a snake_case pack ingredient now contributes nutrients', () {
      final batch = NutritionEngine.computeBatch([
        BatchIngredient('mustard_oil', 30),
      ]);
      expect(batch.totals.fatG, closeTo(30, 0.01));
    });
  });
}

/// Coverage for deriving a batch from a recipe's own ingredients rather than a fixed batch.
void verifyPerRecipeBatches() {
  RegionRecipe recipe({
    required String id,
    required List<(String, double, String)> ingredients,
    int servings = 4,
  }) =>
      RegionRecipe(
        id: id,
        titleEn: id,
        titleNe: id,
        category: 'main',
        cuisine: 'nepali',
        dietary: const [],
        prepTimeMinutes: 10,
        cookTimeMinutes: 20,
        servings: servings,
        difficulty: 'easy',
        pressureCooker: const RecipeWhistleProfile(
          enabled: false,
          recommendedWhistles: 0,
          altitudeWhistleOffsetKathmandu: 0,
          heatLevel: 'low',
          releaseType: 'natural',
        ),
        ingredients: [
          for (final i in ingredients)
            RecipeIngredientItem(
              ingredientId: i.$1,
              quantity: i.$2,
              unit: i.$3,
            ),
        ],
        steps: const [],
        seasonality: const [],
        tags: const [],
      );

  group('NutritionEngine.batchForRecipe', () {
    test('uses the recipe its own ingredients, not a fixed reference', () {
      final dalBhat = recipe(
        id: 'dal-bhat',
        ingredients: [('rice', 300, 'g'), ('lentil', 150, 'g')],
      );
      final thukpa = recipe(
        id: 'thukpa',
        ingredients: [('wheat_flour', 200, 'g'), ('potato', 200, 'g')],
      );

      final a = NutritionEngine.batchForRecipe(dalBhat)!;
      final b = NutritionEngine.batchForRecipe(thukpa)!;

      // The whole point: two different meals must not score the same.
      expect(a.totals.proteinG, isNot(closeTo(b.totals.proteinG, 0.001)));
    });

    test('converts the ingredient unit rather than assuming grams', () {
      final r = recipe(id: 'rice-only', ingredients: [('rice', 1, 'kg')]);
      final batch = NutritionEngine.batchForRecipe(r)!;
      expect(batch.totals.kcal, closeTo(3450, 1)); // 1000 g at 345 kcal/100 g
    });

    test('scales with servings', () {
      final r = recipe(
        id: 'dal-bhat',
        ingredients: [('rice', 300, 'g'), ('lentil', 150, 'g')],
      );
      final forFour = NutritionEngine.batchForRecipe(r, servings: 4)!;
      final forEight = NutritionEngine.batchForRecipe(r, servings: 8)!;
      expect(forEight.totals.kcal, closeTo(forFour.totals.kcal * 2, 0.01));
    });

    test('reports an unknown ingredient instead of quietly dropping it', () {
      // timur is a citron and USDA carries no entry for it, so it stays unknown. Using garlic
      // here would pass vacuously now that it has been imported.
      final r = recipe(
        id: 'with-timur',
        ingredients: [('rice', 300, 'g'), ('timur', 20, 'g')],
      );
      final batch = NutritionEngine.batchForRecipe(r)!;

      expect(batch.unknownIngredients, contains('timur'));
      expect(batch.isComplete, isFalse);
    });

    test('a fully imported recipe is now complete', () {
      // garlic used to be an unknown ingredient and made every recipe containing it look
      // incomplete. The USDA import should have closed that.
      final r = recipe(
        id: 'garlic-rice',
        ingredients: [('rice', 300, 'g'), ('garlic', 20, 'g')],
      );
      expect(NutritionEngine.batchForRecipe(r)!.isComplete, isTrue);
    });

    test('coverage is weighted by weight, not by ingredient count', () {
      // 300 g known, 5 g unknown: the unknown is a rounding error in calories but still makes
      // the batch incomplete.
      final r = recipe(
        id: 'mostly-known',
        ingredients: [('rice', 300, 'g'), ('unobtainium', 5, 'g')],
      );
      final batch = NutritionEngine.batchForRecipe(r)!;

      expect(batch.knownGramsFraction, closeTo(300 / 305, 0.001));
      expect(batch.isComplete, isFalse);
    });

    test('a fully known recipe reports complete coverage', () {
      final r = recipe(id: 'dal-bhat', ingredients: [('rice', 300, 'g')]);
      final batch = NutritionEngine.batchForRecipe(r)!;
      expect(batch.isComplete, isTrue);
      expect(batch.knownGramsFraction, 1.0);
    });

    test('a recipe with no usable ingredients yields no batch', () {
      final r = recipe(id: 'empty', ingredients: []);
      final batch = NutritionEngine.batchForRecipe(r);
      expect(batch == null || batch.totals.grams <= 0, isTrue);
    });
  });
}

/// Coverage for the USDA import.
void verifyUsdaImport() {
  group('USDA composition import', () {
    test('rows imported from USDA are reachable', () {
      for (final id in ['garlic', 'ginger', 'ghee', 'tomato', 'onion', 'turmeric']) {
        expect(
          NutritionEngine.hasCompositionFor(id),
          isTrue,
          reason: '$id should resolve after the USDA import',
        );
      }
    });

    test('imported rows resolve through a snake_case pack id', () {
      expect(NutritionEngine.compositionFor('green_chili'), isNotNull);
      expect(NutritionEngine.compositionFor('kitchen_papad'), isNull);
    });

    test('imported values are plausible per 100 g', () {
      // Guards against a column mix-up, which would be silent: kcal landing in the fibre column
      // would still "work" and produce nonsense totals.
      final garlic = NutritionEngine.compositionFor('garlic')!;
      expect(garlic.kcal, inInclusiveRange(100, 200));
      expect(garlic.proteinG, inInclusiveRange(3, 10));
      expect(garlic.fiberG, inInclusiveRange(1, 4));
      expect(garlic.fatG, lessThan(2));

      final ghee = NutritionEngine.compositionFor('ghee')!;
      expect(ghee.fatG, greaterThan(90), reason: 'ghee is almost entirely fat');
      expect(ghee.kcal, greaterThan(800));

      final oil = NutritionEngine.compositionFor('sunflower_oil')!;
      expect(oil.fatG, greaterThan(90));
    });

    test('imported rows carry the USDA source marker', () {
      expect(NutritionEngine.compositionFor('garlic')?.source, CompositionSource.usda);
      // Curated rows keep their own provenance.
      expect(NutritionEngine.compositionFor('rice')?.source, CompositionSource.nfct);
    });

    test('curated rows win over imported rows for the same id', () {
      // rice is curated; if the import shadowed it the value would be USDA's.
      expect(NutritionEngine.compositionFor('rice')?.kcal, 345);
    });

    test('animal products carry zero fibre rather than a missing value', () {
      expect(NutritionEngine.compositionFor('prawn')?.fiberG, 0);
      expect(NutritionEngine.compositionFor('goat_meat')?.proteinG, greaterThan(15));
    });

    test('every imported id is unique', () {
      final ids = NutritionEngine.allCompositions.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
