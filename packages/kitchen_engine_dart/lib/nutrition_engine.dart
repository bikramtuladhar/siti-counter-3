import 'consumption_engine.dart';
import 'region_pack.dart';
import 'unit_conversion.dart';

/// Source table a composition row is drawn from.
/// Where a composition row's values came from.
enum CompositionSource {
  nfct,
  ifct,

  /// USDA FoodData Central, a US Government work and therefore public domain.
  usda,
}

/// Nutrient composition per 100 g of the RAW ingredient
/// (Nepal Food Composition Table / Indian Food Composition Tables).
class FoodComposition {
  final String id;
  final String nameEn;
  final String nameNe;
  final String foodGroup; // grains, pulses, vegetables, fruits, dairy, protein, fats
  final double kcal;
  final double proteinG;
  final double fiberG;
  final double carbsG;
  final double fatG;
  final CompositionSource source;

  const FoodComposition({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.foodGroup,
    required this.kcal,
    required this.proteinG,
    required this.fiberG,
    required this.carbsG,
    required this.fatG,
    this.source = CompositionSource.nfct,
  });
}

/// Raw -> cooked weight factor (cooked grams per raw gram).
class YieldFactor {
  final String ingredientId;
  final double factor;
  final String method;

  const YieldFactor({
    required this.ingredientId,
    required this.factor,
    required this.method,
  });
}

/// Additive nutrient totals.
class NutrientTotals {
  final double grams;
  final double kcal;
  final double proteinG;
  final double fiberG;
  final double carbsG;
  final double fatG;

