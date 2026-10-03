library;

/// Common standard and regional allergen identifiers.
class AllergenCatalog {
  // EU 14 Allergens
  static const String celery = 'celery';
  static const String gluten = 'gluten'; // Cereals containing gluten (wheat, barley, rye, oats)
  static const String crustaceans = 'crustaceans';
  static const String eggs = 'eggs';
  static const String fish = 'fish';
  static const String lupin = 'lupin';
  static const String milk = 'dairy'; // Dairy / Milk
  static const String molluscs = 'molluscs';
  static const String mustard = 'mustard';
  static const String nuts = 'nuts'; // Tree nuts
  static const String peanuts = 'peanuts';
  static const String sesame = 'sesame';
  static const String soy = 'soy';
  static const String sulphites = 'sulphites';

  // Regional & South Asian / Himalayan Allergens
  static const String buckwheat = 'buckwheat'; // फापर (Fapar) - common Himalayan allergen
  static const String mustardOil = 'mustard_oil'; // तोरीको तेल (pungent erucic acid & mustard protein)
  static const String fenugreek = 'fenugreek'; // मेथी (Methi) - cross-reactive with peanut allergies

  /// All registered allergens in the catalog.
  static const Set<String> allAllergens = {
    celery,
    gluten,
    crustaceans,
    eggs,
    fish,
    lupin,
    milk,
    molluscs,
    mustard,
    nuts,
    peanuts,
    sesame,
    soy,
    sulphites,
    buckwheat,
    mustardOil,
    fenugreek,
  };
}

/// Allergy severity levels for a household member.
enum AllergySeverity {
  /// Life-threatening / anaphylaxis risk. Recipes strictly blocked from auto-planning.
  severe,

  /// Moderate allergy or clinical intolerance. Warning shown with substitution.
  moderate,

  /// Mild sensitivity. Advisory shown.
  mild,
}

/// Dietary rules and faith-based restrictions.
enum DietaryRule {
  vegetarian,
  vegan,
  lactoVegetarian,
  jainVegetarian,
  halal,
  kosher,
  hinduFasting, // Vrata / Ekadashi / Navratri fasting
}

/// Member allergy profile with severity.
class MemberAllergyProfile {
  final String allergen;
  final AllergySeverity severity;
  final String? memberName;

  const MemberAllergyProfile({
    required this.allergen,
    this.severity = AllergySeverity.severe,
    this.memberName,
  });
}

/// Information about a hidden or direct allergen in an ingredient.
class AllergenSourceInfo {
  final String allergen;
  final bool isHidden;
  final String? explanation;

  const AllergenSourceInfo({
    required this.allergen,
    this.isHidden = false,
    this.explanation,
  });
}

/// Suggested safe alternative for an allergenic or restricted ingredient.
class SafeSubstitution {
  final String ingredientId;
  final String nameEn;
  final String nameNe;
  final String notesEn;
  final String notesNe;
  final Set<String> allergens;

  const SafeSubstitution({
    required this.ingredientId,
    required this.nameEn,
    required this.nameNe,
    required this.notesEn,
    required this.notesNe,
    this.allergens = const {},
  });
}

/// A safety conflict identified in a recipe.
class SafetyConflict {
  final String ingredientId;
  final String ingredientName;
  final String? allergen;
  final AllergySeverity? severity;
  final bool isDietaryViolation;
  final DietaryRule? dietaryRule;
  final bool isHiddenSource;
  final String reason;
  final List<SafeSubstitution> suggestedSubstitutions;

  const SafetyConflict({
    required this.ingredientId,
    required this.ingredientName,
    this.allergen,
    this.severity,
    this.isDietaryViolation = false,
    this.dietaryRule,
    this.isHiddenSource = false,
    required this.reason,
    this.suggestedSubstitutions = const [],
  });
}

/// Verdict returned by the deterministic safety engine.
class RecipeSafetyVerdict {
  final bool isSafe;
  final bool isAllowedInAutoPlan;
  final bool hasSevereConflict;
  final bool hasHiddenAllergens;
  final List<SafetyConflict> conflicts;
  final String? primaryWarning;

  const RecipeSafetyVerdict({
    required this.isSafe,
    required this.isAllowedInAutoPlan,
    required this.hasSevereConflict,
    required this.hasHiddenAllergens,
    required this.conflicts,
    this.primaryWarning,
  });
}

