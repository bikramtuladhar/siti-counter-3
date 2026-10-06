import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

RegionRecipe makeRecipe({
  required String id,
  String category = 'dal',
  List<String> dishRoles = const [],
  List<String> mealTimes = const [],
  List<String> seasonality = const [],
  List<String> ingredients = const [],
  int prepMinutes = 10,
  int cookMinutes = 20,
}) {
  return RegionRecipe(
    id: id,
    titleEn: id,
    titleNe: id,
    category: category,
    cuisine: 'nepali',
    dietary: const [],
    prepTimeMinutes: prepMinutes,
    cookTimeMinutes: cookMinutes,
    servings: 4,
    difficulty: 'easy',
    pressureCooker: const RecipeWhistleProfile(
      enabled: false,
      recommendedWhistles: 0,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'low',
      releaseType: 'quick',
    ),
    elevationBand: const RecipeElevationBand(
      testedElevationMeters: 1400,
      boilingPointCelsius: 95.3,
      waterMultiplier: 1.0,
    ),
    ingredients: [
      for (final ingredientId in ingredients)
        RecipeIngredientItem(ingredientId: ingredientId, quantity: 100, unit: 'g'),
    ],
    steps: const [],
    seasonality: seasonality,
    tags: const [],
    dishRoles: dishRoles,
    mealTimes: mealTimes,
  );
}

