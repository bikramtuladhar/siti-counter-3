import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('AllergenCatalog & Hidden Sources', () {
    test('detects hidden gluten in compounded hing (asafoetida)', () {
      final allergens = AllergenEngine.getAllergensForIngredient('hing');
      expect(allergens, isNotEmpty);
      expect(allergens.any((a) => a.allergen == AllergenCatalog.gluten && a.isHidden), isTrue);
    });

    test('detects hidden dairy in clarified butter (ghee)', () {
      final allergens = AllergenEngine.getAllergensForIngredient('ghee');
      expect(allergens, isNotEmpty);
      expect(allergens.any((a) => a.allergen == AllergenCatalog.milk && a.isHidden), isTrue);
    });

    test('detects soy and hidden gluten in soy sauce', () {
      final allergens = AllergenEngine.getAllergensForIngredient('soy_sauce');
      expect(allergens.any((a) => a.allergen == AllergenCatalog.soy), isTrue);
      expect(allergens.any((a) => a.allergen == AllergenCatalog.gluten && a.isHidden), isTrue);
    });

    test('detects regional allergens: buckwheat, mustard oil, fenugreek', () {
      final fapar = AllergenEngine.getAllergensForIngredient('fapar');
      expect(fapar.any((a) => a.allergen == AllergenCatalog.buckwheat), isTrue);

      final tori = AllergenEngine.getAllergensForIngredient('tori_ko_tel');
      expect(tori.any((a) => a.allergen == AllergenCatalog.mustard), isTrue);
      expect(tori.any((a) => a.allergen == AllergenCatalog.mustardOil), isTrue);

      final methi = AllergenEngine.getAllergensForIngredient('methi');
      expect(methi.any((a) => a.allergen == AllergenCatalog.fenugreek), isTrue);
    });
  });

  group('Gate 2: Zero-Miss Test Suite for Severe Allergens', () {
    test('Zero false negatives: Peanut allergy strictly blocks peanuts, peanut butter, badam', () {
      final allergyProfiles = [
        const MemberAllergyProfile(
          allergen: AllergenCatalog.peanuts,
          severity: AllergySeverity.severe,
          memberName: 'Bikram',
        ),
      ];

      // Safe recipe
      final safeVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['rice', 'lentils', 'spinach', 'turmeric'],
        allergyProfiles: allergyProfiles,
      );
      expect(safeVerdict.isSafe, isTrue);
      expect(safeVerdict.isAllowedInAutoPlan, isTrue);
      expect(safeVerdict.conflicts, isEmpty);

      // Recipe with peanuts
      final peanutVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['chickpeas', 'badam', 'onion'],
        allergyProfiles: allergyProfiles,
      );
      expect(peanutVerdict.isSafe, isFalse);
      expect(peanutVerdict.isAllowedInAutoPlan, isFalse);
      expect(peanutVerdict.hasSevereConflict, isTrue);
      expect(peanutVerdict.conflicts.any((c) => c.allergen == AllergenCatalog.peanuts), isTrue);

      // Recipe with peanut butter
      final pbVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['toast', 'peanut_butter'],
        allergyProfiles: allergyProfiles,
      );
      expect(pbVerdict.isSafe, isFalse);
      expect(pbVerdict.isAllowedInAutoPlan, isFalse);
      expect(pbVerdict.hasSevereConflict, isTrue);
    });

    test('Zero false negatives: Severe Gluten allergy catches hidden hing and soy sauce', () {
      final glutenProfiles = [
        const MemberAllergyProfile(
          allergen: AllergenCatalog.gluten,
          severity: AllergySeverity.severe,
          memberName: 'Aayush',
        ),
      ];

      // Recipe with hing (common Nepali dal tadka)
      final dalTadkaVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['musuro_dal', 'tomato', 'cumin', 'hing'],
        allergyProfiles: glutenProfiles,
      );
      expect(dalTadkaVerdict.isSafe, isFalse);
      expect(dalTadkaVerdict.isAllowedInAutoPlan, isFalse);
      expect(dalTadkaVerdict.hasSevereConflict, isTrue);
      expect(dalTadkaVerdict.hasHiddenAllergens, isTrue);
      expect(dalTadkaVerdict.conflicts.any((c) => c.ingredientId == 'hing' && c.isHiddenSource), isTrue);

      // Recipe with soy sauce
      final chowmeinVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['rice_noodles', 'cabbage', 'soy_sauce'],
        allergyProfiles: glutenProfiles,
      );
      expect(chowmeinVerdict.isSafe, isFalse);
      expect(chowmeinVerdict.isAllowedInAutoPlan, isFalse);
      expect(chowmeinVerdict.conflicts.any((c) => c.ingredientId == 'soy_sauce' && c.isHiddenSource), isTrue);
    });

    test('Zero false negatives: Severe Dairy allergy catches hidden ghee and paneer', () {
      final dairyProfiles = [
        const MemberAllergyProfile(
          allergen: AllergenCatalog.milk,
          severity: AllergySeverity.severe,
          memberName: 'Sita',
        ),
      ];

      final khichdiVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['rice', 'mung_dal', 'ghee', 'salt'],
        allergyProfiles: dairyProfiles,
      );
      expect(khichdiVerdict.isSafe, isFalse);
      expect(khichdiVerdict.isAllowedInAutoPlan, isFalse);
      expect(khichdiVerdict.hasSevereConflict, isTrue);
      expect(khichdiVerdict.hasHiddenAllergens, isTrue);
      expect(khichdiVerdict.conflicts.any((c) => c.ingredientId == 'ghee'), isTrue);

      final paneerCurryVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['paneer', 'green_peas', 'tomato'],
        allergyProfiles: dairyProfiles,
      );
      expect(paneerCurryVerdict.isSafe, isFalse);
      expect(paneerCurryVerdict.isAllowedInAutoPlan, isFalse);
    });

    test('Zero false negatives: Severe Buckwheat (Fapar) allergy is strictly blocked', () {
      final buckwheatProfiles = [
        const MemberAllergyProfile(
          allergen: AllergenCatalog.buckwheat,
          severity: AllergySeverity.severe,
        ),
      ];

      final pancakeVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['fapar_pitho', 'water', 'salt'],
        allergyProfiles: buckwheatProfiles,
      );
      expect(pancakeVerdict.isSafe, isFalse);
      expect(pancakeVerdict.isAllowedInAutoPlan, isFalse);
      expect(pancakeVerdict.hasSevereConflict, isTrue);
      expect(pancakeVerdict.conflicts.any((c) => c.allergen == AllergenCatalog.buckwheat), isTrue);
    });
  });

  group('Dietary Rules Enforcement', () {
    test('Vegetarian rule blocks meat, poultry, and fish', () {
      final vegVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['khasi_ko_masu', 'onion', 'ginger', 'oil'],
        allergyProfiles: [],
        dietaryRules: [DietaryRule.vegetarian],
      );
      expect(vegVerdict.isSafe, isFalse);
      expect(vegVerdict.isAllowedInAutoPlan, isFalse);
      expect(vegVerdict.conflicts.any((c) => c.isDietaryViolation), isTrue);
    });

    test('Vegan rule blocks meat and dairy products including ghee', () {
      final veganVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['rice', 'spinach', 'ghee'],
        allergyProfiles: [],
        dietaryRules: [DietaryRule.vegan],
      );
      expect(veganVerdict.isSafe, isFalse);
      expect(veganVerdict.isAllowedInAutoPlan, isFalse);
      expect(veganVerdict.conflicts.any((c) => c.ingredientId == 'ghee' && c.isDietaryViolation), isTrue);
    });

    test('Jain vegetarian rule strictly blocks root vegetables (onion, garlic, potato)', () {
      final jainVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['potato', 'cauliflower', 'tomato', 'cumin'],
        allergyProfiles: [],
        dietaryRules: [DietaryRule.jainVegetarian],
      );
      expect(jainVerdict.isSafe, isFalse);
      expect(jainVerdict.isAllowedInAutoPlan, isFalse);
      expect(jainVerdict.conflicts.any((c) => c.ingredientId == 'potato' && c.isDietaryViolation), isTrue);
    });

    test('Hindu fasting (Vrata/Ekadashi) blocks grains and pulses, permits potato and buckwheat', () {
      // Forbidden: rice and dal
      final forbiddenVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['rice', 'musuro_dal', 'ghee'],
        allergyProfiles: [],
        dietaryRules: [DietaryRule.hinduFasting],
      );
      expect(forbiddenVerdict.isSafe, isFalse);
      expect(forbiddenVerdict.isAllowedInAutoPlan, isFalse);

      // Permitted: buckwheat flour and potato cooked in ghee
      final fastingPancakeVerdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ['buckwheat_flour', 'potato', 'ghee', 'rock_salt'],
        allergyProfiles: [],
        dietaryRules: [DietaryRule.hinduFasting],
      );
      expect(fastingPancakeVerdict.isSafe, isTrue);
      expect(fastingPancakeVerdict.isAllowedInAutoPlan, isTrue);
    });
  });

  group('Safe Substitutions Engine', () {
    test('suggests pure resin or ginger-cumin blend for hing', () {
      final subs = AllergenEngine.getSafeSubstitutions(
        ingredientId: 'hing',
        memberAllergies: [
          const MemberAllergyProfile(allergen: AllergenCatalog.gluten),
        ],
      );
      expect(subs, isNotEmpty);
      expect(subs.any((s) => s.ingredientId == 'pure_hing_resin'), isTrue);
      expect(subs.any((s) => s.ingredientId == 'ginger_cumin_mix'), isTrue);
    });

    test('suggests sunflower seed butter for peanut butter', () {
      final subs = AllergenEngine.getSafeSubstitutions(
        ingredientId: 'peanut_butter',
        memberAllergies: [
          const MemberAllergyProfile(allergen: AllergenCatalog.peanuts),
        ],
      );
      expect(subs, isNotEmpty);
      expect(subs.any((s) => s.ingredientId == 'sunflower_seed_butter'), isTrue);
    });

    test('avoids suggesting substitutes that introduce an active allergen', () {
      // Member is allergic to BOTH Dairy AND Mustard
      final subs = AllergenEngine.getSafeSubstitutions(
        ingredientId: 'ghee',
        memberAllergies: [
          const MemberAllergyProfile(allergen: AllergenCatalog.milk),
          const MemberAllergyProfile(allergen: AllergenCatalog.mustard),
        ],
      );

      // Mustard oil must NOT be suggested because member is mustard-allergic!
      expect(subs.any((s) => s.ingredientId == 'mustard_oil'), isFalse);
      // Sunflower oil is completely safe
      expect(subs.any((s) => s.ingredientId == 'sunflower_oil'), isTrue);
    });
  });

  group('Deterministic Auto-Plan Recipe Filter', () {
    test('strictly removes recipes with severe conflicts from auto-plan list', () {
      final recipes = [
        {'id': 'dal_bhat', 'ingredients': ['rice', 'musuro_dal', 'ghee']},
        {'id': 'peanut_chutney', 'ingredients': ['peanuts', 'tomato', 'chili']},
        {'id': 'fapar_roti', 'ingredients': ['buckwheat_flour', 'water', 'salt']},
        {'id': 'steamed_veggies', 'ingredients': ['carrot', 'cauliflower', 'salt']},
      ];

      final filtered = AllergenEngine.filterRecipesForAutoPlan<Map<String, dynamic>>(
        recipes: recipes,
        getIngredients: (r) => (r['ingredients'] as List).cast<String>(),
        allergyProfiles: [
          const MemberAllergyProfile(
            allergen: AllergenCatalog.peanuts,
            severity: AllergySeverity.severe,
          ),
          const MemberAllergyProfile(
            allergen: AllergenCatalog.milk,
            severity: AllergySeverity.severe,
          ),
        ],
      );

      final remainingIds = filtered.map((r) => r['id']).toList();
      // peanut_chutney (peanuts) and dal_bhat (ghee->dairy) must be strictly removed
      expect(remainingIds, isNot(contains('peanut_chutney')));
      expect(remainingIds, isNot(contains('dal_bhat')));
      // fapar_roti and steamed_veggies remain
      expect(remainingIds, contains('fapar_roti'));
      expect(remainingIds, contains('steamed_veggies'));
    });
  });
}