/// Deterministic allergen and dietary rule filtering engine.
class AllergenEngine {
  /// Known ingredient-to-allergen mappings, including hidden sources.
  static final Map<String, List<AllergenSourceInfo>> ingredientAllergens = {
    // Hidden sources (Critical Safety P0)
    'hing': [
      AllergenSourceInfo(
        allergen: AllergenCatalog.gluten,
        isHidden: true,
        explanation:
            'Commercial compounded asafoetida (hing) typically contains wheat/maida flour as an anti-caking carrier.',
      ),
    ],
    'asafoetida': [
      AllergenSourceInfo(
        allergen: AllergenCatalog.gluten,
        isHidden: true,
        explanation:
            'Commercial compounded asafoetida (hing) typically contains wheat/maida flour as an anti-caking carrier.',
      ),
    ],
    'ghee': [
      AllergenSourceInfo(
        allergen: AllergenCatalog.milk,
        isHidden: true,
        explanation:
            'Clarified butter (ghee) is derived from cow or buffalo milk and contains trace dairy proteins (casein/whey).',
      ),
    ],
    'clarified_butter': [
      AllergenSourceInfo(
        allergen: AllergenCatalog.milk,
        isHidden: true,
        explanation: 'Clarified butter is a dairy product containing trace milk proteins.',
      ),
    ],
    'soy_sauce': [
      AllergenSourceInfo(
        allergen: AllergenCatalog.soy,
        isHidden: false,
      ),
      AllergenSourceInfo(
        allergen: AllergenCatalog.gluten,
        isHidden: true,
        explanation: 'Traditional brewed soy sauce is fermented with wheat mash.',
      ),
    ],

    // Mustard and Mustard Oil
    'mustard_oil': [
      AllergenSourceInfo(allergen: AllergenCatalog.mustard),
      AllergenSourceInfo(allergen: AllergenCatalog.mustardOil),
    ],
    'mustard_seeds': [
      AllergenSourceInfo(allergen: AllergenCatalog.mustard),
    ],
    'tori_ko_tel': [
      AllergenSourceInfo(allergen: AllergenCatalog.mustard),
      AllergenSourceInfo(allergen: AllergenCatalog.mustardOil),
    ],

    // Buckwheat (Fapar)
    'buckwheat': [
      AllergenSourceInfo(allergen: AllergenCatalog.buckwheat),
    ],
    'buckwheat_flour': [
      AllergenSourceInfo(allergen: AllergenCatalog.buckwheat),
    ],
    'fapar': [
      AllergenSourceInfo(allergen: AllergenCatalog.buckwheat),
    ],
    'fapar_pitho': [
      AllergenSourceInfo(allergen: AllergenCatalog.buckwheat),
    ],

    // Fenugreek (Methi)
    'fenugreek': [
      AllergenSourceInfo(
        allergen: AllergenCatalog.fenugreek,
        explanation: 'Fenugreek seeds cross-react with peanut allergies.',
      ),
    ],
    'methi': [
      AllergenSourceInfo(
        allergen: AllergenCatalog.fenugreek,
        explanation: 'Fenugreek seeds cross-react with peanut allergies.',
      ),
    ],

    // Peanuts & Legumes
    'peanut': [AllergenSourceInfo(allergen: AllergenCatalog.peanuts)],
    'peanuts': [AllergenSourceInfo(allergen: AllergenCatalog.peanuts)],
    'peanut_butter': [AllergenSourceInfo(allergen: AllergenCatalog.peanuts)],
    'badam': [AllergenSourceInfo(allergen: AllergenCatalog.peanuts)], // Common Nepali name for groundnut

    // Tree Nuts
    'cashew': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'cashews': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'kaju': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'walnut': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'walnuts': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'okhar': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'almond': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'almonds': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'pistachio': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],
    'pista': [AllergenSourceInfo(allergen: AllergenCatalog.nuts)],