void main() {
  group('DishRoleResolver — roles', () {
    test('a recipe with no declared roles is treated as a main course', () {
      final recipe = makeRecipe(id: 'plain');
      expect(DishRoleResolver.isMainCourse(recipe), isTrue);
      expect(DishRoleResolver.isSideDish(recipe), isFalse);
    });

    test('a declared side dish is not a main course', () {
      final achar = makeRecipe(id: 'achar', dishRoles: ['sideDish']);
      expect(DishRoleResolver.isMainCourse(achar), isFalse);
      expect(DishRoleResolver.isSideDish(achar), isTrue);
      expect(DishRoleResolver.isSideDishOnly(achar), isTrue);
    });

    test('"both" means it can be served either way', () {
      final rice = makeRecipe(id: 'rice', dishRoles: ['both']);
      expect(DishRoleResolver.isMainCourse(rice), isTrue);
      expect(DishRoleResolver.isSideDish(rice), isTrue);
      expect(DishRoleResolver.isSideDishOnly(rice), isFalse);
    });

    test('unknown role strings fall back to main course rather than hiding food', () {
      final recipe = makeRecipe(id: 'odd', dishRoles: ['nonsense']);
      expect(DishRoleResolver.isMainCourse(recipe), isTrue);
    });

    test('snake_case and short forms are accepted', () {
      expect(
        DishRoleResolver.isSideDish(makeRecipe(id: 'a', dishRoles: ['side_dish'])),
        isTrue,
      );
      expect(
        DishRoleResolver.isSideDish(makeRecipe(id: 'b', dishRoles: ['side'])),
        isTrue,
      );
    });
  });

  group('DishRoleResolver — meal times', () {
    test('no declared times means every time', () {
      final recipe = makeRecipe(id: 'any');
      for (final time in MealTime.values) {
        expect(DishRoleResolver.suitsMealTime(recipe, time), isTrue);
      }
    });

    test('declared times are honoured', () {
      final breakfastOnly = makeRecipe(id: 'b', mealTimes: ['morning']);
      expect(DishRoleResolver.suitsMealTime(breakfastOnly, MealTime.morning), isTrue);
      expect(DishRoleResolver.suitsMealTime(breakfastOnly, MealTime.night), isFalse);
    });

    test('breakfast is morning only', () {
      // A dish that suits breakfast declares the morning tag. Merging evening into breakfast
      // made every evening-only dish, such as masu, a breakfast suggestion.
      expect(DishRoleResolver.timesForSlot('breakfast'), {MealTime.morning});
      expect(DishRoleResolver.timesForSlot('dinner'), {MealTime.night});
    });

    test('an evening-only main course is not a breakfast option', () {
      final masu = makeRecipe(
        id: 'masu',
        mealTimes: ['midday', 'evening', 'night'],
      );
      expect(DishRoleResolver.canBePlannedIn(masu, 'breakfast'), isFalse);
      expect(DishRoleResolver.canBePlannedIn(masu, 'dinner'), isTrue);
    });

    test('an unknown slot does not exclude every dish', () {
      final times = DishRoleResolver.timesForSlot('brunch-thing');
      expect(times.length, MealTime.values.length);
    });
  });

  group('MealSuggestionEngine — ranking', () {
    test('prefers the dish closest to the slot\'s time budget', () {
      final quick = makeRecipe(
        id: 'quick',
        mealTimes: ['morning', 'night'],
        prepMinutes: 5,
        cookMinutes: 10, // 15 minutes total
      );
      final moderate = makeRecipe(
        id: 'moderate',
        mealTimes: ['morning', 'night'],
        prepMinutes: 20,
        cookMinutes: 30, // 50 minutes total
      );
      final verySlow = makeRecipe(
        id: 'very_slow',
        mealTimes: ['morning', 'night'],
        prepMinutes: 30,
        cookMinutes: 120, // 150 minutes total
      );

      // Listed worst-first on purpose: suggestions must be ranked, not returned in pack
      // order, or the same recipes get offered at every meal of the day.
      final recipes = [verySlow, moderate, quick];

      // Breakfast wants ~30 minutes, so the quick dish wins.
      expect(
        MealSuggestionEngine.suggest(recipes: recipes, slotId: 'breakfast')
            .first
            .mainCourse
            .id,
        'quick',
      );

      // Dinner allows ~60, so the dish closest to that budget wins instead. A 150-minute
      // dish is not a better dinner than a 50-minute one, it is just further from the goal.
      expect(
        MealSuggestionEngine.suggest(recipes: recipes, slotId: 'dinner')
            .first
            .mainCourse
            .id,
        'moderate',
      );
    });

    test('ranking is stable across repeated calls', () {
      final recipes = [
        for (final id in ['a', 'b', 'c', 'd'])
          makeRecipe(id: id, mealTimes: ['morning'], prepMinutes: 5, cookMinutes: 5),
      ];

      final first = MealSuggestionEngine.suggest(recipes: recipes, slotId: 'breakfast');
      final second = MealSuggestionEngine.suggest(recipes: recipes, slotId: 'breakfast');

      expect(
        first.map((m) => m.mainCourse.id).toList(),
        second.map((m) => m.mainCourse.id).toList(),
      );
    });

    test('a tied pair keeps a deterministic order', () {
      final recipes = [
        makeRecipe(id: 'zebra', mealTimes: ['morning']),
        makeRecipe(id: 'apple', mealTimes: ['morning']),
      ];

      final out = MealSuggestionEngine.suggest(recipes: recipes, slotId: 'breakfast');
      expect(out.map((m) => m.mainCourse.id).toList(), ['apple', 'zebra']);
    });
  });

  group('DishRoleResolver — planning rules', () {
    test('a side dish can never be planned into a meal slot', () {
      final achar = makeRecipe(id: 'achar', dishRoles: ['sideDish']);
      for (final slot in ['breakfast', 'lunch', 'dinner', 'evening-snack']) {
        expect(
          DishRoleResolver.canBePlannedIn(achar, slot),
          isFalse,
          reason: 'achar must never be planned into $slot',
        );
      }
    });

    test('a main course suited to morning can be planned at breakfast and dinner', () {
      final dalBhat = makeRecipe(
        id: 'dal-bhat',
        dishRoles: ['mainCourse'],
        mealTimes: ['morning', 'evening', 'night'],
      );
      expect(DishRoleResolver.canBePlannedIn(dalBhat, 'breakfast'), isTrue);
      expect(DishRoleResolver.canBePlannedIn(dalBhat, 'dinner'), isTrue);
    });

    test('a midday-only main is excluded from dinner', () {
      final lunchOnly = makeRecipe(
        id: 'lunch-only',
        mealTimes: ['midday'],
      );
      expect(DishRoleResolver.canBePlannedIn(lunchOnly, 'lunch'), isTrue);
      expect(DishRoleResolver.canBePlannedIn(lunchOnly, 'dinner'), isFalse);
    });

    test('mainsOnly excludes every side-dish-only recipe', () {
      final recipes = [
        makeRecipe(id: 'dal-bhat'),
        makeRecipe(id: 'achar', dishRoles: ['sideDish']),
        makeRecipe(id: 'tarkari'),
        makeRecipe(id: 'chutney', dishRoles: ['sideDish']),
      ];

      final mains = DishRoleResolver.mainsOnly(recipes);
      expect(mains.map((r) => r.id), ['dal-bhat', 'tarkari']);
    });
  });

  group('MealSuggestionEngine', () {
    test('never returns a side dish as the meal', () {
      final recipes = [
        makeRecipe(id: 'dal-bhat'),
        makeRecipe(id: 'achar', dishRoles: ['sideDish']),
        makeRecipe(id: 'chutney', dishRoles: ['sideDish']),
        makeRecipe(id: 'pickle', dishRoles: ['sideDish']),
      ];

      final suggestions = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
      );

      expect(suggestions.map((s) => s.mainCourse.id), ['dal-bhat']);
      for (final suggestion in suggestions) {
        expect(DishRoleResolver.isMainCourse(suggestion.mainCourse), isTrue);
      }
    });

    test('returns nothing when the pack is all side dishes', () {
      final suggestions = MealSuggestionEngine.suggest(
        recipes: [
          makeRecipe(id: 'achar', dishRoles: ['sideDish']),
          makeRecipe(id: 'chutney', dishRoles: ['sideDish']),
        ],
        slotId: 'dinner',
      );

      expect(suggestions, isEmpty);
    });

    test('respects the slot time', () {
      final recipes = [
        makeRecipe(id: 'breakfast-dish', mealTimes: ['morning', 'evening']),
        makeRecipe(id: 'dinner-only', mealTimes: ['night']),
      ];

      final breakfast = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'breakfast',
      );
      expect(breakfast.map((s) => s.mainCourse.id), ['breakfast-dish']);

      final dinner = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
      );
      expect(dinner.map((s) => s.mainCourse.id), ['dinner-only']);
    });

    test('honours the limit', () {
      final recipes = [
        makeRecipe(id: 'a'),
        makeRecipe(id: 'b'),
        makeRecipe(id: 'c'),
        makeRecipe(id: 'd'),
      ];

      final suggestions = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
        limit: 2,
      );
      expect(suggestions.length, 2);
    });

    test('a zero or negative limit yields nothing', () {
      final recipes = [makeRecipe(id: 'a')];
      expect(
        MealSuggestionEngine.suggest(recipes: recipes, slotId: 'dinner', limit: 0),
        isEmpty,
      );
    });

    test('filters by seasonality only when a ritu is supplied', () {
      final recipes = [
        makeRecipe(id: 'sharad-dish', seasonality: ['sharad']),
        makeRecipe(id: 'hemant-dish', seasonality: ['hemant']),
      ];

      final unfiltered = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
      );
      expect(unfiltered.length, 2);

      final filtered = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
        seasonalityRituIds: {'sharad'},
      );
      expect(filtered.map((s) => s.mainCourse.id), ['sharad-dish']);
    });

    test('an excluded ingredient removes the dish entirely, not just as a main', () {
      final recipes = [
        makeRecipe(id: 'dal-bhat', ingredients: ['mustard_oil']),
        makeRecipe(id: 'achar', category: 'achar', dishRoles: ['sideDish'], ingredients: ['mustard_oil']),
        makeRecipe(id: 'tarkari', ingredients: ['cauliflower']),
      ];

      final suggestions = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
        excludedIngredientIds: {'mustard_oil'},
      );

      expect(suggestions.map((s) => s.mainCourse.id), ['tarkari']);
      // The allergen must not reappear as an accompaniment either.
      for (final suggestion in suggestions) {
        expect(
          suggestion.sideDishes.map((s) => s.id),
          isNot(contains('achar')),
        );
      }
    });

    test('pairs a side dish that shares seasoning with the main', () {
      final recipes = [
        makeRecipe(
          id: 'dal-bhat',
          ingredients: ['mustard_oil', 'jimbu', 'masala'],
        ),
        makeRecipe(
          id: 'achar',
          category: 'achar',
          dishRoles: ['sideDish'],
          ingredients: ['mustard_oil', 'jimbu'],
        ),
        makeRecipe(
          id: 'unrelated-achar',
          category: 'achar',
          dishRoles: ['sideDish'],
          ingredients: ['coconut'],
        ),
      ];

      final suggestions = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
      );

      expect(suggestions.length, 1);
      final sides = suggestions.first.sideDishes.map((s) => s.id).toList();
      // Shared mustard oil and jimbu is the real reason they are served together.
      expect(sides, contains('achar'));
      expect(sides, isNot(contains('unrelated-achar')));
    });

    test('a same-category side dish is penalised as a pairing', () {
      final recipes = [
        makeRecipe(id: 'main-tarkari', category: 'tarkari', ingredients: ['cauliflower']),
        makeRecipe(
          id: 'side-tarkari',
          category: 'tarkari',
          dishRoles: ['both'],
          ingredients: ['cauliflower'],
        ),
      ];

      final suggestions = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
      );

      expect(suggestions.first.sideDishes, isEmpty);
    });

    test('a side dish never pairs with itself', () {
      final recipes = [
        makeRecipe(id: 'achar', dishRoles: ['both'], ingredients: ['mustard_oil']),
      ];

      final suggestions = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
      );
      expect(suggestions.first.sideDishes.map((s) => s.id), isNot(contains('achar')));
    });

    test('suggestions explain themselves', () {
      final recipes = [
        makeRecipe(id: 'dal-bhat', ingredients: ['mustard_oil']),
        makeRecipe(
          id: 'achar',
          category: 'achar',
          dishRoles: ['sideDish'],
          ingredients: ['mustard_oil'],
        ),
      ];

      final suggestion = MealSuggestionEngine.suggest(
        recipes: recipes,
        slotId: 'dinner',
      ).first;

      expect(suggestion.reasonEn, contains('achar'));
      expect(suggestion.reasonNe, isNotEmpty);
    });
  });

  group('RegionRecipe serialisation of the new fields', () {
    test('roles and times survive a JSON round trip', () {
      final recipe = makeRecipe(
        id: 'round-trip',
        dishRoles: ['both'],
        mealTimes: ['morning', 'night'],
      );

      final restored = RegionRecipe.fromJson({
        'id': recipe.id,
        'titleEn': recipe.titleEn,
        'titleNe': recipe.titleNe,
        'category': recipe.category,
        'cuisine': recipe.cuisine,
        'dietary': <String>[],
        'prepTimeMinutes': 10,
        'cookTimeMinutes': 20,
        'servings': 4,
        'difficulty': 'easy',
        'pressureCooker': const {
          'enabled': false,
          'recommendedWhistles': 0,
          'altitudeWhistleOffsetKathmandu': 0,
          'heatLevel': 'low',
          'releaseType': 'quick',
        },
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'seasonality': <String>[],
        'tags': <String>[],
        'dishRoles': ['both'],
        'mealTimes': ['morning', 'night'],
      });

      expect(restored.dishRoles, ['both']);
      expect(restored.mealTimes, ['morning', 'night']);
      expect(DishRoleResolver.isSideDish(restored), isTrue);
      expect(DishRoleResolver.isMainCourse(restored), isTrue);
    });

    test('older packs without the fields load unchanged', () {
      final restored = RegionRecipe.fromJson({
        'id': 'legacy',
        'titleEn': 'Legacy',
        'titleNe': 'पुरानो',
        'category': 'dal',
        'cuisine': 'nepali',
        'dietary': <String>[],
        'prepTimeMinutes': 10,
        'cookTimeMinutes': 20,
        'servings': 4,
        'difficulty': 'easy',
        'pressureCooker': const {
          'enabled': false,
          'recommendedWhistles': 0,
          'altitudeWhistleOffsetKathmandu': 0,
          'heatLevel': 'low',
          'releaseType': 'quick',
        },
        'ingredients': <dynamic>[],
        'steps': <dynamic>[],
        'seasonality': <String>[],
        'tags': <String>[],
      });

      expect(restored.dishRoles, isEmpty);
      expect(restored.mealTimes, isEmpty);
      // Backwards compatible: an unclassified recipe is still a main course.
      expect(DishRoleResolver.isMainCourse(restored), isTrue);
    });
  });
}