  const NutrientTotals({
    this.grams = 0,
    this.kcal = 0,
    this.proteinG = 0,
    this.fiberG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  static const zero = NutrientTotals();

  NutrientTotals operator +(NutrientTotals o) => NutrientTotals(
        grams: grams + o.grams,
        kcal: kcal + o.kcal,
        proteinG: proteinG + o.proteinG,
        fiberG: fiberG + o.fiberG,
        carbsG: carbsG + o.carbsG,
        fatG: fatG + o.fatG,
      );

  NutrientTotals scale(double k) => NutrientTotals(
        grams: grams * k,
        kcal: kcal * k,
        proteinG: proteinG * k,
        fiberG: fiberG * k,
        carbsG: carbsG * k,
        fatG: fatG * k,
      );
}

/// One raw ingredient going into a batch.
class BatchIngredient {
  final String ingredientId;
  final double rawGrams;
  const BatchIngredient(this.ingredientId, this.rawGrams);
}

/// Nutrition of a whole cooked batch.
class BatchNutrition {
  final NutrientTotals totals; // grams == cooked batch weight
  final Set<String> foodGroups;

  /// Ingredients with no composition data, which therefore contribute nothing to [totals].
  final List<String> unknownIngredients;

  /// Fraction of the batch's raw weight that resolved to composition data, 0..1.
  ///
  /// Weight-based rather than a count, because an unknown spice used in five grams matters far
  /// less than an unknown staple used in two hundred. A batch at less than full coverage has
  /// totals that are too low, and a caller showing them should say so rather than presenting
  /// them as the whole truth.
  final double knownGramsFraction;

  const BatchNutrition({
    required this.totals,
    required this.foodGroups,
    this.unknownIngredients = const [],
    this.knownGramsFraction = 1,
  });

  /// Whether every gram in the batch resolved to composition data.
  bool get isComplete => unknownIngredients.isEmpty && knownGramsFraction >= 0.999;

  /// Nutrients in a portion of [grams] cooked food.
  NutrientTotals portion(double grams) {
    if (totals.grams <= 0 || grams <= 0) return NutrientTotals.zero;
    return totals.scale(grams / totals.grams);
  }
}

/// What one member ate: a portion's nutrients plus where it came from.
class PortionIntake {
  final NutrientTotals nutrients;
  final Set<String> foodGroups;
  final double seasonalFraction; // 0..1 of this portion from in-season produce

  const PortionIntake({
    required this.nutrients,
    this.foodGroups = const {},
    this.seasonalFraction = 0,
  });
}

/// Daily protein / fiber targets per nutrition profile.
class NutrientTarget {
  final double proteinG;
  final double fiberG;
  const NutrientTarget(this.proteinG, this.fiberG);
}

/// A gentle progress bar. [fraction] is clamped to 0..1; there is deliberately
/// no warning/alert state, only a [level] word and an encouraging message.
class NutritionProgressBar {
  final String key; // protein, fiber, seasonal
  final double fraction;
  final String level; // 'warming-up' | 'steady' | 'abundant'
  final String messageEn;
  final String messageNe;

  const NutritionProgressBar({
    required this.key,
    required this.fraction,
    required this.level,
    required this.messageEn,
    required this.messageNe,
  });
}

/// Member nutrition view. Children and babies get food groups only: no calories,
/// no protein/fiber numbers.
class MemberNutritionView {
  final String memberId;
  final String memberName;
  final String nutritionProfile;
  final bool showsNumbers;
  final int? estimatedKcalPerDay;
  final List<NutritionProgressBar> bars;
  final List<String> foodGroupsCovered;
  final String messageEn;
  final String messageNe;

  const MemberNutritionView({
    required this.memberId,
    required this.memberName,
    required this.nutritionProfile,
    required this.showsNumbers,
    this.estimatedKcalPerDay,
    required this.bars,
    required this.foodGroupsCovered,
    required this.messageEn,
    required this.messageNe,
  });
}

/// Yield-factor based nutrition engine (Section 11.1, 11.4).
class NutritionEngine {
  static const allFoodGroups = [
    'grains',
    'pulses',
    'vegetables',
    'fruits',
    'dairy',
    'protein',
  ];

  static const List<FoodComposition> compositionTable = [
    FoodComposition(id: 'rice', nameEn: 'Rice', nameNe: 'चामल', foodGroup: 'grains', kcal: 345, proteinG: 6.8, fiberG: 0.6, carbsG: 78.2, fatG: 0.5),
    FoodComposition(id: 'wheat-flour', nameEn: 'Wheat flour (atta)', nameNe: 'गहुँको पीठो', foodGroup: 'grains', kcal: 341, proteinG: 11.8, fiberG: 11.4, carbsG: 71.2, fatG: 1.5, source: CompositionSource.ifct),
    FoodComposition(id: 'lentil', nameEn: 'Lentil (masoor dal)', nameNe: 'मसुरो दाल', foodGroup: 'pulses', kcal: 343, proteinG: 25.1, fiberG: 11.4, carbsG: 59.0, fatG: 0.7),
    FoodComposition(id: 'black-lentil', nameEn: 'Black lentil (kalo dal)', nameNe: 'कालो दाल', foodGroup: 'pulses', kcal: 347, proteinG: 24.0, fiberG: 12.0, carbsG: 59.6, fatG: 1.4),
    FoodComposition(id: 'potato', nameEn: 'Potato', nameNe: 'आलु', foodGroup: 'vegetables', kcal: 97, proteinG: 1.6, fiberG: 1.7, carbsG: 22.6, fatG: 0.1),
    FoodComposition(id: 'spinach', nameEn: 'Spinach (palungo)', nameNe: 'पालुङ्गो', foodGroup: 'vegetables', kcal: 26, proteinG: 2.0, fiberG: 0.6, carbsG: 2.9, fatG: 0.7),
    FoodComposition(id: 'cauliflower', nameEn: 'Cauliflower', nameNe: 'फूलगोभी', foodGroup: 'vegetables', kcal: 30, proteinG: 2.6, fiberG: 1.2, carbsG: 4.0, fatG: 0.4),
    FoodComposition(id: 'radish', nameEn: 'Radish (mula)', nameNe: 'मूला', foodGroup: 'vegetables', kcal: 32, proteinG: 0.6, fiberG: 0.8, carbsG: 7.3, fatG: 0.3),
    FoodComposition(id: 'mustard-oil', nameEn: 'Mustard oil', nameNe: 'तोरीको तेल', foodGroup: 'fats', kcal: 900, proteinG: 0, fiberG: 0, carbsG: 0, fatG: 100),
    FoodComposition(id: 'milk', nameEn: 'Milk', nameNe: 'दूध', foodGroup: 'dairy', kcal: 67, proteinG: 3.2, fiberG: 0, carbsG: 4.4, fatG: 4.1),
    FoodComposition(id: 'egg', nameEn: 'Egg', nameNe: 'अण्डा', foodGroup: 'protein', kcal: 173, proteinG: 13.3, fiberG: 0, carbsG: 0.8, fatG: 13.3, source: CompositionSource.ifct),
    FoodComposition(id: 'chicken', nameEn: 'Chicken', nameNe: 'कुखुराको मासु', foodGroup: 'protein', kcal: 109, proteinG: 25.9, fiberG: 0, carbsG: 0, fatG: 0.6, source: CompositionSource.ifct),
    FoodComposition(id: 'banana', nameEn: 'Banana', nameNe: 'केरा', foodGroup: 'fruits', kcal: 116, proteinG: 1.2, fiberG: 0.4, carbsG: 27.2, fatG: 0.3),

  ];

  /// Rows below are machine-written. See scripts/sync-usda-composition.mjs.
  static const List<FoodComposition> usdaTable = [
    // BEGIN generated USDA composition
    // Generated from data/nutrition/usda-composition.json by
    // scripts/sync-usda-composition.mjs. USDA FoodData Central, public domain.
    // Edit the JSON, not this file.
    FoodComposition(id: "asparagus", nameEn: "Asparagus, raw", nameNe: "asparagus", foodGroup: "vegetables", kcal: 20, proteinG: 2.2, fiberG: 2.1, carbsG: 3.9, fatG: 0.1, source: CompositionSource.usda),
    FoodComposition(id: "bamboo_shoot", nameEn: "Bamboo shoots, raw", nameNe: "bamboo_shoot", foodGroup: "vegetables", kcal: 27, proteinG: 2.6, fiberG: 2.2, carbsG: 5.2, fatG: 0.3, source: CompositionSource.usda),
    FoodComposition(id: "bean_sprouts", nameEn: "Soybeans, mature seeds, sprouted, raw", nameNe: "bean_sprouts", foodGroup: "vegetables", kcal: 510, proteinG: 13.1, fiberG: 1.1, carbsG: 9.6, fatG: 6.7, source: CompositionSource.usda),
    FoodComposition(id: "bitter_gourd", nameEn: "Balsam-pear (bitter gourd), pods, raw", nameNe: "bitter_gourd", foodGroup: "vegetables", kcal: 71, proteinG: 1, fiberG: 2.8, carbsG: 3.7, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "bottle_gourd", nameEn: "Balsam-pear (bitter gourd), pods, raw", nameNe: "bottle_gourd", foodGroup: "vegetables", kcal: 71, proteinG: 1, fiberG: 2.8, carbsG: 3.7, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "buckwheat_flour", nameEn: "Buckwheat flour, whole-groat", nameNe: "buckwheat_flour", foodGroup: "grains", kcal: 335, proteinG: 12.6, fiberG: 10, carbsG: 70.6, fatG: 3.1, source: CompositionSource.usda),
    FoodComposition(id: "cabbage", nameEn: "Cabbage, raw", nameNe: "cabbage", foodGroup: "vegetables", kcal: 25, proteinG: 1.3, fiberG: 2.5, carbsG: 5.8, fatG: 0.1, source: CompositionSource.usda),
    FoodComposition(id: "cardamom", nameEn: "Spices, cardamom", nameNe: "cardamom", foodGroup: "spices", kcal: 311, proteinG: 10.8, fiberG: 28, carbsG: 68.5, fatG: 6.7, source: CompositionSource.usda),
    FoodComposition(id: "carrot", nameEn: "Carrots, raw", nameNe: "carrot", foodGroup: "vegetables", kcal: 41, proteinG: 0.9, fiberG: 2.8, carbsG: 9.6, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "chickpea", nameEn: "Chickpeas (garbanzo beans, bengal gram), mature seeds, raw", nameNe: "chickpea", foodGroup: "pulses", kcal: 378, proteinG: 20.5, fiberG: 12.2, carbsG: 63, fatG: 6, source: CompositionSource.usda),
    FoodComposition(id: "cinnamon", nameEn: "Spices, cinnamon, ground", nameNe: "cinnamon", foodGroup: "spices", kcal: 1035, proteinG: 4, fiberG: 53.1, carbsG: 80.6, fatG: 1.2, source: CompositionSource.usda),
    FoodComposition(id: "colocasia", nameEn: "Taro, raw", nameNe: "colocasia", foodGroup: "vegetables", kcal: 469, proteinG: 1.5, fiberG: 4.1, carbsG: 26.5, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "coriander", nameEn: "Spices, coriander seed", nameNe: "coriander", foodGroup: "spices", kcal: 298, proteinG: 12.4, fiberG: 41.9, carbsG: 55, fatG: 17.8, source: CompositionSource.usda),
    FoodComposition(id: "coriander_fresh", nameEn: "Coriander (cilantro) leaves, raw", nameNe: "coriander_fresh", foodGroup: "vegetables", kcal: 95, proteinG: 2.1, fiberG: 2.8, carbsG: 3.7, fatG: 0.5, source: CompositionSource.usda),
    FoodComposition(id: "cornstarch", nameEn: "Cornstarch", nameNe: "cornstarch", foodGroup: "grains", kcal: 1594, proteinG: 0.3, fiberG: 0.9, carbsG: 91.3, fatG: 0.1, source: CompositionSource.usda),
    FoodComposition(id: "cucumber", nameEn: "Cucumber, with peel, raw", nameNe: "cucumber", foodGroup: "vegetables", kcal: 15, proteinG: 0.7, fiberG: 0.5, carbsG: 3.6, fatG: 0.1, source: CompositionSource.usda),
    FoodComposition(id: "cumin", nameEn: "Spices, cumin seed", nameNe: "cumin", foodGroup: "spices", kcal: 375, proteinG: 17.8, fiberG: 10.5, carbsG: 44.2, fatG: 22.3, source: CompositionSource.usda),
    FoodComposition(id: "eggplant", nameEn: "Eggplant, raw", nameNe: "eggplant", foodGroup: "vegetables", kcal: 25, proteinG: 1, fiberG: 3, carbsG: 5.9, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "fenugreek_seeds", nameEn: "Spices, fenugreek seed", nameNe: "fenugreek_seeds", foodGroup: "spices", kcal: 1352, proteinG: 23, fiberG: 24.6, carbsG: 58.4, fatG: 6.4, source: CompositionSource.usda),
    FoodComposition(id: "fish", nameEn: "Fish, tilapia, raw", nameNe: "fish", foodGroup: "protein", kcal: 96, proteinG: 20.1, fiberG: 0, carbsG: 0, fatG: 1.7, source: CompositionSource.usda),
    FoodComposition(id: "garlic", nameEn: "Garlic, raw", nameNe: "garlic", foodGroup: "vegetables", kcal: 149, proteinG: 6.4, fiberG: 2.1, carbsG: 33.1, fatG: 0.5, source: CompositionSource.usda),
    FoodComposition(id: "ghee", nameEn: "Butter, Clarified butter (ghee)", nameNe: "ghee", foodGroup: "fats", kcal: 3766, proteinG: 0, fiberG: 0, carbsG: 0, fatG: 100, source: CompositionSource.usda),
    FoodComposition(id: "ginger", nameEn: "Ginger root, raw", nameNe: "ginger", foodGroup: "vegetables", kcal: 333, proteinG: 1.8, fiberG: 2, carbsG: 17.8, fatG: 0.8, source: CompositionSource.usda),
    FoodComposition(id: "goat_meat", nameEn: "Game meat, goat, raw", nameNe: "goat_meat", foodGroup: "protein", kcal: 456, proteinG: 20.6, fiberG: 0, carbsG: 0, fatG: 2.3, source: CompositionSource.usda),
    FoodComposition(id: "gram_flour", nameEn: "Chickpeas (garbanzo beans, bengal gram), mature seeds, raw", nameNe: "gram_flour", foodGroup: "pulses", kcal: 378, proteinG: 20.5, fiberG: 12.2, carbsG: 63, fatG: 6, source: CompositionSource.usda),
    FoodComposition(id: "green_chili", nameEn: "Peppers, hot chili, green, raw", nameNe: "green_chili", foodGroup: "vegetables", kcal: 167, proteinG: 2, fiberG: 1.5, carbsG: 9.5, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "green_mustard", nameEn: "Mustard greens, raw", nameNe: "green_mustard", foodGroup: "vegetables", kcal: 114, proteinG: 2.9, fiberG: 3.2, carbsG: 4.7, fatG: 0.4, source: CompositionSource.usda),
    FoodComposition(id: "green_peas", nameEn: "Peas, green, raw", nameNe: "green_peas", foodGroup: "vegetables", kcal: 339, proteinG: 5.4, fiberG: 5.7, carbsG: 14.5, fatG: 0.4, source: CompositionSource.usda),
    FoodComposition(id: "kidney_beans", nameEn: "Beans, kidney, all types, mature seeds, raw", nameNe: "kidney_beans", foodGroup: "pulses", kcal: 1393, proteinG: 23.6, fiberG: 24.9, carbsG: 60, fatG: 0.8, source: CompositionSource.usda),
    FoodComposition(id: "lamb_meat", nameEn: "Lamb, composite of trimmed retail cuts, separable lean and fat, trimmed to 1/4\" fat, choice, raw", nameNe: "lamb_meat", foodGroup: "protein", kcal: 1117, proteinG: 16.9, fiberG: 0, carbsG: 0, fatG: 21.6, source: CompositionSource.usda),
    FoodComposition(id: "lambsquarters", nameEn: "Lambsquarters, raw", nameNe: "lambsquarters", foodGroup: "vegetables", kcal: 180, proteinG: 4.2, fiberG: 4, carbsG: 7.3, fatG: 0.8, source: CompositionSource.usda),
    FoodComposition(id: "lemon", nameEn: "Lemons, raw, without peel", nameNe: "lemon", foodGroup: "fruits", kcal: 121, proteinG: 1.1, fiberG: 2.8, carbsG: 9.3, fatG: 0.3, source: CompositionSource.usda),
    FoodComposition(id: "litchi", nameEn: "Litchis, raw", nameNe: "litchi", foodGroup: "fruits", kcal: 276, proteinG: 0.8, fiberG: 1.3, carbsG: 16.5, fatG: 0.4, source: CompositionSource.usda),
    FoodComposition(id: "mango", nameEn: "Mangos, raw", nameNe: "mango", foodGroup: "fruits", kcal: 60, proteinG: 0.8, fiberG: 1.6, carbsG: 15, fatG: 0.4, source: CompositionSource.usda),
    FoodComposition(id: "millet_flour", nameEn: "Millet flour", nameNe: "millet_flour", foodGroup: "grains", kcal: 382, proteinG: 10.8, fiberG: 3.5, carbsG: 75.1, fatG: 4.3, source: CompositionSource.usda),
    FoodComposition(id: "mushroom", nameEn: "Mushrooms, white, raw", nameNe: "mushroom", foodGroup: "vegetables", kcal: 93, proteinG: 3.1, fiberG: 1, carbsG: 3.3, fatG: 0.3, source: CompositionSource.usda),
    FoodComposition(id: "noodles", nameEn: "Pasta, cooked, unenriched, without added salt", nameNe: "noodles", foodGroup: "grains", kcal: 158, proteinG: 5.8, fiberG: 1.8, carbsG: 30.9, fatG: 0.9, source: CompositionSource.usda),
    FoodComposition(id: "okra", nameEn: "Okra, raw", nameNe: "okra", foodGroup: "vegetables", kcal: 138, proteinG: 1.9, fiberG: 3.2, carbsG: 7.5, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "onion", nameEn: "Onions, raw", nameNe: "onion", foodGroup: "vegetables", kcal: 40, proteinG: 1.1, fiberG: 1.7, carbsG: 9.3, fatG: 0.1, source: CompositionSource.usda),
    FoodComposition(id: "pomegranate", nameEn: "Pomegranates, raw", nameNe: "pomegranate", foodGroup: "fruits", kcal: 346, proteinG: 1.7, fiberG: 4, carbsG: 18.7, fatG: 1.2, source: CompositionSource.usda),
    FoodComposition(id: "pork_meat", nameEn: "Pork, ground, 84% lean / 16% fat, raw", nameNe: "pork_meat", foodGroup: "protein", kcal: 218, proteinG: 18, fiberG: 0, carbsG: 0.4, fatG: 16, source: CompositionSource.usda),
    FoodComposition(id: "prawn", nameEn: "Crustaceans, shrimp, raw", nameNe: "prawn", foodGroup: "protein", kcal: 85, proteinG: 20.1, fiberG: 0, carbsG: 0, fatG: 0.5, source: CompositionSource.usda),
    FoodComposition(id: "pumpkin", nameEn: "Pumpkin, raw", nameNe: "pumpkin", foodGroup: "vegetables", kcal: 109, proteinG: 1, fiberG: 0.5, carbsG: 6.5, fatG: 0.1, source: CompositionSource.usda),
    FoodComposition(id: "pumpkin_shoots", nameEn: "Pumpkin leaves, raw", nameNe: "pumpkin_shoots", foodGroup: "vegetables", kcal: 79, proteinG: 3.2, fiberG: 0, carbsG: 2.3, fatG: 0.4, source: CompositionSource.usda),
    FoodComposition(id: "quinoa", nameEn: "Quinoa, uncooked", nameNe: "quinoa", foodGroup: "grains", kcal: 368, proteinG: 14.1, fiberG: 7, carbsG: 64.2, fatG: 6.1, source: CompositionSource.usda),
    FoodComposition(id: "rajma", nameEn: "Beans, black, mature seeds, raw", nameNe: "rajma", foodGroup: "pulses", kcal: 341, proteinG: 21.6, fiberG: 15.5, carbsG: 62.4, fatG: 1.4, source: CompositionSource.usda),
    FoodComposition(id: "red_chili", nameEn: "Spices, pepper, red or cayenne", nameNe: "red_chili", foodGroup: "spices", kcal: 318, proteinG: 12, fiberG: 27.2, carbsG: 56.6, fatG: 17.3, source: CompositionSource.usda),
    FoodComposition(id: "red_lentils", nameEn: "Lentils, raw", nameNe: "red_lentils", foodGroup: "pulses", kcal: 1473, proteinG: 24.6, fiberG: 10.7, carbsG: 63.4, fatG: 1.1, source: CompositionSource.usda),
    FoodComposition(id: "salmon", nameEn: "Fish, salmon, Atlantic, farmed, raw", nameNe: "salmon", foodGroup: "protein", kcal: 208, proteinG: 20.4, fiberG: 0, carbsG: 0, fatG: 13.4, source: CompositionSource.usda),
    FoodComposition(id: "salt", nameEn: "Salt, table", nameNe: "salt", foodGroup: "spices", kcal: 0, proteinG: 0, fiberG: 0, carbsG: 0, fatG: 0, source: CompositionSource.usda),
    FoodComposition(id: "sesame", nameEn: "Seeds, sesame seeds, whole, dried", nameNe: "sesame", foodGroup: "spices", kcal: 2397, proteinG: 17.7, fiberG: 11.8, carbsG: 23.5, fatG: 49.7, source: CompositionSource.usda),
    FoodComposition(id: "soy_beans", nameEn: "Soybeans, mature seeds, raw", nameNe: "soy_beans", foodGroup: "pulses", kcal: 446, proteinG: 36.5, fiberG: 9.3, carbsG: 30.2, fatG: 19.9, source: CompositionSource.usda),
    FoodComposition(id: "split_pea", nameEn: "Peas, green, split, mature seeds, raw", nameNe: "split_pea", foodGroup: "pulses", kcal: 1521, proteinG: 23.1, fiberG: 22.2, carbsG: 61.6, fatG: 3.9, source: CompositionSource.usda),
    FoodComposition(id: "sponge_gourd", nameEn: "Gourd, dishcloth (towelgourd), raw", nameNe: "sponge_gourd", foodGroup: "vegetables", kcal: 20, proteinG: 1.2, fiberG: 1.1, carbsG: 4.4, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "sunflower_oil", nameEn: "Oil, sunflower, high oleic (70% and over)", nameNe: "sunflower_oil", foodGroup: "fats", kcal: 884, proteinG: 0, fiberG: 0, carbsG: 0, fatG: 100, source: CompositionSource.usda),
    FoodComposition(id: "sweet_potato", nameEn: "Sweet potato, raw, unprepared (Includes foods for USDA's Food Distribution Program)", nameNe: "sweet_potato", foodGroup: "vegetables", kcal: 359, proteinG: 1.6, fiberG: 3, carbsG: 20.1, fatG: 0.1, source: CompositionSource.usda),
    FoodComposition(id: "taro_leaves", nameEn: "Taro leaves, raw", nameNe: "taro_leaves", foodGroup: "vegetables", kcal: 177, proteinG: 5, fiberG: 3.7, carbsG: 6.7, fatG: 0.7, source: CompositionSource.usda),
    FoodComposition(id: "tofu", nameEn: "Tofu, raw, firm, prepared with calcium sulfate", nameNe: "tofu", foodGroup: "protein", kcal: 144, proteinG: 17.3, fiberG: 2.3, carbsG: 2.8, fatG: 8.7, source: CompositionSource.usda),
    FoodComposition(id: "tomato", nameEn: "Tomatoes, red, ripe, raw, year round average", nameNe: "tomato", foodGroup: "vegetables", kcal: 18, proteinG: 0.9, fiberG: 1.2, carbsG: 3.9, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "turmeric", nameEn: "Spices, turmeric, ground", nameNe: "turmeric", foodGroup: "spices", kcal: 312, proteinG: 9.7, fiberG: 22.7, carbsG: 67.1, fatG: 3.3, source: CompositionSource.usda),
    FoodComposition(id: "vegetable_oil", nameEn: "Oil, corn and canola", nameNe: "vegetable_oil", foodGroup: "fats", kcal: 3699, proteinG: 0, fiberG: 0, carbsG: 0, fatG: 100, source: CompositionSource.usda),
    FoodComposition(id: "yam", nameEn: "Yam, raw", nameNe: "yam", foodGroup: "vegetables", kcal: 118, proteinG: 1.5, fiberG: 4.1, carbsG: 27.9, fatG: 0.2, source: CompositionSource.usda),
    FoodComposition(id: "yogurt", nameEn: "Yogurt, plain, whole milk", nameNe: "yogurt", foodGroup: "dairy", kcal: 61, proteinG: 3.5, fiberG: 0, carbsG: 4.7, fatG: 3.3, source: CompositionSource.usda),
    // END generated USDA composition
  ];

  static const List<YieldFactor> yieldFactors = [
    YieldFactor(ingredientId: 'rice', factor: 3.0, method: 'boiled'),
    YieldFactor(ingredientId: 'wheat-flour', factor: 1.5, method: 'dough/roti'),
    YieldFactor(ingredientId: 'lentil', factor: 2.5, method: 'boiled'),
    YieldFactor(ingredientId: 'black-lentil', factor: 2.4, method: 'boiled'),
    YieldFactor(ingredientId: 'potato', factor: 0.95, method: 'curried'),
    YieldFactor(ingredientId: 'spinach', factor: 0.5, method: 'sauteed'),
    YieldFactor(ingredientId: 'cauliflower', factor: 0.85, method: 'curried'),
    YieldFactor(ingredientId: 'radish', factor: 0.8, method: 'curried'),
    YieldFactor(ingredientId: 'chicken', factor: 0.75, method: 'curried'),
    YieldFactor(ingredientId: 'egg', factor: 0.95, method: 'boiled'),
  ];

  static const Map<String, NutrientTarget> dailyTargets = {
    'everyday': NutrientTarget(50, 25),
    'pregnancy': NutrientTarget(71, 28),
    'elderly': NutrientTarget(55, 25),
    'fitness': NutrientTarget(90, 30),
  };

  /// Ingredient ids that name a food the table already covers under a different id.
  ///
  /// The packs and the table were written by different hands and do not agree on spelling, so
  /// a lookup by exact id silently returned nothing and the ingredient contributed zero
  /// nutrients. Separators are handled by [normalizeIngredientId]; these are the cases where
  /// the names genuinely differ.
  static const Map<String, String> ingredientAliases = {
    'kalo_dal': 'black-lentil',
    'masoor_dal': 'lentil',
    'masur_dal': 'lentil',
    'masu': 'chicken',
    'chicken-meat': 'chicken',
    'kukura': 'chicken',
    'ghiu': 'ghee',
    'clarified-butter': 'ghee',
    'tel-paoda': 'spinach',
    'palungo': 'spinach',
    'saag': 'spinach',
    'alu': 'potato',
    'kohlrabi': 'cabbage',
    'pyaaz': 'onion',
    'kershipa': 'onion',
    'khaman': 'wheat-flour',
    'momo-skin': 'wheat-flour',
    'rice_flour': 'rice',
    'flour': 'wheat-flour',
    'maida': 'wheat-flour',
    'chana': 'chickpea',
    'chana_dal': 'chickpea',
    'masuro_dal': 'lentil',
    'mung_dal': 'soy-beans',
    'paneer': 'tofu',
    'buff_meat': 'goat-meat',
    'buff': 'goat-meat',
    'khasi': 'goat-meat',
    // Regional names for foods the table already covers. Each of these is the same food, not a
    // substitute: desi and grassfed ghee are ghee, basmati is rice, chiura is beaten rice.
    'desi_ghee': 'ghee',
    'grassfed_ghee': 'ghee',
    'basmati_rice': 'rice',
    'chiura': 'rice',
    'palak': 'spinach',
    'lady_finger': 'okra',
    'bodi': 'chickpea',
    'kasuri_methi': 'fenugreek-seeds',
    'rahar_dal': 'lentil',
    'urad_dal_black': 'rajma',
    'pumpkinshoots': 'pumpkin-shoots',
    'aussie_lamb': 'lamb-meat',
    'tasmanian_salmon': 'salmon',
    // Spellings the packs use for foods now in the table.
    'cumin_seeds': 'cumin',
    'coriander_powder': 'coriander',
    'green_mango': 'mango',
    'chamsur_saag': 'lambsquarters',
    'rayo_saag': 'green-mustard',
    'methi_saag': 'fenugreek-seeds',
    'bhatmas': 'split-pea',
    'sponge_gourd': 'sponge-gourd',
    'colocasia_leaves': 'taro-leaves',
    'corn_flour': 'cornstarch',
    'semolina': 'wheat-flour',
  };

  /// Canonical form of an ingredient id for lookup.
  ///
  /// The region packs write snake_case (`mustard_oil`) while this table writes kebab-case
  /// (`mustard-oil`). Before normalisation only 66 of 672 ingredient references across the
  /// packs resolved to nutrient data; folding the separator alone lifts that to 183, because
  /// mustard oil on its own appears 101 times.
  static String normalizeIngredientId(String id) {
    return id.trim().toLowerCase().replaceAll('_', '-');
  }

  /// Looks a row up by exact id, then by normalised id, across both tables.
  static FoodComposition? _findById(String? candidate) {
    if (candidate == null) return null;
    // Curated rows first, then the USDA import: a hand-checked local value should win over a
    // generic one for the same food.
    final tables = [compositionTable, usdaTable];

    for (final table in tables) {
      for (final c in table) {
        if (c.id == candidate) return c;
      }
    }
    // The two tables were written to different conventions — the curated rows use kebab-case and
    // the USDA rows the snake_case the packs already use — so both sides are normalised here.
    // Normalising only the candidate left every alias pointing at an imported row inert, because
    // `goat-meat` never matches `goat_meat`.
    final normalized = normalizeIngredientId(candidate);
    for (final table in tables) {
      for (final c in table) {
        if (normalizeIngredientId(c.id) == normalized) return c;
      }
    }
    return null;
  }

  static FoodComposition? compositionFor(String id) {
    final direct = _findById(id);
    if (direct != null) return direct;

    final alias = ingredientAliases[normalizeIngredientId(id)] ?? ingredientAliases[id];
    return _findById(alias);
  }

  /// Every row available, curated first then imported.
  static List<FoodComposition> get allCompositions => [...compositionTable, ...usdaTable];

  /// Whether [id] resolves to nutrient data.
  ///
  /// Callers that report coverage use this rather than inferring it from a zero total, which is
  /// indistinguishable from a food that genuinely has no nutrients.
  static bool hasCompositionFor(String id) => compositionFor(id) != null;

  /// Cooked grams per raw gram; 1.0 when no factor is known.
  static double yieldFor(String ingredientId) {
    for (final y in yieldFactors) {
      if (y.ingredientId == ingredientId) return y.factor;
    }

    // Same separator problem as compositionFor: an unmatched yield factor silently became 1.0,
    // which is a no-op rather than an error, so cooked weights were quietly wrong.
    final normalized = normalizeIngredientId(ingredientId);
    for (final y in yieldFactors) {
      if (y.ingredientId == normalized) return y.factor;
    }

    final alias = ingredientAliases[normalized] ?? ingredientAliases[ingredientId];
    if (alias != null) {
      for (final y in yieldFactors) {
        if (y.ingredientId == alias) return y.factor;
      }
    }
    return 1.0;
  }

  /// Nutrients per 100 g of the COOKED ingredient (raw density / yield factor).
  static NutrientTotals cookedPer100g(String ingredientId) {
    final c = compositionFor(ingredientId);
    if (c == null) return NutrientTotals.zero;
    final f = yieldFor(ingredientId);
    return NutrientTotals(
      grams: 100,
      kcal: c.kcal / f,
      proteinG: c.proteinG / f,
      fiberG: c.fiberG / f,
      carbsG: c.carbsG / f,
      fatG: c.fatG / f,
    );
  }

  /// Computes batch nutrition from RAW ingredient weights. Nutrients always come
  /// from raw weight; the cooked weight is [cookedYieldGrams] when the cook
  /// weighed it, else the sum of raw * yield factor.
  static BatchNutrition computeBatch(
    List<BatchIngredient> ingredients, {
    double? cookedYieldGrams,
  }) {
    var total = NutrientTotals.zero;
    var estimatedCooked = 0.0;
    var knownRawGrams = 0.0;
    var totalRawGrams = 0.0;
    final groups = <String>{};
    final unknown = <String>[];

    for (final ing in ingredients) {
      if (ing.rawGrams > 0) totalRawGrams += ing.rawGrams;
      final c = compositionFor(ing.ingredientId);
      if (c == null || ing.rawGrams <= 0) {
        if (c == null) unknown.add(ing.ingredientId);
        continue;
      }
      knownRawGrams += ing.rawGrams;
      final k = ing.rawGrams / 100.0;
      total = total +
          NutrientTotals(
            kcal: c.kcal * k,
            proteinG: c.proteinG * k,
            fiberG: c.fiberG * k,
            carbsG: c.carbsG * k,
            fatG: c.fatG * k,
          );
      estimatedCooked += ing.rawGrams * yieldFor(ing.ingredientId);
      if (c.foodGroup != 'fats') groups.add(c.foodGroup);
    }

    final cooked = (cookedYieldGrams != null && cookedYieldGrams > 0)
        ? cookedYieldGrams
        : estimatedCooked;
    return BatchNutrition(
      totals: NutrientTotals(
        grams: cooked,
        kcal: total.kcal,
        proteinG: total.proteinG,
        fiberG: total.fiberG,
        carbsG: total.carbsG,
        fatG: total.fatG,
      ),
      foodGroups: groups,
      unknownIngredients: unknown,
      knownGramsFraction: totalRawGrams <= 0
          ? 0
          : (knownRawGrams / totalRawGrams).clamp(0.0, 1.0).toDouble(),
    );
  }

  /// Nutrition of one recipe's own ingredient list, at an optional serving count.
  ///
  /// This is what the family nutrition dashboard should score a logged meal with. Previously
  /// every meal was scored as dal bhat regardless of what was eaten, so a household logging
  /// thukpa was shown dal bhat's nutrients.
  ///
  /// Returns null only when the recipe has no usable ingredients. A recipe with partial
  /// coverage still returns a batch, with [BatchNutrition.knownGramsFraction] below 1 so the
  /// caller can say the figure is incomplete instead of presenting it as whole.
  static BatchNutrition? batchForRecipe(
    RegionRecipe recipe, {
    double? servings,
  }) {
    final target = servings != null && servings > 0 ? servings : recipe.servings.toDouble();
    final scale = recipe.servings > 0 ? target / recipe.servings.toDouble() : 1.0;

    return computeBatch([
      for (final ing in recipe.ingredients)
        if (quantityToGrams(ing.quantity, ing.unit) > 0)
          BatchIngredient(
            ing.ingredientId,
            quantityToGrams(ing.quantity, ing.unit) * scale,
          ),
    ]);
  }

  static NutritionProgressBar _bar(String key, double ratio, String en, String ne) {
    final fraction = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0).toDouble();
    final level = ratio < 0.6 ? 'warming-up' : (ratio < 1.0 ? 'steady' : 'abundant');
    return NutritionProgressBar(
      key: key,
      fraction: fraction,
      level: level,
      messageEn: en,
      messageNe: ne,
    );
  }

  /// Builds a calm member view over [days] days of intake.
  static MemberNutritionView buildMemberView({
    required MemberDietaryProfile member,
    required List<PortionIntake> intakes,
    int days = 7,
  }) {
    final groups = <String>{};
    for (final i in intakes) {
      groups.addAll(i.foodGroups);
    }
    final covered = allFoodGroups.where(groups.contains).toList();

    if (member.isChildOrBaby) {
      final n = covered.length;
      return MemberNutritionView(
        memberId: member.memberId,
        memberName: member.name,
        nutritionProfile: member.nutritionProfile,
        showsNumbers: false,
        bars: const [],
        foodGroupsCovered: covered,
        messageEn: n >= 4
            ? 'A colourful plate this week: $n food groups enjoyed.'
            : 'Lovely start. Try adding another colour to a plate soon.',
        messageNe: n >= 4
            ? 'यो हप्ता रंगीन थाली: $n खाद्य समूह खाइयो।'
            : 'राम्रो सुरुवात। चाँडै थालीमा अर्को रंग थप्न सकिन्छ।',
      );
    }

    final target = dailyTargets[member.nutritionProfile] ?? dailyTargets['everyday']!;
    var sum = NutrientTotals.zero;
    var seasonalWeighted = 0.0;
    for (final i in intakes) {
      sum = sum + i.nutrients;
      seasonalWeighted += i.nutrients.grams * i.seasonalFraction;
    }
    final d = days <= 0 ? 1 : days;
    final protein = sum.proteinG / (target.proteinG * d);
    final fiber = sum.fiberG / (target.fiberG * d);
    final seasonal = sum.grams > 0 ? seasonalWeighted / sum.grams : 0.0;

    final bars = [
      _bar('protein', protein, 'Protein is building up nicely.', 'प्रोटिन राम्ररी जम्दैछ।'),
      _bar('fiber', fiber, 'Fibre from dal and vegetables adds up.', 'दाल र तरकारीबाट फाइबर थपिँदैछ।'),
      _bar('seasonal', seasonal, 'Eating with the season keeps meals fresh.', 'ऋतु अनुसारको खानाले ताजा राख्छ।'),
    ];

    return MemberNutritionView(
      memberId: member.memberId,
      memberName: member.name,
      nutritionProfile: member.nutritionProfile,
      showsNumbers: true,
      estimatedKcalPerDay: intakes.isEmpty ? null : (sum.kcal / d).round(),
      bars: bars,
      foodGroupsCovered: covered,
      messageEn: 'Every meal counts. Here is this week at a glance.',
      messageNe: 'हरेक खानाको महत्त्व छ। यो हप्ताको झलक यहाँ छ।',
    );
  }
}
