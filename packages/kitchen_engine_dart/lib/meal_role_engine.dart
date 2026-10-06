/// Dish roles and time-of-day suitability for region pack recipes.
///
/// A pack describes the same dish more than once: dal bhat is a breakfast main course and a
/// dinner main course, and achar is a side dish that never stands alone. Without an explicit
/// role the app has no way to tell those apart, so it happily recommends a pickle as if it
/// were a meal.
///
/// Roles are therefore declared per recipe rather than inferred from category, because
/// category (`tarkari`, `dal`, `masu`) describes the dish, not how it is eaten.
library;

import 'region_pack.dart';

/// How a dish is served.
///
/// A dish can be more than one of these: dal bhat is a main course *and* the base that a
/// side dish like achar accompanies.
enum DishRole {
  /// A complete meal on its own. The only role eligible for a meal recommendation.
  mainCourse,

  /// Served alongside a main course. Never recommended on its own, because "achar for
  /// dinner" is not a meal.
  sideDish,

  /// E.g. a rice dish that works both as the meal and as an accompaniment.
  both,
}

/// Meal times a dish is suitable for.
///
/// Kept separate from [DishRole] because the question "is this a meal?" and "when is it
/// eaten?" are different: a main course is suitable at breakfast in Nepal but rarely so in
/// another region.
enum MealTime {
  morning,
  midday,
  evening,
  night,
}

/// Utility for reading role and time metadata off a recipe.
///
/// Kept as static helpers rather than methods on `RegionRecipe` so both engine copies share
/// one definition of the rules and a recipe missing the fields still resolves to something
/// safe.
class DishRoleResolver {
  /// Parses declared dish roles, defaulting to main-course-only.
  ///
  /// A recipe with no declared roles is treated as a main course: the safe default is to
  /// keep offering the dish rather than silently hiding food from the household.
  static Set<DishRole> rolesOf(RegionRecipe recipe) {
    final declared = recipe.dishRoles;
    if (declared.isEmpty) return const {DishRole.mainCourse};

    final roles = <DishRole>{};
    for (final value in declared) {
      final role = _parseRole(value);
      if (role != null) roles.add(role);
    }

    if (roles.isEmpty) return const {DishRole.mainCourse};
    if (roles.contains(DishRole.both)) {
      return const {DishRole.mainCourse, DishRole.sideDish};
    }
    return roles;
  }

  /// Whether the dish can stand as a meal in its own right.
  static bool isMainCourse(RegionRecipe recipe) =>
      rolesOf(recipe).contains(DishRole.mainCourse);

  /// Whether the dish is meant to accompany something else.
  static bool isSideDish(RegionRecipe recipe) =>
      rolesOf(recipe).contains(DishRole.sideDish);

  /// Whether the dish is only ever an accompaniment.
  static bool isSideDishOnly(RegionRecipe recipe) =>
      !isMainCourse(recipe) && isSideDish(recipe);

  /// Meal times the dish suits, defaulting to every time when nothing is declared.
  ///
  /// An empty declaration must not mean "never", or an unclassified pack would produce an
  /// empty plan.
  static Set<MealTime> mealTimesOf(RegionRecipe recipe) {
    final declared = recipe.mealTimes;
    if (declared.isEmpty) return const {
      MealTime.morning,
      MealTime.midday,
      MealTime.evening,
      MealTime.night,
    };

    final times = <MealTime>{};
    for (final value in declared) {
      final time = _parseMealTime(value);
      if (time != null) times.add(time);
    }
    return times.isEmpty
        ? const {MealTime.morning, MealTime.midday, MealTime.evening, MealTime.night}
        : times;
  }

  /// Whether the dish is suitable at [time].
  static bool suitsMealTime(RegionRecipe recipe, MealTime time) =>
      mealTimesOf(recipe).contains(time);

  /// Recipes that may be recommended as a meal.
  ///
  /// This is the rule that keeps a side dish out of a meal slot: only a main course (or a
  /// dish that is both) qualifies.
  static List<RegionRecipe> mainsOnly(List<RegionRecipe> recipes) =>
      recipes.where(isMainCourse).toList();

  static DishRole? _parseRole(String value) {
    switch (value) {
      case 'mainCourse':
      case 'main_course':
      case 'main':
        return DishRole.mainCourse;
      case 'sideDish':
      case 'side_dish':
      case 'side':
        return DishRole.sideDish;
      case 'both':
        return DishRole.both;
      default:
        return null;
    }
  }

  static MealTime? _parseMealTime(String value) {
    switch (value) {
      case 'morning':
      case 'breakfast':
        return MealTime.morning;
      case 'midday':
      case 'lunch':
        return MealTime.midday;
      case 'evening':
      case 'snack':
        return MealTime.evening;
      case 'night':
      case 'dinner':
        return MealTime.night;
      default:
        return null;
    }
  }

  /// Maps a planner meal-slot id onto the meal times a dish may be served at.
  ///
  /// Morning and evening are merged on purpose: dal bhat is the canonical Nepali breakfast
  /// and also a dinner, so the same main course legitimately appears at both ends of the
  /// day. A side dish maps to nothing, so it can never be slotted into a meal.
  static Set<MealTime> timesForSlot(String slotId) {
    switch (slotId) {
      case 'breakfast':
      case 'morning-dal-bhat':
      case 'morning':
        return const {MealTime.morning, MealTime.evening};
      case 'lunch':
      case 'midday':
        return const {MealTime.midday};
      case 'evening-snack':
      case 'evening':
        return const {MealTime.evening};
      case 'dinner':
      case 'night':
        return const {MealTime.night};
      default:
        // An unrecognised slot does not silently exclude every dish.
        return const {
          MealTime.morning,
          MealTime.midday,
          MealTime.evening,
          MealTime.night,
        };
    }
  }