    // Dairy
    'milk': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],
    'dudh': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],
    'paneer': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],
    'curd': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],
    'dahi': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],
    'yogurt': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],
    'butter': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],
    'makhan': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],
    'chhurpi': [AllergenSourceInfo(allergen: AllergenCatalog.milk)],

    // Sesame
    'sesame': [AllergenSourceInfo(allergen: AllergenCatalog.sesame)],
    'sesame_seeds': [AllergenSourceInfo(allergen: AllergenCatalog.sesame)],
    'til': [AllergenSourceInfo(allergen: AllergenCatalog.sesame)],
    'tahini': [AllergenSourceInfo(allergen: AllergenCatalog.sesame)],

    // Gluten / Wheat
    'wheat_flour': [AllergenSourceInfo(allergen: AllergenCatalog.gluten)],
    'atta': [AllergenSourceInfo(allergen: AllergenCatalog.gluten)],
    'maida': [AllergenSourceInfo(allergen: AllergenCatalog.gluten)],
    'suji': [AllergenSourceInfo(allergen: AllergenCatalog.gluten)],
    'semolina': [AllergenSourceInfo(allergen: AllergenCatalog.gluten)],
    'barley': [AllergenSourceInfo(allergen: AllergenCatalog.gluten)],
    'jau': [AllergenSourceInfo(allergen: AllergenCatalog.gluten)],
    'oats': [AllergenSourceInfo(allergen: AllergenCatalog.gluten)],

    // Soy
    'tofu': [AllergenSourceInfo(allergen: AllergenCatalog.soy)],
    'soybean': [AllergenSourceInfo(allergen: AllergenCatalog.soy)],
    'bhatmas': [AllergenSourceInfo(allergen: AllergenCatalog.soy)],

    // Eggs & Seafood
    'egg': [AllergenSourceInfo(allergen: AllergenCatalog.eggs)],
    'eggs': [AllergenSourceInfo(allergen: AllergenCatalog.eggs)],
    'anda': [AllergenSourceInfo(allergen: AllergenCatalog.eggs)],
    'fish': [AllergenSourceInfo(allergen: AllergenCatalog.fish)],
    'machha': [AllergenSourceInfo(allergen: AllergenCatalog.fish)],
    'prawn': [AllergenSourceInfo(allergen: AllergenCatalog.crustaceans)],
    'shrimp': [AllergenSourceInfo(allergen: AllergenCatalog.crustaceans)],
  };

  /// Safe culinary substitution options.
  static final Map<String, List<SafeSubstitution>> substitutionCatalog = {
    'hing': [
      SafeSubstitution(
        ingredientId: 'pure_hing_resin',
        nameEn: 'Pure Compounded-Free Asafoetida Resin',
        nameNe: 'शुद्ध हिङ (गहुँरहित)',
        notesEn: '100% pure raw resin dissolved in hot water or ghee; contains zero wheat starch.',
        notesNe: 'गहुँको पिठो नमिसिएको शुद्ध प्राकृतिक हिङ।',
      ),
      SafeSubstitution(
        ingredientId: 'ginger_cumin_mix',
        nameEn: 'Fresh Ginger + Cumin Seed Blend',
        nameNe: 'अदुवा र जिराको धुलो',
        notesEn: 'Mimics the digestive and sulfurous warmth of hing without any gluten.',
        notesNe: 'पाचन सहयोगी र हिङको जस्तै स्वाद दिने सुरक्षित विकल्प।',
      ),
    ],
    'ghee': [
      SafeSubstitution(
        ingredientId: 'mustard_oil',
        nameEn: 'Cold-Pressed Mustard Oil',
        nameNe: 'तोरीको तेल',
        notesEn: 'Authentic Nepali high-smoke point cooking oil, 100% dairy-free.',
        notesNe: 'डेयरी-रहित शुद्ध परम्परागत नेपाली तेल।',
        allergens: {AllergenCatalog.mustard, AllergenCatalog.mustardOil},
      ),
      SafeSubstitution(
        ingredientId: 'sunflower_oil',
        nameEn: 'Refined Sunflower Oil',
        nameNe: 'सूर्यमुखी तेल',
        notesEn: 'Neutral taste, completely free of dairy and mustard allergens.',
        notesNe: 'कुनै पनि एलर्जी नभएको तटस्थ तेल।',
      ),
    ],
    'mustard_oil': [
      SafeSubstitution(
        ingredientId: 'sunflower_oil',
        nameEn: 'Sunflower Oil',
        nameNe: 'सूर्यमुखी तेल',
        notesEn: 'Safe alternative for mustard allergy.',
        notesNe: 'तोरीको एलर्जी भएकाहरूका लागि सुरक्षित।',
      ),
    ],
    'peanut_butter': [
      SafeSubstitution(
        ingredientId: 'sunflower_seed_butter',
        nameEn: 'Sunflower Seed Butter (SunButter)',
        nameNe: 'सूर्यमुखी दानाको बटर',
        notesEn: 'Nut-free, peanut-free creamy substitute with rich roasted flavor.',
        notesNe: 'बदाम एलर्जी नहुने सुरक्षित विकल्प।',
      ),
    ],
    'paneer': [
      SafeSubstitution(
        ingredientId: 'firm_tofu',
        nameEn: 'Firm Tofu',
        nameNe: 'टोफु (भटमास पनिर)',
        notesEn: '100% plant-based dairy-free protein cube.',
        notesNe: 'डेयरी-रहित भटमासबाट बनेको पनिर।',
        allergens: {AllergenCatalog.soy},
      ),
      SafeSubstitution(
        ingredientId: 'chickpea_paneer',
        nameEn: 'Chickpea Flour Tofu (Shan Tofu)',
        nameNe: 'चनाको पनिर (शान टोफु)',
        notesEn: 'Dairy-free, soy-free protein made from besan (gram flour).',
        notesNe: 'डेयरी र भटमास दुवै नभएको चनाको पिठोबाट बन्ने प्रोटिन।',
      ),
    ],
    'soy_sauce': [
      SafeSubstitution(
        ingredientId: 'coconut_aminos',
        nameEn: 'Coconut Aminos',
        nameNe: 'नरिवल अमिनोज',
        notesEn: 'Naturally soy-free, gluten-free savory seasoning.',
        notesNe: 'भटमास र ग्लुटेन दुवै नभएको प्राकृतिक सस।',
      ),
    ],
    'wheat_flour': [
      SafeSubstitution(
        ingredientId: 'rice_flour',
        nameEn: 'Rice Flour',
        nameNe: 'चामलको पिठो',
        notesEn: 'Gluten-free traditional flour.',
        notesNe: 'ग्लुटेन-रहित चामलको पिठो।',
      ),
      SafeSubstitution(
        ingredientId: 'millet_flour',
        nameEn: 'Finger Millet Flour (Kodo)',
        nameNe: 'कोदोको पिठो',
        notesEn: 'Nutrient-rich, gluten-free ancient grain.',
        notesNe: 'ग्लुटेन-रहित पौष्टिक कोदोको पिठो।',
      ),
    ],
    'onion': [
      SafeSubstitution(
        ingredientId: 'cabbage_ginger',
        nameEn: 'Finely Chopped Cabbage + Fresh Ginger',
        nameNe: 'मसिनो बन्दा र अदुवा',
        notesEn: 'Provides texture and aroma for Jain and Vrata fasting dishes.',
        notesNe: 'जैन तथा व्रतका लागि प्याजको सुरक्षित विकल्प।',
      ),
    ],
    'garlic': [
      SafeSubstitution(
        ingredientId: 'pure_hing',
        nameEn: 'Pure Gluten-Free Hing Pinch',
        nameNe: 'शुद्ध हिङको थोरै धुलो',
        notesEn: 'Gives pungent allium depth without onion or garlic bulbs.',
        notesNe: 'लसुन-प्याज बिना स्वाद दिने विकल्प।',
      ),
    ],
  };

  /// Non-vegetarian ingredient IDs.
  static const Set<String> meatFishIngredients = {
    'mutton',
    'khasi_ko_masu',
    'goat_meat',
    'chicken',
    'kukhura_ko_masu',
    'buff',
    'ranga_ko_masu',
    'pork',
    'sungur_ko_masu',
    'fish',
    'machha',
    'sukuti_machha',
    'sidra',
    'egg',
    'eggs',
    'anda',
    'prawn',
    'shrimp',
    'crab',
  };

  /// Animal dairy ingredient IDs.
  static const Set<String> animalDairyIngredients = {
    'ghee',
    'clarified_butter',
    'milk',
    'dudh',
    'curd',
    'dahi',
    'yogurt',
    'paneer',
    'butter',
    'makhan',
    'chhurpi',
    'malai',
    'cream',
    'khoa',
    'khuwa',
  };

  /// Root vegetables strictly prohibited in Jain vegetarian diet.
  static const Set<String> rootVegetablesJain = {
    'potato',
    'alu',
    'onion',
    'pyaz',
    'garlic',
    'lasun',
    'ginger',
    'aduwa',
    'radish',
    'mula',
    'carrot',
    'gajar',
    'beetroot',
    'chukandar',
    'sweet_potato',
    'sakarkhanda',
    'taro',
    'pindalu',
    'colocasia',
  };

  /// Grains, cereals and pulses forbidden during strict Hindu fasting (Vrata / Ekadashi).
  static const Set<String> hinduFastingForbidden = {
    'rice',
    'chamal',
    'bhat',
    'wheat_flour',
    'atta',
    'maida',
    'suji',
    'barley',
    'jau',
    'corn',
    'makai',
    'millet',
    'kodo',
    'lentils',
    'dal',
    'musuro_dal',
    'mas_ko_dal',
    'chana_dal',
    'rahar_dal',
    'soybean',
    'bhatmas',
    'onion',
    'pyaz',
    'garlic',
    'lasun',
  };

  /// Normalizes an ingredient identifier for safe lookup.
  static String normalizeKey(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  /// Returns all allergens associated with an ingredient, including hidden sources.
  static List<AllergenSourceInfo> getAllergensForIngredient(
    String ingredientId, {
    List<String> declaredAllergens = const [],
  }) {
    final normalized = normalizeKey(ingredientId);
    final results = <AllergenSourceInfo>[];
    final seen = <String>{};

    // 1. Check known built-in allergen and hidden source catalog
    if (ingredientAllergens.containsKey(normalized)) {
      for (final info in ingredientAllergens[normalized]!) {
        if (seen.add(info.allergen)) {
          results.add(info);
        }
      }
    }

    // 2. Add declared allergens from RegionPack metadata if not already present
    for (final allergen in declaredAllergens) {
      final normAllergen = allergen.toLowerCase().trim();
      if (seen.add(normAllergen)) {
        results.add(AllergenSourceInfo(allergen: normAllergen, isHidden: false));
      }
    }

    return results;
  }

  /// Deterministically checks a recipe against household allergy profiles and dietary rules.
  static RecipeSafetyVerdict checkRecipeSafety({
    required List<String> ingredientIds,
    Map<String, List<String>>? declaredIngredientAllergens,
    required List<MemberAllergyProfile> allergyProfiles,
    List<DietaryRule> dietaryRules = const [],
  }) {
    final conflicts = <SafetyConflict>[];
    bool hasSevere = false;
    bool hasHidden = false;

    // Index allergy profiles for O(1) lookup
    final memberAllergies = <String, MemberAllergyProfile>{};
    for (final profile in allergyProfiles) {
      memberAllergies[profile.allergen.toLowerCase().trim()] = profile;
    }

    // Check each ingredient in the recipe
    for (final rawIngredient in ingredientIds) {
      final normId = normalizeKey(rawIngredient);
      final declared = declaredIngredientAllergens?[rawIngredient] ??
          declaredIngredientAllergens?[normId] ??
          const [];

      final allergenSources = getAllergensForIngredient(
        normId,
        declaredAllergens: declared,
      );

      // Check Allergen Conflicts
      for (final source in allergenSources) {
        if (memberAllergies.containsKey(source.allergen)) {
          final profile = memberAllergies[source.allergen]!;
          final isSevere = profile.severity == AllergySeverity.severe;
          if (isSevere) {
            hasSevere = true;
          }
          if (source.isHidden) {
            hasHidden = true;
          }

          final memberDesc = profile.memberName != null
              ? ' for ${profile.memberName}'
              : '';
          final hiddenPrefix = source.isHidden ? '[HIDDEN ALLERGEN] ' : '';
          final reason = '$hiddenPrefix$rawIngredient contains ${source.allergen}$memberDesc.'
              '${source.explanation != null ? ' ${source.explanation}' : ''}';

          conflicts.add(SafetyConflict(
            ingredientId: rawIngredient,
            ingredientName: rawIngredient,
            allergen: source.allergen,
            severity: profile.severity,
            isHiddenSource: source.isHidden,
            reason: reason,
            suggestedSubstitutions: getSafeSubstitutions(
              ingredientId: normId,
              memberAllergies: allergyProfiles,
              dietaryRules: dietaryRules,
            ),
          ));
        }
      }

      // Check Dietary Rule Violations
      for (final rule in dietaryRules) {
        final violationReason = _checkDietaryViolation(normId, rawIngredient, rule);
        if (violationReason != null) {
          hasSevere = true; // Dietary rules are strict blocking violations
          conflicts.add(SafetyConflict(
            ingredientId: rawIngredient,
            ingredientName: rawIngredient,
            isDietaryViolation: true,
            dietaryRule: rule,
            reason: violationReason,
            suggestedSubstitutions: getSafeSubstitutions(
              ingredientId: normId,
              memberAllergies: allergyProfiles,
              dietaryRules: dietaryRules,
            ),
          ));
        }
      }
    }

    final isSafe = conflicts.isEmpty;
    final isAllowedInAutoPlan = !hasSevere;

    String? primaryWarning;
    if (hasSevere) {
      primaryWarning = '🚨 DANGER: Contains severe allergens or dietary violations. Auto-planning blocked.';
    } else if (conflicts.isNotEmpty) {
      primaryWarning = '⚠️ Warning: Contains mild or moderate allergens. Review safe substitutions.';
    }

    return RecipeSafetyVerdict(
      isSafe: isSafe,
      isAllowedInAutoPlan: isAllowedInAutoPlan,
      hasSevereConflict: hasSevere,
      hasHiddenAllergens: hasHidden,
      conflicts: conflicts,
      primaryWarning: primaryWarning,
    );
  }

  /// Verifies if an ingredient violates a dietary rule.
  static String? _checkDietaryViolation(
    String normId,
    String rawName,
    DietaryRule rule,
  ) {
    switch (rule) {
      case DietaryRule.vegetarian:
      case DietaryRule.lactoVegetarian:
        if (meatFishIngredients.contains(normId)) {
          return '$rawName is meat, fish, or poultry, violating vegetarian diet.';
        }
        break;

      case DietaryRule.vegan:
        if (meatFishIngredients.contains(normId)) {
          return '$rawName is an animal product, violating vegan diet.';
        }
        if (animalDairyIngredients.contains(normId)) {
          return '$rawName is an animal dairy product, violating vegan diet.';
        }
        break;

      case DietaryRule.jainVegetarian:
        if (meatFishIngredients.contains(normId)) {
          return '$rawName violates Jain vegetarian diet.';
        }
        if (rootVegetablesJain.contains(normId)) {
          return '$rawName is an underground root vegetable, strictly prohibited in Jain diet.';
        }
        break;

      case DietaryRule.halal:
        if (normId.contains('pork') || normId.contains('sungur') || normId.contains('alcohol') || normId.contains('wine')) {
          return '$rawName violates Halal dietary rules.';
        }
        break;

      case DietaryRule.kosher:
        if (normId.contains('pork') || normId.contains('shellfish') || normId.contains('prawn') || normId.contains('crab')) {
          return '$rawName violates Kosher dietary rules.';
        }
        break;

      case DietaryRule.hinduFasting:
        if (meatFishIngredients.contains(normId)) {
          return '$rawName is not permitted during Vrata / Ekadashi fasting.';
        }
        if (hinduFastingForbidden.contains(normId)) {
          return '$rawName is a forbidden grain, pulse, or allium during Hindu fasting.';
        }
        break;
    }
    return null;
  }

  /// Returns safe substitutions that do not trigger the user's active allergens or dietary rules.
  static List<SafeSubstitution> getSafeSubstitutions({
    required String ingredientId,
    required List<MemberAllergyProfile> memberAllergies,
    List<DietaryRule> dietaryRules = const [],
  }) {
    final normId = normalizeKey(ingredientId);
    final candidates = substitutionCatalog[normId] ?? const [];
    final activeAllergenSet = memberAllergies.map((p) => p.allergen.toLowerCase().trim()).toSet();

    final safeList = <SafeSubstitution>[];

    for (final candidate in candidates) {
      // Check if candidate introduces an active allergen
      final candidateAllergens = candidate.allergens.map((a) => a.toLowerCase().trim()).toSet();
      if (candidateAllergens.any(activeAllergenSet.contains)) {
        continue;
      }

      // Check if candidate violates any dietary rule
      bool violatesDiet = false;
      for (final rule in dietaryRules) {
        if (_checkDietaryViolation(candidate.ingredientId, candidate.nameEn, rule) != null) {
          violatesDiet = true;
          break;
        }
      }

      if (!violatesDiet) {
        safeList.add(candidate);
      }
    }

    return safeList;
  }

  /// Deterministic recipe filter: filters a list of recipes, strictly omitting any with severe allergen conflicts.
  static List<T> filterRecipesForAutoPlan<T>({
    required List<T> recipes,
    required List<String> Function(T recipe) getIngredients,
    Map<String, List<String>>? declaredIngredientAllergens,
    required List<MemberAllergyProfile> allergyProfiles,
    List<DietaryRule> dietaryRules = const [],
  }) {
    return recipes.where((recipe) {
      final ingredients = getIngredients(recipe);
      final verdict = checkRecipeSafety(
        ingredientIds: ingredients,
        declaredIngredientAllergens: declaredIngredientAllergens,
        allergyProfiles: allergyProfiles,
        dietaryRules: dietaryRules,
      );
      return verdict.isAllowedInAutoPlan;
    }).toList();
  }
}
