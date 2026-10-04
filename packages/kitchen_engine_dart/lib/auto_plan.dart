/// Deterministic rule-based auto-plan generator (SPECIFICATION.md Section 8.2, issue #20).
///
/// Evaluated entirely on-device: the same inputs always yield the same week. There is no
/// randomness, no wall-clock read and no reliance on iteration order — every sort ends in an
/// explicit `recipeId` tie-break, and the caller supplies the start date.
///
/// Safety is a hard constraint, not a weight. Every household member's allergies and dietary
/// rules are resolved through the allergen engine's `isAllowedInAutoPlan` verdict *before* any
/// candidate is scored, so a recipe can never be scheduled by scoring its way out of a
/// conflict. The result also reports which recipes were excluded and why, so the UI can
/// explain an empty plan instead of silently returning nothing.
///
/// `kitchen_engine_ts` mirrors this library's semantics for the Vue client and the
/// Cloudflare Workers gateway. The two are held to a shared golden fixture in their tests.
library;

import 'allergen_engine.dart';
import 'nepali_calendar.dart';
import 'region_pack.dart';

enum AutoPlanGoal { quick, budget, seasonal, highProtein, vegetarian }

/// How strongly a Ritu's availability status argues for (or against) using an ingredient.
/// Peak produce is what issue #20 asks us to prioritise; out-of-season produce is penalised
/// because it is the most expensive and least flavoursome to buy.
const Map<String, int> _availabilityWeight = {
  'peak': 4,
  'in_season': 3,
  'available': 1,
  'limited': -1,
  'out_of_season': -4,
};

class PlanIngredient {
  final String id;
  final String nameEn;
  final String nameNe;
  final int marketPackageGrams;
  final int storageDays;

  /// Availability keyed by Ritu id, values are peak / in_season / available / limited /
  /// out_of_season.
  final Map<String, String> availability;

  const PlanIngredient({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.marketPackageGrams,
    required this.storageDays,
    required this.availability,
  });

  factory PlanIngredient.fromJson(Map<String, dynamic> json) {
    return PlanIngredient(
      id: json['id'] as String,
      nameEn: json['nameEn'] as String,
      nameNe: json['nameNe'] as String,
      marketPackageGrams: json['marketPackageGrams'] as int,
      storageDays: json['storageDays'] as int,
      availability: (json['availability'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value.toString())),
    );
  }

  factory PlanIngredient.fromRegion(RegionIngredient ingredient) {
    return PlanIngredient(
      id: ingredient.id,
      nameEn: ingredient.nameEn,
      nameNe: ingredient.nameNe,
      marketPackageGrams: ingredient.marketPackageGrams,
      storageDays: ingredient.storageDays,
      availability: ingredient.availability,
    );
  }
}

class PlanRecipeIngredient {
  final String ingredientId;
  final double quantityGrams;

  const PlanRecipeIngredient({
    required this.ingredientId,
    required this.quantityGrams,
  });
}

class PlanRecipe {
  final String id;
  final String titleEn;
  final String titleNe;
  final String category;
  final List<String> dietary;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;

  /// Market cost of a single serving.
  final int costEstimateNpr;

  /// Protein grams in a single serving.
  final double proteinGramsPerServing;

  final List<PlanRecipeIngredient> ingredients;
  final List<String> tags;

  const PlanRecipe({
    required this.id,
    required this.titleEn,
    required this.titleNe,
    required this.category,
    required this.dietary,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.costEstimateNpr,
    required this.proteinGramsPerServing,
    required this.ingredients,
    this.tags = const [],
  });
}

class PlanPantryItem {
  final String ingredientId;
  final double quantityGrams;

  const PlanPantryItem({
    required this.ingredientId,
    required this.quantityGrams,
  });
}

class PlanRhythmSlot {
  final String id;
  final String nameEn;
  final String nameNe;
  final int sortOrder;

  const PlanRhythmSlot({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.sortOrder,
  });
}

class AutoPlanTuning {
  /// Days a recipe is held back after it is planned. Only reachable once the eligible pool has
  /// been refilled, which is what happens when a narrow safety filter leaves fewer recipes than
  /// the week has slots.
  final int repeatGapDays;

  const AutoPlanTuning({this.repeatGapDays = 2});
}

