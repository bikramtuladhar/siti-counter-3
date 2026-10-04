import 'dart:convert';
import 'dart:io';

import 'package:kitchen_engine/allergen_engine.dart';
import 'package:kitchen_engine/auto_plan.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:test/test.dart';

/// Mirrors the fixtures in `packages/kitchen_engine_ts/src/auto_plan.test.ts`. Slot ids
/// deliberately sort differently from their sortOrder, so the fixture also pins that a day
/// renders in rhythm order rather than alphabetically.
const List<PlanRhythmSlot> nepaliRhythm = [
  PlanRhythmSlot(
    id: 'morning_dal_bhat',
    nameEn: 'Morning Dal Bhat',
    nameNe: 'बिहानीको दाल भात',
    sortOrder: 1,
  ),
  PlanRhythmSlot(
    id: 'afternoon_khaja',
    nameEn: 'Afternoon Khaja',
    nameNe: 'दिउँसोको खाजा',
    sortOrder: 2,
  ),
  PlanRhythmSlot(
    id: 'evening_dal_bhat',
    nameEn: 'Evening Dal Bhat',
    nameNe: 'साँझको दाल भात',
    sortOrder: 3,
  ),
];

class Pack {
  final List<PlanRecipe> recipes;
  final List<PlanIngredient> ingredients;

  Pack(this.recipes, this.ingredients);
}

Pack loadPack() {
  const dir = '../region-packs/nepal-bagmati';

  final recipeJson =
      jsonDecode(File('$dir/recipes.json').readAsStringSync()) as List<dynamic>;
  final ingredientJson =
      jsonDecode(File('$dir/ingredients.json').readAsStringSync()) as List<dynamic>;

  final ingredients = ingredientJson
      .map((i) => PlanIngredient.fromJson(i as Map<String, dynamic>))
      .toList();

  final recipes = recipeJson.map((r) {
    final json = r as Map<String, dynamic>;
    return PlanRecipe(
      id: json['id'] as String,
      titleEn: json['titleEn'] as String,
      titleNe: json['titleNe'] as String,
      category: json['category'] as String,
      dietary: (json['dietary'] as List<dynamic>).cast<String>(),
      prepTimeMinutes: json['prepTimeMinutes'] as int,
      cookTimeMinutes: json['cookTimeMinutes'] as int,
      servings: json['servings'] as int,
      costEstimateNpr: json['costEstimateNpr'] as int,
      proteinGramsPerServing: (json['proteinGramsPerServing'] as num).toDouble(),
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((i) => PlanRecipeIngredient(
                ingredientId: (i as Map<String, dynamic>)['ingredientId'] as String,
                quantityGrams: (i['quantity'] as num).toDouble(),
              ))
          .toList(),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
    );
  }).toList();

  return Pack(recipes, ingredients);
}

AutoPlanInput baseInput(Pack pack,
    {AutoPlanGoal goal = AutoPlanGoal.seasonal,
    List<MemberAllergyProfile> allergyProfiles = const [],
    List<DietaryRule> dietaryRules = const [],
    List<PlanPantryItem> pantryItems = const [],
    List<PlanRecipe>? recipes,
    List<PlanRhythmSlot>? rhythmSlots,
    RituName? rituId,
    int? days,
    int householdServings = 4}) {
  return AutoPlanInput(
    startDateIso: '2026-10-05',
    goal: goal,
    recipes: recipes ?? pack.recipes,
    ingredients: pack.ingredients,
    rhythmSlots: rhythmSlots ?? nepaliRhythm,
    allergyProfiles: allergyProfiles,
    dietaryRules: dietaryRules,
    pantryItems: pantryItems,
    householdServings: householdServings,
    days: days ?? 7,
    rituId: rituId,
  );
}