  /// Whether [recipe] may be planned into [slotId].
  ///
  /// Both conditions must hold: it must be a meal in its own right, and it must suit the
  /// time of that slot.
  static bool canBePlannedIn(RegionRecipe recipe, String slotId) {
    if (!isMainCourse(recipe)) return false;
    return timesForSlot(slotId).any((time) => suitsMealTime(recipe, time));
  }
}

/// A main course paired with side dishes to serve alongside it.
class MealSuggestion {
  final RegionRecipe mainCourse;
  final List<RegionRecipe> sideDishes;

  /// Why this pairing was offered, for display to the cook.
  final String reasonEn;
  final String reasonNe;

  const MealSuggestion({
    required this.mainCourse,
    required this.sideDishes,
    required this.reasonEn,
    required this.reasonNe,
  });
}

/// Builds meal suggestions for a slot, honouring dish roles and meal times.
///
/// Rules, in order of importance:
///  1. A side dish is never the meal. Only main courses are ever returned as `mainCourse`.
///  2. Side dishes are attached to a main, never offered on their own.
///  3. A main course must suit the time of the slot being filled.
class MealSuggestionEngine {
  /// Suggests up to [limit] meals suitable for [slotId].
  ///
  /// [seasonalityRituIds] filters to dishes whose seasonality includes the current ritu; pass
  /// an empty set to consider the whole pack. [excludedIngredientIds] removes dishes the
  /// household cannot eat, which is applied before role and time filtering so an allergen
  /// never appears even as an accompaniment.
  static List<MealSuggestion> suggest({
    required List<RegionRecipe> recipes,
    required String slotId,
    Set<String> seasonalityRituIds = const {},
    Set<String> excludedIngredientIds = const {},
    int limit = 5,
    bool preferNepali = false,
  }) {
    if (limit <= 0) return [];

    final eligibleMains = recipes.where((recipe) {
      if (!DishRoleResolver.canBePlannedIn(recipe, slotId)) return false;
      if (seasonalityRituIds.isNotEmpty &&
          !recipe.seasonality.any(seasonalityRituIds.contains)) {
        return false;
      }
      return !_usesExcludedIngredient(recipe, excludedIngredientIds);
    }).toList();

    final sideDishes = recipes.where((recipe) {
      if (!DishRoleResolver.isSideDish(recipe)) return false;
      if (seasonalityRituIds.isNotEmpty &&
          !recipe.seasonality.any(seasonalityRituIds.contains)) {
        return false;
      }
      return !_usesExcludedIngredient(recipe, excludedIngredientIds);
    }).toList();

    return eligibleMains.take(limit).map((main) {
      // Accompaniments are limited and drawn from the same filtered set, so a household
      // never has an allergen suggested next to a safe main.
      final pairings = _pairingsFor(main, sideDishes);
      return MealSuggestion(
        mainCourse: main,
        sideDishes: pairings,
        reasonEn: _reasonEn(main, slotId, pairings),
        reasonNe: _reasonNe(main, pairings),
      );
    }).toList();
  }

  /// Side dishes that go with this main course.
  ///
  /// Matching is on shared seasoning and staple ingredients rather than cuisine alone: achar
  /// goes with dal bhat because both are tempered in mustard oil and jimbu, which is the
  /// actual reason they are served together.
  static List<RegionRecipe> _pairingsFor(
    RegionRecipe main,
    List<RegionRecipe> sideDishes,
  ) {
    final mainIngredients = main.ingredients
        .map((i) => i.ingredientId.toLowerCase())
        .toSet();

    final scored = <MapEntry<RegionRecipe, int>>[];
    for (final side in sideDishes) {
      if (side.id == main.id) continue;

      var score = 0;
      for (final ingredient in side.ingredients) {
        if (mainIngredients.contains(ingredient.ingredientId.toLowerCase())) score++;
      }
      // Same category means a tarkari paired with another tarkari, which is not a pairing.
      // A penalty of 1 rather than more, so a genuinely strong shared-ingredient match still
      // survives: achar and dal bhat are both "dal"-adjacent but really go together.
      if (side.category == main.category) score -= 1;

      if (score > 0) scored.add(MapEntry(side, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(2).map((e) => e.key).toList();
  }

  static bool _usesExcludedIngredient(
    RegionRecipe recipe,
    Set<String> excludedIngredientIds,
  ) {
    if (excludedIngredientIds.isEmpty) return false;
    for (final ingredient in recipe.ingredients) {
      if (excludedIngredientIds.contains(ingredient.ingredientId)) return true;
    }
    return false;
  }

  static String _reasonEn(RegionRecipe main, String slotId, List<RegionRecipe> sides) {
    final time = switch (slotId) {
      'breakfast' || 'morning-dal-bhat' || 'morning' => 'a morning main course',
      'lunch' || 'midday' => 'a midday main course',
      'dinner' || 'night' => 'an evening main course',
      _ => 'this time of day',
    };
    if (sides.isEmpty) return 'Fits $time.';
    return 'Fits $time, with ${sides.first.titleEn} alongside.';
  }

  static String _reasonNe(RegionRecipe main, List<RegionRecipe> sides) {
    if (sides.isEmpty) return 'यो समयका लागि उपयुक्त मुख्य परिकार।';
    return '${sides.first.titleNe} सँगै खान मिल्ने मुख्य परिकार।';
  }
}