class AutoPlanInput {
  /// First day of the plan, as YYYY-MM-DD. Supplied by the caller so runs are reproducible.
  final String startDateIso;
  final AutoPlanGoal goal;
  final List<PlanRecipe> recipes;
  final List<PlanIngredient> ingredients;
  final List<PlanRhythmSlot> rhythmSlots;
  final List<MemberAllergyProfile> allergyProfiles;
  final List<DietaryRule> dietaryRules;
  final List<PlanPantryItem> pantryItems;

  /// Feeds the whole household; recipes are scaled to match. Defaults to 4.
  final int householdServings;

  /// Days to plan. Defaults to 7.
  final int days;

  /// Overrides the calendar-derived Ritu, for tests and offline packs without a calendar.
  final RituName? rituId;

  final AutoPlanTuning tuning;

  const AutoPlanInput({
    required this.startDateIso,
    required this.goal,
    required this.recipes,
    required this.ingredients,
    required this.rhythmSlots,
    this.allergyProfiles = const [],
    this.dietaryRules = const [],
    this.pantryItems = const [],
    this.householdServings = 4,
    this.days = 7,
    this.rituId,
    this.tuning = const AutoPlanTuning(),
  });
}

class AutoPlanScheduledMeal {
  final String dateIso;
  final int dayIndex;
  final String slotId;
  final String slotNameEn;
  final String slotNameNe;
  final String recipeId;
  final String titleEn;
  final String titleNe;
  final String category;
  final int servings;
  final bool isSeasonal;
  final List<String> peakIngredientIds;
  final List<String> dietaryBadges;

  /// Normalised 0..1 goal fit; lower is a better fit for the chosen goal.
  final double score;
  final double goalScore;
  final double wasteScore;
  final bool repeatedWithinGap;

  const AutoPlanScheduledMeal({
    required this.dateIso,
    required this.dayIndex,
    required this.slotId,
    required this.slotNameEn,
    required this.slotNameNe,
    required this.recipeId,
    required this.titleEn,
    required this.titleNe,
    required this.category,
    required this.servings,
    required this.isSeasonal,
    required this.peakIngredientIds,
    required this.dietaryBadges,
    required this.score,
    required this.goalScore,
    required this.wasteScore,
    required this.repeatedWithinGap,
  });
}

class AutoPlanGroceryLine {
  final String ingredientId;
  final String nameEn;
  final String nameNe;
  final double totalRequiredGrams;
  final double pantryAvailableGrams;
  final double netNeededGrams;
  final int marketPackageGrams;
  final int packagesToBuy;
  final double totalPurchasedGrams;
  final double surplusGrams;
  final String availability;
  final int storageDays;
  final List<String> usedByRecipeIds;

  const AutoPlanGroceryLine({
    required this.ingredientId,
    required this.nameEn,
    required this.nameNe,
    required this.totalRequiredGrams,
    required this.pantryAvailableGrams,
    required this.netNeededGrams,
    required this.marketPackageGrams,
    required this.packagesToBuy,
    required this.totalPurchasedGrams,
    required this.surplusGrams,
    required this.availability,
    required this.storageDays,
    required this.usedByRecipeIds,
  });
}

class AutoPlanExclusion {
  final String recipeId;
  final String titleEn;
  final String reason;
  final String? blockedAllergen;
  final DietaryRule? blockedDietaryRule;

  const AutoPlanExclusion({
    required this.recipeId,
    required this.titleEn,
    required this.reason,
    this.blockedAllergen,
    this.blockedDietaryRule,
  });
}

class AutoPlanTotals {
  final int estimatedCostNpr;
  final double proteinGrams;
  final int distinctIngredients;
  final double pantryCoveredGrams;
  final double purchasedGrams;
  final double estimatedSurplusGrams;

  const AutoPlanTotals({
    required this.estimatedCostNpr,
    required this.proteinGrams,
    required this.distinctIngredients,
    required this.pantryCoveredGrams,
    required this.purchasedGrams,
    required this.estimatedSurplusGrams,
  });
}

class AutoPlanResult {
  final AutoPlanGoal goal;
  final String startDateIso;
  final String endDateIso;
  final int days;
  final int servings;

  /// Ritu of the first day, for the plan header. Individual days may cross a Ritu boundary.
  final RituName rituId;

  final List<AutoPlanScheduledMeal> meals;
  final List<AutoPlanGroceryLine> grocery;
  final AutoPlanTotals totals;
  final List<AutoPlanExclusion> exclusions;

