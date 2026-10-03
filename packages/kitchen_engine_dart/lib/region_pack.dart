library;

class RegionPackManifest {
  final String id;
  final String version;
  final String name;
  final String country;
  final String countryCode;
  final String region;
  final String status;
  final int elevationMeters;
  final String defaultLanguage;
  final String calendar;
  final String seasonSystem;

  const RegionPackManifest({
    required this.id,
    required this.version,
    required this.name,
    required this.country,
    required this.countryCode,
    required this.region,
    required this.status,
    required this.elevationMeters,
    required this.defaultLanguage,
    required this.calendar,
    required this.seasonSystem,
  });

  factory RegionPackManifest.fromJson(Map<String, dynamic> json) {
    return RegionPackManifest(
      id: json['id'] as String,
      version: json['version'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      countryCode: json['countryCode'] as String,
      region: json['region'] as String,
      status: json['status'] as String,
      elevationMeters: json['elevationMeters'] as int,
      defaultLanguage: json['defaultLanguage'] as String,
      calendar: json['calendar'] as String,
      seasonSystem: json['seasonSystem'] as String,
    );
  }
}

class RegionIngredient {
  final String id;
  final String nameEn;
  final String nameNe;
  final List<String> aliases;
  final String category;
  final String standardUnit;
  final int marketPackageGrams;
  final int storageDays;
  final List<String> allergens;
  final Map<String, String> availability;

  const RegionIngredient({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.aliases,
    required this.category,
    required this.standardUnit,
    required this.marketPackageGrams,
    required this.storageDays,
    required this.allergens,
    required this.availability,
  });

  factory RegionIngredient.fromJson(Map<String, dynamic> json) {
    return RegionIngredient(
      id: json['id'] as String,
      nameEn: json['nameEn'] as String,
      nameNe: json['nameNe'] as String,
      aliases: (json['aliases'] as List<dynamic>).cast<String>(),
      category: json['category'] as String,
      standardUnit: json['standardUnit'] as String,
      marketPackageGrams: json['marketPackageGrams'] as int,
      storageDays: json['storageDays'] as int,
      allergens: (json['allergens'] as List<dynamic>).cast<String>(),
      availability: (json['availability'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}

class RecipeWhistleProfile {
  final bool enabled;
  final int recommendedWhistles;
  final int altitudeWhistleOffsetKathmandu;
  final String heatLevel;
  final String releaseType;

  const RecipeWhistleProfile({
    required this.enabled,
    required this.recommendedWhistles,
    required this.altitudeWhistleOffsetKathmandu,
    required this.heatLevel,
    required this.releaseType,
  });

  int effectiveWhistlesForKathmandu() =>
      recommendedWhistles + altitudeWhistleOffsetKathmandu;

  factory RecipeWhistleProfile.fromJson(Map<String, dynamic> json) {
    return RecipeWhistleProfile(
      enabled: json['enabled'] as bool? ?? false,
      recommendedWhistles: json['recommendedWhistles'] as int? ?? 0,
      altitudeWhistleOffsetKathmandu:
          json['altitudeWhistleOffsetKathmandu'] as int? ?? 0,
      heatLevel: json['heatLevel'] as String? ?? 'medium',
      releaseType: json['releaseType'] as String? ?? 'natural',
    );
  }
}

class RecipeIngredientItem {
  final String ingredientId;
  final double quantity;
  final String unit;
  final String? notes;

  const RecipeIngredientItem({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.notes,
  });

  factory RecipeIngredientItem.fromJson(Map<String, dynamic> json) {
    return RecipeIngredientItem(
      ingredientId: json['ingredientId'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      notes: json['notes'] as String?,
    );
  }
}

class RegionRecipe {
  final String id;
  final String titleEn;
  final String titleNe;
  final String category;
  final String cuisine;
  final List<String> dietary;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String difficulty;
  final RecipeWhistleProfile pressureCooker;
  final List<RecipeIngredientItem> ingredients;
  final List<String> seasonality;
  final List<String> tags;

  const RegionRecipe({
    required this.id,
    required this.titleEn,
    required this.titleNe,
    required this.category,
    required this.cuisine,
    required this.dietary,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.difficulty,
    required this.pressureCooker,
    required this.ingredients,
    required this.seasonality,
    required this.tags,
  });

  factory RegionRecipe.fromJson(Map<String, dynamic> json) {
    return RegionRecipe(
      id: json['id'] as String,
      titleEn: json['titleEn'] as String,
      titleNe: json['titleNe'] as String,
      category: json['category'] as String,
      cuisine: json['cuisine'] as String,
      dietary: (json['dietary'] as List<dynamic>).cast<String>(),
      prepTimeMinutes: json['prepTimeMinutes'] as int,
      cookTimeMinutes: json['cookTimeMinutes'] as int,
      servings: json['servings'] as int,
      difficulty: json['difficulty'] as String,
      pressureCooker: RecipeWhistleProfile.fromJson(
          json['pressureCooker'] as Map<String, dynamic>),
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((i) => RecipeIngredientItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      seasonality: (json['seasonality'] as List<dynamic>).cast<String>(),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
    );
  }
}

class RegionFestival {
  final String id;
  final String nameEn;
  final String nameNe;
  final String tithi;
  final String approxGregorianMonth;
  final String descriptionEn;
  final String descriptionNe;
  final List<String> keyDishes;

  const RegionFestival({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.tithi,
    required this.approxGregorianMonth,
    required this.descriptionEn,
    required this.descriptionNe,
    required this.keyDishes,
  });

  factory RegionFestival.fromJson(Map<String, dynamic> json) {
    final food = json['foodTraditions'] as Map<String, dynamic>? ?? {};
    return RegionFestival(
      id: json['id'] as String,
      nameEn: json['nameEn'] as String,
      nameNe: json['nameNe'] as String,
      tithi: json['tithi'] as String,
      approxGregorianMonth: json['approxGregorianMonth'] as String,
      descriptionEn: json['descriptionEn'] as String,
      descriptionNe: json['descriptionNe'] as String,
      keyDishes: (food['keyDishes'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