/// The projection both engines' tests compare, matching the golden fixture's shape.
Map<String, dynamic> project(AutoPlanResult result) {
  return {
    'goal': result.goal.name,
    'startDateIso': result.startDateIso,
    'endDateIso': result.endDateIso,
    'days': result.days,
    'servings': result.servings,
    'rituId': result.rituId.name,
    'meals': [
      for (final m in result.meals)
        {
          'dateIso': m.dateIso,
          'dayIndex': m.dayIndex,
          'slotId': m.slotId,
          'recipeId': m.recipeId,
          'category': m.category,
          'isSeasonal': m.isSeasonal,
          'peakIngredientIds': m.peakIngredientIds,
          'dietaryBadges': m.dietaryBadges,
          'goalScore': m.goalScore,
          'wasteScore': m.wasteScore,
          'repeatedWithinGap': m.repeatedWithinGap,
        }
    ],
    'grocery': [
      for (final line in result.grocery)
        {
          'ingredientId': line.ingredientId,
          'totalRequiredGrams': line.totalRequiredGrams,
          'pantryAvailableGrams': line.pantryAvailableGrams,
          'netNeededGrams': line.netNeededGrams,
          'marketPackageGrams': line.marketPackageGrams,
          'packagesToBuy': line.packagesToBuy,
          'totalPurchasedGrams': line.totalPurchasedGrams,
          'surplusGrams': line.surplusGrams,
          'availability': line.availability,
          'usedByRecipeIds': line.usedByRecipeIds,
        }
    ],
    'totals': {
      'estimatedCostNpr': result.totals.estimatedCostNpr,
      'proteinGrams': result.totals.proteinGrams,
      'distinctIngredients': result.totals.distinctIngredients,
      'pantryCoveredGrams': result.totals.pantryCoveredGrams,
      'purchasedGrams': result.totals.purchasedGrams,
      'estimatedSurplusGrams': result.totals.estimatedSurplusGrams,
    },
    'exclusions': [
      for (final e in result.exclusions)
        {
          'recipeId': e.recipeId,
          'blockedAllergen': e.blockedAllergen,
          'blockedDietaryRule': e.blockedDietaryRule?.name,
        }
    ],
    'unfilledSlots': [
      for (final slot in result.unfilledSlots)
        {
          'dateIso': slot.dateIso,
          'dayIndex': slot.dayIndex,
          'slotId': slot.slotId,
        }
    ],
  };
}