  /// Slots that no eligible recipe could fill, so callers can surface a partial week.
  final List<({String dateIso, int dayIndex, String slotId})> unfilledSlots;

  const AutoPlanResult({
    required this.goal,
    required this.startDateIso,
    required this.endDateIso,
    required this.days,
    required this.servings,
    required this.rituId,
    required this.meals,
    required this.grocery,
    required this.totals,
    required this.exclusions,
    required this.unfilledSlots,
  });
}

/// Parses YYYY-MM-DD into a local-noon DateTime: immune to timezone and DST drift.
DateTime _parseIsoDate(String iso) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (match == null) {
    throw ArgumentError('startDateIso must be YYYY-MM-DD, received "$iso"');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day, 12);
  if (date.year != year || date.month != month || date.day != day) {
    throw ArgumentError('startDateIso is not a real calendar date: "$iso"');
  }
  return date;
}

String _toIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

double _scaleToGrams(double quantityGrams, int recipeServings, int householdServings) {
  if (recipeServings <= 0) return quantityGrams;
  return quantityGrams * householdServings / recipeServings;
}

double _roundGrams(double value) => (value * 100).roundToDouble() / 100;

/// Min-max normalisation onto 0..1. A flat input collapses to 0 so it never skews a tie-break.
List<double> _normalise(List<double> values) {
  if (values.isEmpty) return const [];
  var min = values.first;
  var max = values.first;
  for (final value in values) {
    if (value < min) min = value;
    if (value > max) max = value;
  }
  if (max == min) return List<double>.filled(values.length, 0);
  return values.map((value) => (value - min) / (max - min)).toList();
}

String _availabilityOf(PlanIngredient? ingredient, RituName rituId) {
  final raw = ingredient?.availability[rituId.name];
  if (raw == null) return 'available';
  return raw;
}

/// The single place a Ritu is derived, so the TypeScript engine can mirror one rule.
RituName resolveRituId(DateTime date) {
  return NepaliCalendar.getRituForBsMonth(NepaliCalendar.gregorianToBs(date).month).id;
}

class _SeasonSummary {
  final int weightedScore;
  final List<String> peakIngredientIds;

  const _SeasonSummary(this.weightedScore, this.peakIngredientIds);
}

_SeasonSummary _summariseSeason(
  PlanRecipe recipe,
  Map<String, PlanIngredient> ingredientById,
  RituName rituId,
) {
  final peakIngredientIds = <String>[];
  var weightedScore = 0;

  for (final item in recipe.ingredients) {
    final ingredient = ingredientById[item.ingredientId];
    if (ingredient == null) continue;
    final availability = _availabilityOf(ingredient, rituId);
    weightedScore += _availabilityWeight[availability] ?? 0;
    if (availability == 'peak') peakIngredientIds.add(item.ingredientId);
  }

  peakIngredientIds.sort();
  return _SeasonSummary(weightedScore, peakIngredientIds);
}

/// Hard gate for the vegetarian goal, independent of any household dietary rules.
bool _isPlantBased(PlanRecipe recipe) {
  return recipe.dietary.contains('vegetarian') ||
      recipe.dietary.contains('vegan') ||
      recipe.dietary.contains('lacto-vegetarian') ||
      recipe.dietary.contains('jain-vegetarian');
}

/// Raw goal score; lower is better. Scales are normalised later so the ordering stays
/// comparable across goals whose units differ (minutes, rupees, signed availability).
double _rawGoalScore(
  AutoPlanGoal goal,
  PlanRecipe recipe,
  _SeasonSummary season,
) {
  switch (goal) {
    case AutoPlanGoal.quick:
      return (recipe.prepTimeMinutes + recipe.cookTimeMinutes).toDouble();
    case AutoPlanGoal.budget:
      return recipe.costEstimateNpr.toDouble();
    case AutoPlanGoal.seasonal:
      return -season.weightedScore.toDouble();
    case AutoPlanGoal.highProtein:
      return -recipe.proteinGramsPerServing;
    case AutoPlanGoal.vegetarian:
      // Affordable plant food: the vegetarian gate above guarantees plant-based, so cost is
      // the discriminator and protein density would just re-run the highProtein goal.
      return recipe.costEstimateNpr.toDouble();
  }
}

class _Candidate {
  final PlanRecipe recipe;
  _SeasonSummary season;

  _Candidate(this.recipe, this.season);
}

