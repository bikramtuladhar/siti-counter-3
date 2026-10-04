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
  final String currencyCode;
  final String currencySymbol;
  final List<String> marketUnits;
  final List<String> languages;

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
    this.currencyCode = 'NPR',
    this.currencySymbol = 'रू',
    this.marketUnits = const ['kg', 'g'],
    this.languages = const ['en'],
  });

  factory RegionPackManifest.fromJson(Map<String, dynamic> json) {
    final currency = json['currency'] as Map<String, dynamic>?;
    final units = json['units'] as Map<String, dynamic>?;
    final languagesList = (json['languages'] as List<dynamic>?)?.cast<String>();
    return RegionPackManifest(
      id: json['id'] as String,
      version: json['version'] as String? ?? '1.0.0',
      name: json['name'] as String,
      country: json['country'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      region: json['region'] as String? ?? '',
      status: json['status'] as String? ?? 'verified',
      elevationMeters: json['elevationMeters'] as int? ?? 1400,
      defaultLanguage: json['defaultLanguage'] as String? ?? 'en',
      calendar: json['calendar'] as String? ?? 'gregorian',
      seasonSystem: json['seasonSystem'] as String? ?? 'six-ritus',
      currencyCode: currency != null
          ? (currency['code'] as String? ?? 'NPR')
          : (json['currencyCode'] as String? ?? 'NPR'),
      currencySymbol: currency != null
          ? (currency['symbol'] as String? ?? 'रू')
          : (json['currencySymbol'] as String? ?? 'रू'),
      marketUnits: units != null && units['market'] != null
          ? (units['market'] as List<dynamic>).cast<String>()
          : (json['marketUnits'] as List<dynamic>?)?.cast<String>() ??
              const ['kg', 'g'],
      languages: languagesList ??
          (json['languages'] as List<dynamic>?)?.cast<String>() ??
          const ['en'],
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

class RecipeElevationBand {
  final int testedElevationMeters;
  final double boilingPointCelsius;
  final double waterMultiplier;

  const RecipeElevationBand({
    required this.testedElevationMeters,
    required this.boilingPointCelsius,
    required this.waterMultiplier,
  });

  factory RecipeElevationBand.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RecipeElevationBand(
        testedElevationMeters: 1400,
        boilingPointCelsius: 95.3,
        waterMultiplier: 1.15,
      );
    }
    return RecipeElevationBand(
      testedElevationMeters: json['testedElevationMeters'] as int? ?? 1400,
      boilingPointCelsius: (json['boilingPointCelsius'] as num?)?.toDouble() ?? 95.3,
      waterMultiplier: (json['waterMultiplier'] as num?)?.toDouble() ?? 1.15,
    );
  }
}

class RecipeStepItem {
  final int stepNumber;
  final String instructionEn;
  final String instructionNe;
  final int? timerMinutes;
  final int? whistles;

  const RecipeStepItem({
    required this.stepNumber,
    required this.instructionEn,
    required this.instructionNe,
    this.timerMinutes,
    this.whistles,
  });

  factory RecipeStepItem.fromJson(Map<String, dynamic> json) {
    return RecipeStepItem(
      stepNumber: json['stepNumber'] as int? ?? 1,
      instructionEn: json['instructionEn'] as String? ?? '',
      instructionNe: json['instructionNe'] as String? ?? '',
      timerMinutes: json['timerMinutes'] as int?,
      whistles: json['whistles'] as int?,
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
  final RecipeElevationBand? elevationBand;
  final List<RecipeIngredientItem> ingredients;
  final List<RecipeStepItem> steps;
  final List<String> seasonality;
  final List<String> tags;
  final double rating;
  final int caloriesPerServing;

  /// Estimated market cost of one serving, in the pack manifest's currency.
  final int costEstimateNpr;

  /// Grams of protein in one serving.
  final double proteinGramsPerServing;

  /// Origin region pack ID if layered from a specific pack
  final String? originPackId;

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
    this.elevationBand,
    required this.ingredients,
    this.steps = const [],
    required this.seasonality,
    required this.tags,
    this.rating = 4.8,
    this.caloriesPerServing = 220,
    this.costEstimateNpr = 65,
    this.proteinGramsPerServing = 0,
    this.originPackId,
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
      elevationBand: json['elevationBand'] != null
          ? RecipeElevationBand.fromJson(
              json['elevationBand'] as Map<String, dynamic>)
          : null,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((i) => RecipeIngredientItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => RecipeStepItem.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      seasonality: (json['seasonality'] as List<dynamic>).cast<String>(),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      caloriesPerServing: json['caloriesPerServing'] as int? ?? 220,
      costEstimateNpr: json['costEstimateNpr'] as int? ?? 65,
      proteinGramsPerServing:
          (json['proteinGramsPerServing'] as num?)?.toDouble() ?? 0,
      originPackId: json['originPackId'] as String?,
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

class RituSeason {
  final String id;
  final String name;
  final List<String> monthsBS;
  final List<String> monthsGregorian;
  final List<String> signatureProduce;

  const RituSeason({
    required this.id,
    required this.name,
    required this.monthsBS,
    required this.monthsGregorian,
    required this.signatureProduce,
  });

  factory RituSeason.fromJson(Map<String, dynamic> json) {
    return RituSeason(
      id: json['id'] as String,
      name: json['name'] as String,
      monthsBS: (json['monthsBS'] as List<dynamic>).cast<String>(),
      monthsGregorian: (json['monthsGregorian'] as List<dynamic>).cast<String>(),
      signatureProduce: (json['signatureProduce'] as List<dynamic>).cast<String>(),
    );
  }
}

class RegionSeasonality {
  final String regionId;
  final List<RituSeason> ritus;

  const RegionSeasonality({
    required this.regionId,
    required this.ritus,
  });

  factory RegionSeasonality.fromJson(Map<String, dynamic> json) {
    return RegionSeasonality(
      regionId: json['regionId'] as String,
      ritus: (json['ritus'] as List<dynamic>)
          .map((r) => RituSeason.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum AvailabilityLevel {
  peak,
  inSeason,
  available,
  limited,
  outOfSeason;

  static AvailabilityLevel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'peak':
        return AvailabilityLevel.peak;
      case 'in_season':
      case 'inseason':
        return AvailabilityLevel.inSeason;
      case 'available':
        return AvailabilityLevel.available;
      case 'limited':
        return AvailabilityLevel.limited;
      case 'out_of_season':
      case 'outofseason':
      default:
        return AvailabilityLevel.outOfSeason;
    }
  }

  String get labelEn {
    switch (this) {
      case AvailabilityLevel.peak:
        return 'Peak Season';
      case AvailabilityLevel.inSeason:
        return 'In Season';
      case AvailabilityLevel.available:
        return 'Available';
      case AvailabilityLevel.limited:
        return 'Limited';
      case AvailabilityLevel.outOfSeason:
        return 'Out of Season';
    }
  }

  String get labelNe {
    switch (this) {
      case AvailabilityLevel.peak:
        return 'उत्कृष्ट सिजन (Peak)';
      case AvailabilityLevel.inSeason:
        return 'सिजनमा (In Season)';
      case AvailabilityLevel.available:
        return 'उपलब्ध (Available)';
      case AvailabilityLevel.limited:
        return 'सीमित (Limited)';
      case AvailabilityLevel.outOfSeason:
        return 'अफ सिजन (Off-season)';
    }
  }
}

class PreservationSuggestion {
  final String id;
  final String titleEn;
  final String titleNe;
  final String descriptionEn;
  final String descriptionNe;
  final String targetSeason;
  final List<String> primaryIngredients;
  final String method;

  const PreservationSuggestion({
    required this.id,
    required this.titleEn,
    required this.titleNe,
    required this.descriptionEn,
    required this.descriptionNe,
    required this.targetSeason,
    required this.primaryIngredients,
    required this.method,
  });

  factory PreservationSuggestion.fromJson(Map<String, dynamic> json) {
    return PreservationSuggestion(
      id: json['id'] as String,
      titleEn: json['titleEn'] as String,
      titleNe: json['titleNe'] as String,
      descriptionEn: json['descriptionEn'] as String,
      descriptionNe: json['descriptionNe'] as String,
      targetSeason: json['targetSeason'] as String,
      primaryIngredients: (json['primaryIngredients'] as List<dynamic>).cast<String>(),
      method: json['method'] as String,
    );
  }
}

class RegionPack {
  final RegionPackManifest manifest;
  final RegionSeasonality seasonality;
  final List<RegionIngredient> ingredients;
  final List<RegionRecipe> recipes;
  final List<RegionFestival> festivals;
  final List<PreservationSuggestion> preservationSuggestions;

  const RegionPack({
    required this.manifest,
    required this.seasonality,
    required this.ingredients,
    required this.recipes,
    required this.festivals,
    this.preservationSuggestions = const [],
  });

  List<RegionRecipe> getRecipesForIngredient(String ingredientId) {
    return recipes
        .where((r) => r.ingredients.any((i) => i.ingredientId == ingredientId))
        .toList();
  }

  AvailabilityLevel getIngredientAvailability(String ingredientId, String rituId) {
    final ing = ingredients.cast<RegionIngredient?>().firstWhere(
          (i) => i?.id == ingredientId,
          orElse: () => null,
        );
    if (ing == null) return AvailabilityLevel.outOfSeason;
    final val = ing.availability[rituId];
    return AvailabilityLevel.fromString(val);
  }
}