void main() {
  late Pack pack;

  setUpAll(() {
    pack = loadPack();
  });

  group('Dart AutoPlan: cross-engine golden fixture parity', () {
    final goldenFile = File('../../fixtures/auto_plan_golden.json');
    late Map<String, dynamic> golden;

    setUpAll(() {
      expect(goldenFile.existsSync(), isTrue,
          reason: 'run scripts/generate_auto_plan_golden.mjs to create the shared fixture');
      golden = jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;
    });

    final mustardSevere = <MemberAllergyProfile>[
      const MemberAllergyProfile(
        allergen: AllergenCatalog.mustard,
        severity: AllergySeverity.severe,
        memberName: 'Bikram',
      )
    ];
    final dairySevere = <MemberAllergyProfile>[
      const MemberAllergyProfile(
        allergen: AllergenCatalog.milk,
        severity: AllergySeverity.severe,
        memberName: 'Sita',
      )
    ];

    Map<String, dynamic> scenario(String name) =>
        (golden['scenarios'] as Map<String, dynamic>)[name] as Map<String, dynamic>;

    void expectMatchesGolden(String name, AutoPlanInput input) {
      expect(project(generateAutoPlan(input)), equals(scenario(name)),
          reason: '$name diverged from the shared golden fixture; the two engines must agree '
              'byte for byte, so regenerate only if the change was deliberate');
    }

    test('seasonal-default matches', () {
      expectMatchesGolden('seasonal-default', baseInput(pack, goal: AutoPlanGoal.seasonal));
    });

    test('budget-default matches', () {
      expectMatchesGolden('budget-default', baseInput(pack, goal: AutoPlanGoal.budget));
    });

    test('quick-default matches', () {
      expectMatchesGolden('quick-default', baseInput(pack, goal: AutoPlanGoal.quick));
    });

    test('high-protein-default matches', () {
      expectMatchesGolden(
          'high-protein-default', baseInput(pack, goal: AutoPlanGoal.highProtein));
    });

    test('vegetarian-default matches', () {
      expectMatchesGolden(
          'vegetarian-default', baseInput(pack, goal: AutoPlanGoal.vegetarian));
    });

    test('seasonal-sharad-override matches', () {
      expectMatchesGolden(
          'seasonal-sharad-override',
          baseInput(pack, goal: AutoPlanGoal.seasonal, rituId: RituName.sharad));
    });

    test('seasonal-mustard-allergy matches', () {
      expectMatchesGolden('seasonal-mustard-allergy',
          baseInput(pack, goal: AutoPlanGoal.seasonal, allergyProfiles: mustardSevere));
    });

    test('budget-dairy-allergy-vegetarian matches', () {
      expectMatchesGolden(
          'budget-dairy-allergy-vegetarian',
          baseInput(pack,
              goal: AutoPlanGoal.budget,
              dietaryRules: const [DietaryRule.vegetarian],
              allergyProfiles: dairySevere));
    });

    test('quick-hindu-fasting matches', () {
      expectMatchesGolden(
          'quick-hindu-fasting',
          baseInput(pack,
              goal: AutoPlanGoal.quick,
              dietaryRules: const [DietaryRule.hinduFasting]));
    });

    test('seasonal-pantry-potato matches', () {
      expectMatchesGolden(
          'seasonal-pantry-potato',
          baseInput(pack,
              goal: AutoPlanGoal.seasonal,
              pantryItems: const [
                PlanPantryItem(ingredientId: 'potato', quantityGrams: 100000)
              ]));
    });

    test('seasonal-eight-servings matches', () {
      expectMatchesGolden('seasonal-eight-servings',
          baseInput(pack, goal: AutoPlanGoal.seasonal, householdServings: 8));
    });

    test('quick-single-slot-single-day matches', () {
      expectMatchesGolden(
          'quick-single-slot-single-day',
          baseInput(pack,
              goal: AutoPlanGoal.quick,
              days: 1,
              rhythmSlots: [nepaliRhythm[0]]));
    });

    test('budget-small-pool-refill matches', () {
      expectMatchesGolden(
          'budget-small-pool-refill',
          baseInput(pack,
              goal: AutoPlanGoal.budget, recipes: pack.recipes.take(4).toList()));
    });

    test('seasonal-three-days matches', () {
      expectMatchesGolden(
          'seasonal-three-days', baseInput(pack, goal: AutoPlanGoal.seasonal, days: 3));
    });
  });

  group('Dart AutoPlan: determinism', () {
    test('produces an identical plan for identical inputs', () {
      final a = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.budget));
      final b = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.budget));
      expect(project(a), equals(project(b)));
    });

    test('is unaffected by recipe input order', () {
      final forward = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.seasonal));
      final reversed = generateAutoPlan(baseInput(pack,
          goal: AutoPlanGoal.seasonal, recipes: pack.recipes.reversed.toList()));
      expect(
        forward.meals.map((m) => m.recipeId).toList(),
        equals(reversed.meals.map((m) => m.recipeId).toList()),
      );
      expect(forward.grocery.length, equals(reversed.grocery.length));
    });

    test('takes its window from the caller, not the wall clock', () {
      final result = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.quick));
      expect(result.startDateIso, equals('2026-10-05'));
      expect(result.endDateIso, equals('2026-10-11'));
      expect(result.days, equals(7));
    });

    test('renders each day in rhythm order, not alphabetical slot order', () {
      final expected = nepaliRhythm.map((s) => s.id).toList();
      expect(expected.toList()..sort(), isNot(equals(expected)),
          reason: 'fixture slot ids must disagree with sortOrder or this proves nothing');

      final result = generateAutoPlan(baseInput(pack));
      for (final day in result.meals.map((m) => m.dayIndex).toSet()) {
        final dayMeals = result.meals.where((m) => m.dayIndex == day).toList();
        expect(dayMeals.map((m) => m.slotId).toList(), equals(expected));
      }
    });
  });

  group('Dart AutoPlan: seven-day schedule shape', () {
    test('fills every slot of every day for the default rhythm', () {
      final result = generateAutoPlan(baseInput(pack));
      expect(result.meals.length, equals(21));
      expect(result.unfilledSlots, isEmpty);
      expect(result.meals.map((m) => m.dateIso).toSet().length, equals(7));
    });

    test('honours a caller-supplied slot list', () {
      final result = generateAutoPlan(baseInput(pack, rhythmSlots: [nepaliRhythm[0]]));
      expect(result.meals.length, equals(7));
      expect(result.meals.every((m) => m.slotId == 'morning_dal_bhat'), isTrue);
    });

    test('never repeats a recipe while the pool lasts', () {
      final result = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.quick));
      expect(result.meals.map((m) => m.recipeId).toSet().length, equals(21));
    });

    test('refills the pool rather than returning a starved week', () {
      final result =
          generateAutoPlan(baseInput(pack, recipes: pack.recipes.take(4).toList()));
      expect(result.meals.length, equals(21));
      expect(result.unfilledSlots, isEmpty);
      expect(result.meals.map((m) => m.recipeId).toSet().length, equals(4));
      expect(result.meals.any((m) => m.repeatedWithinGap), isTrue,
          reason: 'the rotation penalty must engage once the pool has been refilled');
    });

    test('reports unfilled slots when nothing is eligible', () {
      final result = generateAutoPlan(baseInput(pack, recipes: const []));
      expect(result.meals, isEmpty);
      expect(result.unfilledSlots.length, equals(21));
      expect(result.grocery, isEmpty);
    });

    test('scales quantities when the household outgrows the recipe servings', () {
      final result = generateAutoPlan(baseInput(pack,
          goal: AutoPlanGoal.quick, days: 1, householdServings: 8, rhythmSlots: [nepaliRhythm[0]]));
      expect(result.meals.length, equals(1));

      final meal = result.meals.first;
      final recipe = pack.recipes.firstWhere((r) => r.id == meal.recipeId);
      expect(recipe.servings, equals(4));
      expect(result.meals.first.servings, equals(8));

      for (final line in result.grocery) {
        final own = recipe.ingredients.firstWhere((i) => i.ingredientId == line.ingredientId);
        expect(line.totalRequiredGrams, closeTo(own.quantityGrams * 2, 0.001),
            reason: '${line.ingredientId} should be double for eight servings');
      }
    });
  });

  group('Dart AutoPlan: zero-miss allergy and dietary safety', () {
    test('excludes every recipe using a severe household allergen', () {
      final result = generateAutoPlan(baseInput(pack,
          allergyProfiles: const [
            MemberAllergyProfile(
              allergen: AllergenCatalog.mustard,
              severity: AllergySeverity.severe,
              memberName: 'Bikram',
            )
          ]));

      final plannedIds = result.meals.map((m) => m.recipeId).toSet();
      final mustardRecipes = pack.recipes
          .where((r) => r.ingredients.any((i) => i.ingredientId == 'mustard_oil'))
          .toList();
      expect(mustardRecipes.length, greaterThan(20));
      for (final recipe in mustardRecipes) {
        expect(plannedIds.contains(recipe.id), isFalse,
            reason: '${recipe.id} scheduled despite a severe mustard allergy');
      }
      expect(result.exclusions.length, equals(mustardRecipes.length));
    });

    test('excludes buff meat from a vegetarian household', () {
      // Regression: `buff_meat` was missing from the allergen engine's meat set, so every
      // ranga-ko-* dish passed a vegetarian, vegan or Jain check.
      final buffRecipes = pack.recipes
          .where((r) => r.ingredients.any((i) => i.ingredientId == 'buff_meat'))
          .toList();
      expect(buffRecipes, isNotEmpty);

      for (final rule in [DietaryRule.vegetarian, DietaryRule.vegan, DietaryRule.jainVegetarian]) {
        final result =
            generateAutoPlan(baseInput(pack, dietaryRules: [rule]));
        final plannedIds = result.meals.map((m) => m.recipeId).toSet();
        for (final recipe in buffRecipes) {
          expect(plannedIds.contains(recipe.id), isFalse,
              reason: '${recipe.id} scheduled under $rule');
        }
      }
    });

    test('never schedules hidden dairy when dairy is severe', () {
      final result = generateAutoPlan(baseInput(pack,
          allergyProfiles: const [
            MemberAllergyProfile(
              allergen: AllergenCatalog.milk,
              severity: AllergySeverity.severe,
              memberName: 'Sita',
            )
          ]));

      final plannedIds = result.meals.map((m) => m.recipeId).toSet();
      final dairyIds = {'ghee', 'paneer', 'milk', 'yogurt', 'chhurpi', 'cream', 'malai'};
      for (final recipe in pack.recipes) {
        if (recipe.ingredients.any((i) => dairyIds.contains(i.ingredientId))) {
          expect(plannedIds.contains(recipe.id), isFalse,
              reason: '${recipe.id} contains dairy but was scheduled');
        }
      }
    });

    test('blocks a fasting-rule violation and reports it', () {
      final result = generateAutoPlan(
          baseInput(pack, dietaryRules: const [DietaryRule.hinduFasting]));
      final plannedIds = result.meals.map((m) => m.recipeId).toSet();
      expect(plannedIds.contains('sada-bhat'), isFalse,
          reason: 'plain rice must not be planned during Vrata fasting');
      expect(result.exclusions.any((e) => e.recipeId == 'sada-bhat'), isTrue);
    });

    test('returns no meals and full exclusions when nothing is safe', () {
      final gheeRecipes = pack.recipes
          .where((r) => r.ingredients.any((i) => i.ingredientId == 'ghee'))
          .toList();
      final result = generateAutoPlan(baseInput(pack,
          recipes: gheeRecipes,
          allergyProfiles: const [
            MemberAllergyProfile(
              allergen: AllergenCatalog.milk,
              severity: AllergySeverity.severe,
            )
          ]));
      expect(result.meals, isEmpty);
      expect(result.unfilledSlots.length, equals(21));
      expect(result.exclusions.length, equals(gheeRecipes.length));
    });
  });

  group('Dart AutoPlan: goal scoring', () {
    test('quick ranks slots by non-decreasing total cook time', () {
      final result = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.quick));
      final scores = result.meals.map((m) => m.goalScore).toList();
      final sorted = [...scores]..sort();
      expect(scores, equals(sorted));
    });

    test('highProtein ranks slots by non-decreasing protein', () {
      final result = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.highProtein));
      final scores = result.meals.map((m) => m.goalScore).toList();
      final sorted = [...scores]..sort();
      expect(scores, equals(sorted));
      expect(result.totals.proteinGrams, greaterThan(0));
    });

    test('highProtein beats quick on weekly protein', () {
      final proteinWeek =
          generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.highProtein)).totals.proteinGrams;
      final quickWeek =
          generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.quick)).totals.proteinGrams;
      expect(proteinWeek, greaterThan(quickWeek));
    });

    test('budget plans a cheaper week than seasonal', () {
      final budget =
          generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.budget)).totals.estimatedCostNpr;
      final seasonal =
          generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.seasonal)).totals.estimatedCostNpr;
      expect(budget, lessThan(seasonal));
    });

    test('seasonal surfaces peak produce in sharad but not in barsha', () {
      int peakCount(RituName ritu) {
        final result = generateAutoPlan(
            baseInput(pack, goal: AutoPlanGoal.seasonal, rituId: ritu));
        return result.meals.fold<int>(0, (sum, m) => sum + m.peakIngredientIds.length);
      }

      final sharad = peakCount(RituName.sharad);
      final barsha = peakCount(RituName.barsha);
      expect(sharad, greaterThanOrEqualTo(barsha));
      expect(sharad, greaterThan(0));
    });

    test('vegetarian only schedules plant-based recipes', () {
      final result = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.vegetarian));
      final meatIds = {'goat_meat', 'buff_meat', 'chicken', 'fish'};
      for (final meal in result.meals) {
        final recipe = pack.recipes.firstWhere((r) => r.id == meal.recipeId);
        for (final item in recipe.ingredients) {
          expect(meatIds.contains(item.ingredientId), isFalse,
              reason: '${recipe.id} is not vegetarian');
        }
      }
      expect(result.exclusions, isNotEmpty);
    });
  });

  group('Dart AutoPlan: combined grocery requirements', () {
    test('aggregates each ingredient across the week', () {
      final result = generateAutoPlan(baseInput(pack, goal: AutoPlanGoal.seasonal));
      final recipeById = {for (final r in pack.recipes) r.id: r};
      final expected = <String, double>{};
      for (final meal in result.meals) {
        final recipe = recipeById[meal.recipeId]!;
        for (final item in recipe.ingredients) {
          expected[item.ingredientId] = (expected[item.ingredientId] ?? 0) +
              item.quantityGrams * result.servings / recipe.servings;
        }
      }
      expect(result.grocery.length, equals(expected.length));
      for (final line in result.grocery) {
        expect(line.totalRequiredGrams, closeTo(expected[line.ingredientId]!, 0.01),
            reason: '${line.ingredientId} weekly requirement');
      }
    });

    test('subtracts pantry stock before deciding what to buy', () {
      final result = generateAutoPlan(baseInput(pack,
          pantryItems: const [
            PlanPantryItem(ingredientId: 'potato', quantityGrams: 100000)
          ]));
      final potato = result.grocery.firstWhere((l) => l.ingredientId == 'potato');
      expect(potato.pantryAvailableGrams, equals(100000));
      expect(potato.netNeededGrams, equals(0));
      expect(potato.packagesToBuy, equals(0));
      expect(potato.totalPurchasedGrams, equals(0));
    });

    test('rounds purchases up to whole market packages', () {
      final result = generateAutoPlan(baseInput(pack));
      for (final line in result.grocery) {
        if (line.netNeededGrams <= 0) {
          expect(line.packagesToBuy, equals(0));
          continue;
        }
        expect(line.packagesToBuy,
            equals((line.netNeededGrams / line.marketPackageGrams).ceil()));
        expect(line.totalPurchasedGrams, greaterThanOrEqualTo(line.netNeededGrams));
      }
    });

    test('returns grocery sorted by ingredient id', () {
      final ids = generateAutoPlan(baseInput(pack)).grocery.map((l) => l.ingredientId).toList();
      expect(ids, equals([...ids]..sort()));
    });

    test('totals agree with the grocery lines', () {
      final result = generateAutoPlan(baseInput(pack));
      final surplus =
          result.grocery.fold<double>(0, (sum, line) => sum + line.surplusGrams);
      expect(result.totals.estimatedSurplusGrams, closeTo(surplus, 0.01));
      expect(result.totals.distinctIngredients, equals(result.grocery.length));
    });
  });

  group('Dart AutoPlan: Ritu resolution and validation', () {
    test('maps a Gregorian date onto one of the six ritus', () {
      final ritu = resolveRituId(DateTime(2026, 10, 5, 12));
      expect(RituName.values, contains(ritu));
    });

    test('reports the first day Ritu on the result', () {
      expect(
        generateAutoPlan(baseInput(pack, rituId: RituName.sharad)).rituId,
        equals(RituName.sharad),
      );
    });

    test('rejects a malformed start date', () {
      expect(
        () => generateAutoPlan(AutoPlanInput(
          startDateIso: '05-10-2026',
          goal: AutoPlanGoal.seasonal,
          recipes: pack.recipes,
          ingredients: pack.ingredients,
          rhythmSlots: nepaliRhythm,
        )),
        throwsArgumentError,
      );
    });

    test('rejects an impossible calendar date', () {
      expect(
        () => generateAutoPlan(AutoPlanInput(
          startDateIso: '2026-02-30',
          goal: AutoPlanGoal.seasonal,
          recipes: pack.recipes,
          ingredients: pack.ingredients,
          rhythmSlots: nepaliRhythm,
        )),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive day count and household size', () {
      expect(() => generateAutoPlan(baseInput(pack, days: 0)), throwsArgumentError);
      expect(() => generateAutoPlan(baseInput(pack, householdServings: 0)), throwsArgumentError);
    });
  });
}