/// Lexicographic comparison of a ranking key; the id makes the order total.
int _compareKeys(List<Object> a, List<Object> b) {
  for (var index = 0; index < 3; index++) {
    final left = a[index] as double;
    final right = b[index] as double;
    if (left != right) return left < right ? -1 : 1;
  }
  final leftId = a[3] as String;
  final rightId = b[3] as String;
  if (leftId == rightId) return 0;
  return leftId.compareTo(rightId);
}

/// Builds a seven-day schedule against the household's safety constraints.
///
/// Slots are filled in a fixed order (day ascending, then slot sort order). Each slot takes the
/// best remaining candidate, ranked lexicographically by:
///
///   1. goal fit (normalised 0..1, lower is better)
///   2. waste — the share of grams already in the pantry or committed earlier in the week
///   3. rotation — a penalty for reusing a recipe inside `repeatGapDays`
///   4. recipe id — the tie-break that makes the whole ordering total
///
/// The goal leads deliberately. Issue #20 lists allergy safety, waste and seasonality as
/// constraints *within* a goal, so blending them into one weighted number would let waste
/// quietly outvote what the user actually asked for. Because cost, time and availability are
/// small integers, ties are common and the waste term decides most of them in practice.
///
/// Each recipe is used at most once while the pool lasts, which is what gives a generated week
/// its variety. When a narrow safety filter leaves fewer recipes than the week has slots, the
/// pool refills and the rotation penalty starts applying.
AutoPlanResult generateAutoPlan(AutoPlanInput input) {
  final tuning = input.tuning;
  final days = input.days;
  final servings = input.householdServings;

  if (days <= 0) {
    throw ArgumentError('days must be positive, received $days');
  }
  if (servings <= 0) {
    throw ArgumentError('householdServings must be positive, received $servings');
  }

  final startDate = _parseIsoDate(input.startDateIso);
  final dates = <DateTime>[
    for (var offset = 0; offset < days; offset++)
      startDate.add(Duration(days: offset)),
  ];

  final ingredientById = <String, PlanIngredient>{
    for (final ingredient in input.ingredients) ingredient.id: ingredient,
  };

  final slots = [...input.rhythmSlots]..sort((a, b) {
        if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
        return a.id.compareTo(b.id);
      });

  // --- Safety gate. Nothing below this point can reintroduce an excluded recipe. ---
  final exclusions = <AutoPlanExclusion>[];
  final candidates = <_Candidate>[];

  for (final recipe in input.recipes) {
    final verdict = AllergenEngine.checkRecipeSafety(
      ingredientIds: recipe.ingredients.map((i) => i.ingredientId).toList(),
      allergyProfiles: input.allergyProfiles,
      dietaryRules: input.dietaryRules,
    );

    if (!verdict.isAllowedInAutoPlan) {
      final first = verdict.conflicts.isEmpty ? null : verdict.conflicts.first;
      exclusions.add(AutoPlanExclusion(
        recipeId: recipe.id,
        titleEn: recipe.titleEn,
        reason: first?.reason ?? 'Blocked by a household safety constraint.',
        blockedAllergen: first?.allergen,
        blockedDietaryRule: first?.dietaryRule,
      ));
      continue;
    }

    if (input.goal == AutoPlanGoal.vegetarian && !_isPlantBased(recipe)) {
      exclusions.add(AutoPlanExclusion(
        recipeId: recipe.id,
        titleEn: recipe.titleEn,
        reason: 'Not plant-based, so it cannot satisfy the Vegetarian goal.',
      ));
      continue;
    }

    candidates.add(_Candidate(recipe, const _SeasonSummary(0, [])));
  }

  exclusions.sort((a, b) => a.recipeId.compareTo(b.recipeId));
  final eligible = [...candidates];

  final pantryGrams = <String, double>{};
  for (final item in input.pantryItems) {
    pantryGrams[item.ingredientId] =
        (pantryGrams[item.ingredientId] ?? 0) + item.quantityGrams;
  }

  /// Grams of each ingredient already spoken for, by the pantry or an earlier slot this week.
  final committedGrams = <String, double>{...pantryGrams};
  final lastPlannedDay = <String, int>{};
  final meals = <AutoPlanScheduledMeal>[];
  final unfilledSlots = <({String dateIso, int dayIndex, String slotId})>[];

  for (var dayIndex = 0; dayIndex < days; dayIndex++) {
    final date = dates[dayIndex];
    final dateIso = _toIsoDate(date);
    final rituId = input.rituId ?? resolveRituId(date);

    for (final slot in slots) {
      // Variety first: each recipe is planned once. A narrow safety filter can leave fewer
      // recipes than slots, so refill rather than return a starved week.
      if (candidates.isEmpty) {
        if (eligible.isEmpty) {
          unfilledSlots.add((dateIso: dateIso, dayIndex: dayIndex, slotId: slot.id));
          continue;
        }
        candidates.addAll(eligible);
      }

      for (final candidate in candidates) {
        candidate.season = _summariseSeason(candidate.recipe, ingredientById, rituId);
      }

      final goalScores =
          candidates.map((c) => _rawGoalScore(input.goal, c.recipe, c.season)).toList();
      final normalisedGoal = _normalise(goalScores);

      // Waste term: the share of this recipe's scaled grams that the household already has
      // in the pantry or has committed to earlier in the week. Higher is less waste.
      final wasteRatios = <double>[];
      for (final candidate in candidates) {
        var total = 0.0;
        var reused = 0.0;
        for (final item in candidate.recipe.ingredients) {
          final grams =
              _scaleToGrams(item.quantityGrams, candidate.recipe.servings, servings);
          total += grams;
          final available = committedGrams[item.ingredientId] ?? 0;
          if (available > 0) {
            reused += grams < available ? grams : available;
          }
        }
        wasteRatios.add(total > 0 ? reused / total : 0);
      }

      var bestIndex = 0;
      List<Object>? bestKey;
      for (var index = 0; index < candidates.length; index++) {
        final candidate = candidates[index];
        final previousDay = lastPlannedDay[candidate.recipe.id];
        final repeatedWithinGap = previousDay != null &&
            dayIndex - previousDay <= tuning.repeatGapDays;

        final key = <Object>[
          normalisedGoal[index],
          1 - wasteRatios[index],
          repeatedWithinGap ? 1.0 : 0.0,
          candidate.recipe.id,
        ];

        if (bestKey == null || _compareKeys(key, bestKey) < 0) {
          bestIndex = index;
          bestKey = key;
        }
      }

      final chosen = candidates.removeAt(bestIndex);

      // Read the previous occurrence before recording this one, otherwise the gap is always 0.
      final previousDay = lastPlannedDay[chosen.recipe.id];
      final repeatedWithinGap = previousDay != null &&
          dayIndex - previousDay <= tuning.repeatGapDays;
      lastPlannedDay[chosen.recipe.id] = dayIndex;

      for (final item in chosen.recipe.ingredients) {
        final grams = _scaleToGrams(item.quantityGrams, chosen.recipe.servings, servings);
        committedGrams[item.ingredientId] = (committedGrams[item.ingredientId] ?? 0) + grams;
      }

      meals.add(AutoPlanScheduledMeal(
        dateIso: dateIso,
        dayIndex: dayIndex,
        slotId: slot.id,
        slotNameEn: slot.nameEn,
        slotNameNe: slot.nameNe,
        recipeId: chosen.recipe.id,
        titleEn: chosen.recipe.titleEn,
        titleNe: chosen.recipe.titleNe,
        category: chosen.recipe.category,
        servings: servings,
        isSeasonal: chosen.season.peakIngredientIds.isNotEmpty,
        peakIngredientIds: chosen.season.peakIngredientIds,
        dietaryBadges: [...chosen.recipe.dietary]..sort(),
        score: _roundGrams(normalisedGoal[bestIndex]),
        goalScore: _roundGrams(goalScores[bestIndex]),
        wasteScore: _roundGrams(wasteRatios[bestIndex]),
        repeatedWithinGap: repeatedWithinGap,
      ));
    }
  }

  // Render in the household's rhythm order, not alphabetical slot id, so a day reads
  // morning-first even when the slot ids sort differently.
  final slotOrder = <String, int>{
    for (var index = 0; index < slots.length; index++) slots[index].id: index,
  };
  meals.sort((a, b) {
    final byDay = a.dayIndex.compareTo(b.dayIndex);
    if (byDay != 0) return byDay;
    final bySlot = (slotOrder[a.slotId] ?? 0).compareTo(slotOrder[b.slotId] ?? 0);
    if (bySlot != 0) return bySlot;
    return a.slotId.compareTo(b.slotId);
  });

  // --- Combined grocery requirement across the whole week. ---
  final recipeById = <String, PlanRecipe>{
    for (final recipe in input.recipes) recipe.id: recipe,
  };
  final required = <String, double>{};
  final usedBy = <String, Set<String>>{};
  for (final meal in meals) {
    final recipe = recipeById[meal.recipeId];
    if (recipe == null) continue;
    for (final item in recipe.ingredients) {
      final grams = _scaleToGrams(item.quantityGrams, recipe.servings, servings);
      required[item.ingredientId] = (required[item.ingredientId] ?? 0) + grams;
      (usedBy[item.ingredientId] ??= <String>{}).add(recipe.id);
    }
  }

  final firstRituId = input.rituId ?? resolveRituId(dates.first);
  final grocery = <AutoPlanGroceryLine>[];

  final requiredIds = required.keys.toList()..sort();
  for (final ingredientId in requiredIds) {
    final ingredient = ingredientById[ingredientId];
    final totalRequiredGrams = _roundGrams(required[ingredientId] ?? 0);
    final pantryAvailableGrams = _roundGrams(pantryGrams[ingredientId] ?? 0);
    final netNeededGrams = _roundGrams(
      (totalRequiredGrams - pantryAvailableGrams).clamp(0, double.infinity),
    );

    // An ingredient the pack does not describe still belongs on the list; fall back to a
    // 250 g market package so the shopper is told to buy something rather than nothing.
    final marketPackageGrams =
        (ingredient != null && ingredient.marketPackageGrams > 0)
            ? ingredient.marketPackageGrams
            : 250;
    final packagesToBuy =
        netNeededGrams > 0 ? (netNeededGrams / marketPackageGrams).ceil() : 0;
    final totalPurchasedGrams = packagesToBuy * marketPackageGrams.toDouble();

    grocery.add(AutoPlanGroceryLine(
      ingredientId: ingredientId,
      nameEn: ingredient?.nameEn ?? ingredientId,
      nameNe: ingredient?.nameNe ?? ingredientId,
      totalRequiredGrams: totalRequiredGrams,
      pantryAvailableGrams: pantryAvailableGrams,
      netNeededGrams: netNeededGrams,
      marketPackageGrams: marketPackageGrams,
      packagesToBuy: packagesToBuy,
      totalPurchasedGrams: totalPurchasedGrams,
      surplusGrams: _roundGrams(
        (pantryAvailableGrams + totalPurchasedGrams - totalRequiredGrams).clamp(0, double.infinity),
      ),
      availability: _availabilityOf(ingredient, firstRituId),
      storageDays: ingredient?.storageDays ?? 0,
      usedByRecipeIds: (usedBy[ingredientId] ?? const <String>{}).toList()..sort(),
    ));
  }

  var estimatedCostNpr = 0.0;
  var proteinGrams = 0.0;
  for (final meal in meals) {
    final recipe = recipeById[meal.recipeId];
    if (recipe == null) continue;
    estimatedCostNpr += recipe.costEstimateNpr * servings;
    proteinGrams += recipe.proteinGramsPerServing * servings;
  }

  var pantryCoveredGrams = 0.0;
  var purchasedGrams = 0.0;
  var estimatedSurplusGrams = 0.0;
  for (final line in grocery) {
    pantryCoveredGrams +=
        line.pantryAvailableGrams < line.totalRequiredGrams
            ? line.pantryAvailableGrams
            : line.totalRequiredGrams;
    purchasedGrams += line.totalPurchasedGrams;
    estimatedSurplusGrams += line.surplusGrams;
  }

  return AutoPlanResult(
    goal: input.goal,
    startDateIso: _toIsoDate(dates.first),
    endDateIso: _toIsoDate(dates[days - 1]),
    days: days,
    servings: servings,
    rituId: firstRituId,
    meals: meals,
    grocery: grocery,
    totals: AutoPlanTotals(
      estimatedCostNpr: estimatedCostNpr.round(),
      proteinGrams: _roundGrams(proteinGrams),
      distinctIngredients: grocery.length,
      pantryCoveredGrams: _roundGrams(pantryCoveredGrams),
      purchasedGrams: _roundGrams(purchasedGrams),
      estimatedSurplusGrams: _roundGrams(estimatedSurplusGrams),
    ),
    exclusions: exclusions,
    unfilledSlots: unfilledSlots,
  );
}
