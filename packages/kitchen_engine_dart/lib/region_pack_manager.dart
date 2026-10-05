library;

import 'kitchen_engine.dart';
import 'region_pack.dart';

/// Catalog entry for discovering verified, community, or custom region packs.
class RegionPackCatalogEntry {
  final String id;
  final String name;
  final String nativeName;
  final String country;
  final String countryCode;
  final String status; // 'verified' | 'community' | 'custom'
  final String version;
  final String description;
  final int elevationMeters;
  final String climateZone;
  final String seasonSystem;
  final String defaultLanguage;
  final String calendar;
  final String currencyCode;
  final String currencySymbol;
  final List<String> marketUnits;
  final int sizeBytes;
  final int recipeCount;
  final int ingredientCount;
  final bool isBuiltIn;
  final String? downloadUrl;
  final bool isInstalled;

  const RegionPackCatalogEntry({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.country,
    required this.countryCode,
    required this.status,
    required this.version,
    required this.description,
    required this.elevationMeters,
    required this.climateZone,
    required this.seasonSystem,
    required this.defaultLanguage,
    required this.calendar,
    required this.currencyCode,
    required this.currencySymbol,
    required this.marketUnits,
    required this.sizeBytes,
    required this.recipeCount,
    required this.ingredientCount,
    this.isBuiltIn = false,
    this.downloadUrl,
    this.isInstalled = false,
  });

  RegionPackCatalogEntry copyWith({
    bool? isInstalled,
  }) {
    return RegionPackCatalogEntry(
      id: id,
      name: name,
      nativeName: nativeName,
      country: country,
      countryCode: countryCode,
      status: status,
      version: version,
      description: description,
      elevationMeters: elevationMeters,
      climateZone: climateZone,
      seasonSystem: seasonSystem,
      defaultLanguage: defaultLanguage,
      calendar: calendar,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      marketUnits: marketUnits,
      sizeBytes: sizeBytes,
      recipeCount: recipeCount,
      ingredientCount: ingredientCount,
      isBuiltIn: isBuiltIn,
      downloadUrl: downloadUrl,
      isInstalled: isInstalled ?? this.isInstalled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nativeName': nativeName,
        'country': country,
        'countryCode': countryCode,
        'status': status,
        'version': version,
        'description': description,
        'elevationMeters': elevationMeters,
        'climateZone': climateZone,
        'seasonSystem': seasonSystem,
        'defaultLanguage': defaultLanguage,
        'calendar': calendar,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'marketUnits': marketUnits,
        'sizeBytes': sizeBytes,
        'recipeCount': recipeCount,
        'ingredientCount': ingredientCount,
        'isBuiltIn': isBuiltIn,
        'downloadUrl': downloadUrl,
        'isInstalled': isInstalled,
      };

  factory RegionPackCatalogEntry.fromJson(Map<String, dynamic> json) =>
      RegionPackCatalogEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        nativeName: json['nativeName'] as String? ?? json['name'] as String,
        country: json['country'] as String,
        countryCode: json['countryCode'] as String,
        status: json['status'] as String? ?? 'verified',
        version: json['version'] as String? ?? '1.0.0',
        description: json['description'] as String? ?? '',
        elevationMeters: json['elevationMeters'] as int? ?? 1400,
        climateZone: json['climateZone'] as String? ?? 'subtropical',
        seasonSystem: json['seasonSystem'] as String? ?? 'six-ritus',
        defaultLanguage: json['defaultLanguage'] as String? ?? 'ne',
        calendar: json['calendar'] as String? ?? 'bikram-sambat',
        currencyCode: json['currencyCode'] as String? ?? 'NPR',
        currencySymbol: json['currencySymbol'] as String? ?? 'रू',
        marketUnits: (json['marketUnits'] as List<dynamic>?)?.cast<String>() ??
            const ['kg', 'g'],
        sizeBytes: json['sizeBytes'] as int? ?? 102400,
        recipeCount: json['recipeCount'] as int? ?? 0,
        ingredientCount: json['ingredientCount'] as int? ?? 0,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        downloadUrl: json['downloadUrl'] as String?,
        isInstalled: json['isInstalled'] as bool? ?? false,
      );
}

/// Active Region configuration supporting multi-pack diaspora mode.
class ActiveRegionConfig {
  final String primaryPackId;
  final List<String> secondaryPackIds;

  const ActiveRegionConfig({
    required this.primaryPackId,
    this.secondaryPackIds = const [],
  });

  bool get isDiasporaActive => secondaryPackIds.isNotEmpty;

  ActiveRegionConfig copyWith({
    String? primaryPackId,
    List<String>? secondaryPackIds,
  }) {
    return ActiveRegionConfig(
      primaryPackId: primaryPackId ?? this.primaryPackId,
      secondaryPackIds: secondaryPackIds ?? this.secondaryPackIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'primaryPackId': primaryPackId,
        'secondaryPackIds': secondaryPackIds,
      };

  factory ActiveRegionConfig.fromJson(Map<String, dynamic> json) =>
      ActiveRegionConfig(
        primaryPackId: json['primaryPackId'] as String? ?? 'nepal-bagmati',
        secondaryPackIds: (json['secondaryPackIds'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
      );
}

/// Household overrides that layer over installed packs without modifying them.
class HouseholdPackOverride {
  final int? elevationMeters;
  final List<String>? preferredUnits;
  final List<RegionIngredient>? customIngredients;
  final Map<String, int>? whistleOffsets;

  const HouseholdPackOverride({
    this.elevationMeters,
    this.preferredUnits,
    this.customIngredients,
    this.whistleOffsets,
  });

  HouseholdPackOverride copyWith({
    int? elevationMeters,
    List<String>? preferredUnits,
    List<RegionIngredient>? customIngredients,
    Map<String, int>? whistleOffsets,
  }) {
    return HouseholdPackOverride(
      elevationMeters: elevationMeters ?? this.elevationMeters,
      preferredUnits: preferredUnits ?? this.preferredUnits,
      customIngredients: customIngredients ?? this.customIngredients,
      whistleOffsets: whistleOffsets ?? this.whistleOffsets,
    );
  }

  Map<String, dynamic> toJson() => {
        if (elevationMeters != null) 'elevationMeters': elevationMeters,
        if (preferredUnits != null) 'preferredUnits': preferredUnits,
        if (whistleOffsets != null) 'whistleOffsets': whistleOffsets,
      };
}

/// Form input to author a new custom region.
class CustomRegionInput {
  final String id;
  final String name;
  final String nativeName;
  final String country;
  final String countryCode;
  final int elevationMeters;
  final String climateZone;
  final String seasonSystem;
  final List<String> marketUnits;
  final String defaultLanguage;
  final String calendar;
  final String currencyCode;
  final String currencySymbol;
  final List<RituSeason> seasons;
  final List<RegionIngredient> customIngredients;
  final List<RegionRecipe> customRecipes;

  const CustomRegionInput({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.country,
    required this.countryCode,
    required this.elevationMeters,
    required this.climateZone,
    required this.seasonSystem,
    required this.marketUnits,
    this.defaultLanguage = 'en',
    this.calendar = 'gregorian',
    this.currencyCode = 'USD',
    this.currencySymbol = '\$',
    this.seasons = const [],
    this.customIngredients = const [],
    this.customRecipes = const [],
  });

  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('Region ID is required');
    if (name.trim().isEmpty) errors.add('Region name is required');
    if (country.trim().isEmpty) errors.add('Country is required');
    if (elevationMeters < 0) errors.add('Elevation must be 0 meters or higher');
    if (marketUnits.isEmpty) errors.add('At least one market unit is required');
    return errors;
  }
}

/// Fully resolved cooking environment combining primary pack, diaspora secondary packs,
/// and household overrides.
class ResolvedRegionContext {
  final RegionPack primaryPack;
  final List<RegionPack> secondaryPacks;
  final HouseholdPackOverride? override;
  final int effectiveElevationMeters;
  final double effectiveBoilingPointCelsius;
  final String activeSeasonId;
  final String activeSeasonName;
  final List<RegionRecipe> combinedRecipes;
  final List<RegionIngredient> combinedIngredients;
  final List<RegionFestival> combinedFestivals;
  final List<String> effectiveMarketUnits;
  final String currencyCode;
  final String currencySymbol;

  const ResolvedRegionContext({
    required this.primaryPack,
    required this.secondaryPacks,
    this.override,
    required this.effectiveElevationMeters,
    required this.effectiveBoilingPointCelsius,
    required this.activeSeasonId,
    required this.activeSeasonName,
    required this.combinedRecipes,
    required this.combinedIngredients,
    required this.combinedFestivals,
    required this.effectiveMarketUnits,
    required this.currencyCode,
    required this.currencySymbol,
  });

  /// Check ingredient availability in current primary environment season
  AvailabilityLevel getIngredientAvailability(String ingredientId) {
    return primaryPack.getIngredientAvailability(ingredientId, activeSeasonId);
  }

  /// Calculates adjusted whistle count for a recipe cooked in this effective environment.
  int adjustWhistlesForRecipe(RegionRecipe recipe) {
    if (!recipe.pressureCooker.enabled) return 0;
    final base = recipe.pressureCooker.recommendedWhistles;
    final adjusted = AltitudeCalculator.adjustSitiCount(
      baseSiti: base,
      elevationMeters: effectiveElevationMeters.toDouble(),
    );
    final offset = override?.whistleOffsets?[recipe.id] ?? 0;
    return adjusted + offset;
  }
}

/// Manager service for browsing catalog, downloading/caching packs,
/// managing multi-pack active diaspora setup, authoring custom regions,
/// and layered resolution.
class RegionPackManager {
  final Map<String, RegionPack> _installedPacks = {};
  final List<RegionPackCatalogEntry> _catalog = [];
  ActiveRegionConfig _activeConfig;
  HouseholdPackOverride? _householdOverride;

  RegionPackManager({
    List<RegionPackCatalogEntry>? catalog,
    Map<String, RegionPack>? initialInstalledPacks,
    ActiveRegionConfig? activeConfig,
    HouseholdPackOverride? householdOverride,
  })  : _activeConfig = activeConfig ??
            const ActiveRegionConfig(primaryPackId: 'nepal-bagmati'),
        _householdOverride = householdOverride {
    if (catalog != null) {
      _catalog.addAll(catalog);
    } else {
      _catalog.addAll(defaultCatalog);
    }

    if (initialInstalledPacks != null) {
      _installedPacks.addAll(initialInstalledPacks);
    }
  }

  Map<String, RegionPack> get installedPacks => Map.unmodifiable(_installedPacks);
  ActiveRegionConfig get activeConfig => _activeConfig;
  HouseholdPackOverride? get householdOverride => _householdOverride;

  List<RegionPackCatalogEntry> get catalog {
    return _catalog.map((entry) {
      return entry.copyWith(isInstalled: _installedPacks.containsKey(entry.id));
    }).toList();
  }

  bool isInstalled(String packId) => _installedPacks.containsKey(packId);

  RegionPack? getPack(String packId) => _installedPacks[packId];

  /// Loads a bundled pack into installed cache.
  void loadBuiltInPack(RegionPack pack) {
    _installedPacks[pack.manifest.id] = pack;
  }

  /// Installs or updates a pack bundle in the offline cache.
  Future<void> installPack(RegionPack pack) async {
    _installedPacks[pack.manifest.id] = pack;
  }

  /// Installs a pack from catalog using pre-built sample data or provided downloaded bundle.
  Future<void> installFromCatalog(String packId, {RegionPack? downloadedPack}) async {
    final pack = downloadedPack ?? getSamplePack(packId);
    if (pack == null) {
      throw ArgumentError('Region pack not found in catalog: $packId');
    }
    await installPack(pack);
  }

  /// Uninstalls an installed pack. Built-in packs cannot be uninstalled.
  void uninstallPack(String packId) {
    final entry = _catalog.cast<RegionPackCatalogEntry?>().firstWhere(
          (c) => c?.id == packId,
          orElse: () => null,
        );
    if (entry?.isBuiltIn == true) {
      throw UnsupportedError('Built-in region pack $packId cannot be uninstalled.');
    }
    _installedPacks.remove(packId);

    // If active primary was uninstalled, fallback to built-in or first available
    if (_activeConfig.primaryPackId == packId) {
      _activeConfig = _activeConfig.copyWith(primaryPackId: 'nepal-bagmati');
    }
    if (_activeConfig.secondaryPackIds.contains(packId)) {
      final updated = List<String>.from(_activeConfig.secondaryPackIds)..remove(packId);
      _activeConfig = _activeConfig.copyWith(secondaryPackIds: updated);
    }
  }

  /// Sets the active primary residence pack.
  void setPrimaryPack(String packId) {
    if (!_installedPacks.containsKey(packId)) {
      final entry = _catalog.cast<RegionPackCatalogEntry?>().firstWhere(
            (c) => c?.id == packId,
            orElse: () => null,
          );
      if (entry != null) {
        final sample = getSamplePack(packId);
        if (sample != null) {
          _installedPacks[packId] = sample;
        } else {
          throw StateError('Pack $packId is not installed.');
        }
      } else {
        throw StateError('Pack $packId not found in catalog.');
      }
    }

    final updatedSecondaries = List<String>.from(_activeConfig.secondaryPackIds)
      ..remove(packId);
    _activeConfig = _activeConfig.copyWith(
      primaryPackId: packId,
      secondaryPackIds: updatedSecondaries,
    );
  }

  /// Adds a secondary heritage pack for diaspora households.
  void addSecondaryPack(String packId) {
    if (packId == _activeConfig.primaryPackId) return;
    if (_activeConfig.secondaryPackIds.contains(packId)) return;

    if (!_installedPacks.containsKey(packId)) {
      final sample = getSamplePack(packId);
      if (sample != null) {
        _installedPacks[packId] = sample;
      }
    }

    final updated = List<String>.from(_activeConfig.secondaryPackIds)..add(packId);
    _activeConfig = _activeConfig.copyWith(secondaryPackIds: updated);
  }

  /// Removes a secondary heritage pack.
  void removeSecondaryPack(String packId) {
    if (!_activeConfig.secondaryPackIds.contains(packId)) return;
    final updated = List<String>.from(_activeConfig.secondaryPackIds)..remove(packId);
    _activeConfig = _activeConfig.copyWith(secondaryPackIds: updated);
  }

  /// Authors and installs a custom user region pack.
  RegionPack createCustomRegion(CustomRegionInput input) {
    final errors = input.validate();
    if (errors.isNotEmpty) {
      throw ArgumentError('Invalid custom region input: ${errors.join(', ')}');
    }

    final defaultSeasons = input.seasons.isNotEmpty
        ? input.seasons
        : _buildDefaultSeasons(input.seasonSystem);

    final manifest = RegionPackManifest(
      id: input.id,
      version: '1.0.0',
      name: input.name,
      country: input.country,
      countryCode: input.countryCode,
      region: input.name,
      status: 'custom',
      elevationMeters: input.elevationMeters,
      defaultLanguage: input.defaultLanguage,
      calendar: input.calendar,
      seasonSystem: input.seasonSystem,
      currencyCode: input.currencyCode,
      currencySymbol: input.currencySymbol,
      marketUnits: input.marketUnits,
    );

    final pack = RegionPack(
      manifest: manifest,
      seasonality: RegionSeasonality(regionId: input.id, ritus: defaultSeasons),
      ingredients: input.customIngredients,
      recipes: input.customRecipes,
      festivals: const [],
      preservationSuggestions: const [],
    );

    _installedPacks[input.id] = pack;

    // Add to catalog
    _catalog.removeWhere((c) => c.id == input.id);
    _catalog.add(
      RegionPackCatalogEntry(
        id: input.id,
        name: input.name,
        nativeName: input.nativeName,
        country: input.country,
        countryCode: input.countryCode,
        status: 'custom',
        version: '1.0.0',
        description: 'User authored custom region: ${input.name}',
        elevationMeters: input.elevationMeters,
        climateZone: input.climateZone,
        seasonSystem: input.seasonSystem,
        defaultLanguage: input.defaultLanguage,
        calendar: input.calendar,
        currencyCode: input.currencyCode,
        currencySymbol: input.currencySymbol,
        marketUnits: input.marketUnits,
        sizeBytes: 15360,
        recipeCount: input.customRecipes.length,
        ingredientCount: input.customIngredients.length,
        isBuiltIn: false,
        isInstalled: true,
      ),
    );

    return pack;
  }

  /// Deletes a custom authored region pack.
  void deleteCustomRegion(String packId) {
    final entry = _catalog.cast<RegionPackCatalogEntry?>().firstWhere(
          (c) => c?.id == packId,
          orElse: () => null,
        );
    if (entry?.status != 'custom') {
      throw UnsupportedError('Only custom region packs can be deleted via this method.');
    }
    _catalog.removeWhere((c) => c.id == packId);
    _installedPacks.remove(packId);

    if (_activeConfig.primaryPackId == packId) {
      _activeConfig = _activeConfig.copyWith(primaryPackId: 'nepal-bagmati');
    }
    if (_activeConfig.secondaryPackIds.contains(packId)) {
      final updated = List<String>.from(_activeConfig.secondaryPackIds)..remove(packId);
      _activeConfig = _activeConfig.copyWith(secondaryPackIds: updated);
    }
  }

  /// Updates or clears household pack overrides.
  void setHouseholdOverride(HouseholdPackOverride? override) {
    _householdOverride = override;
  }

  /// Resolves the effective layered cooking context.
  ResolvedRegionContext resolveContext({DateTime? forDate}) {
    final targetDate = forDate ?? DateTime.now();

    final primaryPack = _installedPacks[_activeConfig.primaryPackId] ??
        getSamplePack(_activeConfig.primaryPackId) ??
        getSamplePack('nepal-bagmati')!;

    final secondaryPacks = <RegionPack>[];
    for (final id in _activeConfig.secondaryPackIds) {
      final sPack = _installedPacks[id] ?? getSamplePack(id);
      if (sPack != null) {
        secondaryPacks.add(sPack);
      }
    }

    final effectiveElevation = _householdOverride?.elevationMeters ??
        primaryPack.manifest.elevationMeters;
    final effectiveBoilingPoint =
        AltitudeCalculator.boilingPointCelsius(effectiveElevation.toDouble());

    // Resolve season for primary environment
    final activeSeason = _resolveSeason(
      primaryPack.manifest.seasonSystem,
      primaryPack.seasonality.ritus,
      targetDate,
    );

    // Combine recipes with deduplication and origin tracking
    final recipeMap = <String, RegionRecipe>{};
    for (final r in primaryPack.recipes) {
      recipeMap[r.id] = r;
    }
    for (final sec in secondaryPacks) {
      for (final r in sec.recipes) {
        if (!recipeMap.containsKey(r.id)) {
          recipeMap[r.id] = r;
        }
      }
    }

    // Combine ingredients with deduplication and household custom ingredients
    final ingredientMap = <String, RegionIngredient>{};
    for (final ing in primaryPack.ingredients) {
      ingredientMap[ing.id] = ing;
    }
    for (final sec in secondaryPacks) {
      for (final ing in sec.ingredients) {
        if (!ingredientMap.containsKey(ing.id)) {
          ingredientMap[ing.id] = ing;
        }
      }
    }
    if (_householdOverride?.customIngredients != null) {
      for (final ing in _householdOverride!.customIngredients!) {
        ingredientMap[ing.id] = ing;
      }
    }

    // Combine festivals
    final festivalMap = <String, RegionFestival>{};
    for (final f in primaryPack.festivals) {
      festivalMap[f.id] = f;
    }
    for (final sec in secondaryPacks) {
      for (final f in sec.festivals) {
        if (!festivalMap.containsKey(f.id)) {
          festivalMap[f.id] = f;
        }
      }
    }

    // Effective market units
    final effectiveUnits = _householdOverride?.preferredUnits ??
        primaryPack.manifest.marketUnits;

    return ResolvedRegionContext(
      primaryPack: primaryPack,
      secondaryPacks: secondaryPacks,
      override: _householdOverride,
      effectiveElevationMeters: effectiveElevation,
      effectiveBoilingPointCelsius: effectiveBoilingPoint,
      activeSeasonId: activeSeason.id,
      activeSeasonName: activeSeason.name,
      combinedRecipes: recipeMap.values.toList(),
      combinedIngredients: ingredientMap.values.toList(),
      combinedFestivals: festivalMap.values.toList(),
      effectiveMarketUnits: effectiveUnits,
      currencyCode: primaryPack.manifest.currencyCode,
      currencySymbol: primaryPack.manifest.currencySymbol,
    );
  }

  static RituSeason _resolveSeason(
    String seasonSystem,
    List<RituSeason> seasons,
    DateTime date,
  ) {
    final month = date.month;

    if (seasonSystem == 'six-ritus') {
      // 1: Shishir, 2: Shishir, 3: Basanta, 4: Basanta, 5: Grishma, 6: Grishma,
      // 7: Barsha, 8: Barsha, 9: Sharad, 10: Sharad, 11: Hemanta, 12: Hemanta
      String targetId;
      if (month == 3 || month == 4) {
        targetId = 'basanta';
      } else if (month == 5 || month == 6) {
        targetId = 'grishma';
      } else if (month == 7 || month == 8) {
        targetId = 'barsha';
      } else if (month == 9 || month == 10) {
        targetId = 'sharad';
      } else if (month == 11 || month == 12) {
        targetId = 'hemanta';
      } else {
        targetId = 'shishir';
      }
      return seasons.cast<RituSeason?>().firstWhere(
            (s) =>
                s?.id == targetId ||
                (targetId == 'basanta' && s?.id == 'vasant') ||
                (targetId == 'barsha' && s?.id == 'varsha') ||
                (targetId == 'hemanta' && s?.id == 'hemant'),
            orElse: () => seasons.isNotEmpty
                ? seasons.first
                : const RituSeason(
                    id: 'sharad',
                    name: 'शरद् ऋतु (Sharad)',
                    monthsBS: ['Ashwin', 'Kartik'],
                    monthsGregorian: ['September', 'October'],
                    signatureProduce: ['cauliflower', 'radish', 'mustard_greens'],
                  ),
          )!;
    }

    if (seasonSystem == 'four-seasons-southern') {
      // Southern Hemisphere (e.g. Sydney Australia)
      // Sep, Oct, Nov: Spring
      // Dec, Jan, Feb: Summer
      // Mar, Apr, May: Autumn
      // Jun, Jul, Aug: Winter
      String targetId;
      if (month >= 9 && month <= 11) {
        targetId = 'spring';
      } else if (month == 12 || month == 1 || month == 2) {
        targetId = 'summer';
      } else if (month >= 3 && month <= 5) {
        targetId = 'autumn';
      } else {
        targetId = 'winter';
      }
      return seasons.cast<RituSeason?>().firstWhere(
            (s) => s?.id == targetId,
            orElse: () => seasons.isNotEmpty
                ? seasons.first
                : RituSeason(
                    id: targetId,
                    name: targetId[0].toUpperCase() + targetId.substring(1),
                    monthsBS: const [],
                    monthsGregorian: const [],
                    signatureProduce: const [],
                  ),
          )!;
    }

    if (seasonSystem == 'four-seasons') {
      // Northern Hemisphere (e.g. UK London)
      // Mar, Apr, May: Spring
      // Jun, Jul, Aug: Summer
      // Sep, Oct, Nov: Autumn
      // Dec, Jan, Feb: Winter
      String targetId;
      if (month >= 3 && month <= 5) {
        targetId = 'spring';
      } else if (month >= 6 && month <= 8) {
        targetId = 'summer';
      } else if (month >= 9 && month <= 11) {
        targetId = 'autumn';
      } else {
        targetId = 'winter';
      }
      return seasons.cast<RituSeason?>().firstWhere(
            (s) => s?.id == targetId,
            orElse: () => seasons.isNotEmpty
                ? seasons.first
                : RituSeason(
                    id: targetId,
                    name: targetId[0].toUpperCase() + targetId.substring(1),
                    monthsBS: const [],
                    monthsGregorian: const [],
                    signatureProduce: const [],
                  ),
          )!;
    }

    if (seasonSystem == 'wet-dry') {
      // Tropical wet/dry (e.g. Lagos Nigeria)
      // Apr - Oct: Rainy Season
      // Nov - Mar: Dry Season
      final isRainy = month >= 4 && month <= 10;
      final targetId = isRainy ? 'rainy' : 'dry';
      return seasons.cast<RituSeason?>().firstWhere(
            (s) => s?.id == targetId,
            orElse: () => seasons.isNotEmpty
                ? seasons.first
                : RituSeason(
                    id: targetId,
                    name: isRainy ? 'Rainy Season' : 'Dry Season',
                    monthsBS: const [],
                    monthsGregorian: const [],
                    signatureProduce: const [],
                  ),
          )!;
    }

    return seasons.isNotEmpty
        ? seasons.first
        : const RituSeason(
            id: 'default',
            name: 'Standard Season',
            monthsBS: [],
            monthsGregorian: [],
            signatureProduce: [],
          );
  }

  static List<RituSeason> _buildDefaultSeasons(String seasonSystem) {
    if (seasonSystem == 'four-seasons' || seasonSystem == 'four-seasons-southern') {
      return const [
        RituSeason(
          id: 'spring',
          name: 'Spring',
          monthsBS: [],
          monthsGregorian: ['September', 'October', 'November'],
          signatureProduce: ['asparagus', 'spinach', 'peas', 'strawberries'],
        ),
        RituSeason(
          id: 'summer',
          name: 'Summer',
          monthsBS: [],
          monthsGregorian: ['December', 'January', 'February'],
          signatureProduce: ['tomatoes', 'corn', 'zucchini', 'stone_fruit'],
        ),
        RituSeason(
          id: 'autumn',
          name: 'Autumn',
          monthsBS: [],
          monthsGregorian: ['March', 'April', 'May'],
          signatureProduce: ['pumpkin', 'apples', 'mushrooms', 'sweet_potato'],
        ),
        RituSeason(
          id: 'winter',
          name: 'Winter',
          monthsBS: [],
          monthsGregorian: ['June', 'July', 'August'],
          signatureProduce: ['kale', 'broccoli', 'citrus', 'root_vegetables'],
        ),
      ];
    } else if (seasonSystem == 'wet-dry') {
      return const [
        RituSeason(
          id: 'rainy',
          name: 'Rainy Season',
          monthsBS: [],
          monthsGregorian: ['April', 'May', 'June', 'July', 'August', 'September', 'October'],
          signatureProduce: ['yam', 'plantain', 'cassava', 'peppers'],
        ),
        RituSeason(
          id: 'dry',
          name: 'Dry Season',
          monthsBS: [],
          monthsGregorian: ['November', 'December', 'January', 'February', 'March'],
          signatureProduce: ['beans', 'groundnuts', 'millet', 'onions'],
        ),
      ];
    } else {
      return const [
        RituSeason(
          id: 'basanta',
          name: 'वसन्तः (Basanta / Spring)',
          monthsBS: ['Chaitra', 'Baisakh'],
          monthsGregorian: ['March', 'April'],
          signatureProduce: ['green_garlic', 'pointed_gourd', 'spinach'],
        ),
        RituSeason(
          id: 'grishma',
          name: 'ग्रीष्मः (Grishma / Summer)',
          monthsBS: ['Jestha', 'Ashadh'],
          monthsGregorian: ['May', 'June'],
          signatureProduce: ['okra', 'cucumber', 'bitter_gourd'],
        ),
        RituSeason(
          id: 'barsha',
          name: 'वर्षा (Barsha / Monsoon)',
          monthsBS: ['Shrawan', 'Bhadra'],
          monthsGregorian: ['July', 'August'],
          signatureProduce: ['taro_leaves', 'bamboo_shoots', 'bottle_gourd'],
        ),
        RituSeason(
          id: 'sharad',
          name: 'शरद् (Sharad / Autumn)',
          monthsBS: ['Ashwin', 'Kartik'],
          monthsGregorian: ['September', 'October'],
          signatureProduce: ['cauliflower', 'radish', 'mustard_greens'],
        ),
        RituSeason(
          id: 'hemanta',
          name: 'हेमन्तः (Hemanta / Late Autumn)',
          monthsBS: ['Mangsir', 'Poush'],
          monthsGregorian: ['November', 'December'],
          signatureProduce: ['green_peas', 'broad_beans', 'coriander'],
        ),
        RituSeason(
          id: 'shishir',
          name: 'शिशिरः (Shishir / Winter)',
          monthsBS: ['Magh', 'Falgun'],
          monthsGregorian: ['January', 'February'],
          signatureProduce: ['spinach', 'mustard_greens', 'carrots'],
        ),
      ];
    }
  }

  /// Default verified and community catalog entries.
  static List<RegionPackCatalogEntry> get defaultCatalog => const [
        RegionPackCatalogEntry(
          id: 'nepal-bagmati',
          name: 'Nepal (Bagmati Province)',
          nativeName: 'नेपाल (बागमती प्रदेश - काठमाडौँ)',
          country: 'Nepal',
          countryCode: 'NP',
          status: 'verified',
          version: '1.0.0',
          description:
              'Kathmandu Valley and Bagmati mid-hills with 6 ritus, Bikram Sambat calendar, and haat bazaar market units (pau, dharni, mana).',
          elevationMeters: 1400,
          climateZone: 'subtropical',
          seasonSystem: 'six-ritus',
          defaultLanguage: 'ne',
          calendar: 'bikram-sambat',
          currencyCode: 'NPR',
          currencySymbol: 'रू',
          marketUnits: ['pau', 'dharni', 'mana', 'muthi', 'kg', 'g'],
          sizeBytes: 245760,
          recipeCount: 30,
          ingredientCount: 68,
          isBuiltIn: true,
          isInstalled: true,
        ),
        RegionPackCatalogEntry(
          id: 'nepal-terai',
          name: 'Nepal (Terai Plains)',
          nativeName: 'नेपाल (तराई-मधेस प्रदेश)',
          country: 'Nepal',
          countryCode: 'NP',
          status: 'verified',
          version: '1.0.0',
          description:
              'Southern plains of Nepal (Janakpur, Biratnagar, Chitwan) with river fish, seasonal parwal, sattu, and Mithila cuisine.',
          elevationMeters: 200,
          climateZone: 'tropical',
          seasonSystem: 'six-ritus',
          defaultLanguage: 'ne',
          calendar: 'bikram-sambat',
          currencyCode: 'NPR',
          currencySymbol: 'रू',
          marketUnits: ['kg', 'g', 'pau', 'bunch'],
          sizeBytes: 184320,
          recipeCount: 15,
          ingredientCount: 42,
          isBuiltIn: false,
          isInstalled: false,
        ),
        RegionPackCatalogEntry(
          id: 'australia-nsw',
          name: 'Australia (New South Wales / Sydney)',
          nativeName: 'Australia (NSW - Sydney)',
          country: 'Australia',
          countryCode: 'AU',
          status: 'verified',
          version: '1.0.0',
          description:
              'Sydney and NSW coast featuring Southern Hemisphere inverted seasons, metric units, fresh spring asparagus and seafood.',
          elevationMeters: 50,
          climateZone: 'temperate',
          seasonSystem: 'four-seasons-southern',
          defaultLanguage: 'en',
          calendar: 'gregorian',
          currencyCode: 'AUD',
          currencySymbol: '\$',
          marketUnits: ['kg', 'g', 'cup', 'bunch', 'punnet'],
          sizeBytes: 198656,
          recipeCount: 12,
          ingredientCount: 38,
          isBuiltIn: false,
          isInstalled: false,
        ),
        RegionPackCatalogEntry(
          id: 'uk-london',
          name: 'United Kingdom (London & SE)',
          nativeName: 'UK (Greater London)',
          country: 'United Kingdom',
          countryCode: 'GB',
          status: 'verified',
          version: '1.0.0',
          description:
              'London metropolitan area with British seasonal produce, farmers market punnets, leeks, root vegetables and autumn bramley apples.',
          elevationMeters: 35,
          climateZone: 'temperate',
          seasonSystem: 'four-seasons',
          defaultLanguage: 'en',
          calendar: 'gregorian',
          currencyCode: 'GBP',
          currencySymbol: '£',
          marketUnits: ['kg', 'g', 'punnet', 'pack', 'bunch'],
          sizeBytes: 172032,
          recipeCount: 10,
          ingredientCount: 35,
          isBuiltIn: false,
          isInstalled: false,
        ),
        RegionPackCatalogEntry(
          id: 'nigeria-lagos',
          name: 'Nigeria (Lagos State)',
          nativeName: 'Nigeria (Ìpínlẹ̀ Èkó / Lagos)',
          country: 'Nigeria',
          countryCode: 'NG',
          status: 'community',
          version: '1.0.0',
          description:
              'Lagos coastal metropolis with rainy/dry tropical seasons, local market volume units (derica, mudu, olodo), yams, and plantains.',
          elevationMeters: 10,
          climateZone: 'tropical',
          seasonSystem: 'wet-dry',
          defaultLanguage: 'en',
          calendar: 'gregorian',
          currencyCode: 'NGN',
          currencySymbol: '₦',
          marketUnits: ['kg', 'derica', 'olodo', 'mudu', 'heap', 'piece'],
          sizeBytes: 153600,
          recipeCount: 8,
          ingredientCount: 30,
          isBuiltIn: false,
          isInstalled: false,
        ),
        RegionPackCatalogEntry(
          id: 'bolivia-lapaz',
          name: 'Bolivia (La Paz & Altiplano)',
          nativeName: 'Bolivia (Nuestra Señora de La Paz)',
          country: 'Bolivia',
          countryCode: 'BO',
          status: 'community',
          version: '1.0.0',
          description:
              'High-altitude Andean plateau (3,600m) where water boils at 87°C requiring specialized pressure cooker timings, quinoa and chuño.',
          elevationMeters: 3600,
          climateZone: 'highland',
          seasonSystem: 'four-seasons-southern',
          defaultLanguage: 'es',
          calendar: 'gregorian',
          currencyCode: 'BOB',
          currencySymbol: 'Bs',
          marketUnits: ['kg', 'g', 'libra', 'arroba'],
          sizeBytes: 163840,
          recipeCount: 8,
          ingredientCount: 28,
          isBuiltIn: false,
          isInstalled: false,
        ),
        RegionPackCatalogEntry(
          id: 'andes-lapaz',
          name: 'Andes (Bolivia / La Paz Altiplano)',
          nativeName: 'Bolivia (Nuestra Señora de La Paz Altiplano)',
          country: 'Bolivia',
          countryCode: 'BO',
          status: 'verified',
          version: '1.0.0',
          description:
              'High-altitude Andean plateau (3,600m) where water boils at 87.4°C requiring specialized pressure cooker calibrations, royal quinoa and chuño.',
          elevationMeters: 3600,
          climateZone: 'highland',
          seasonSystem: 'four-seasons-southern',
          defaultLanguage: 'es',
          calendar: 'gregorian',
          currencyCode: 'BOB',
          currencySymbol: 'Bs',
          marketUnits: ['kg', 'g', 'libra', 'arroba', 'monton', 'atado'],
          sizeBytes: 163840,
          recipeCount: 8,
          ingredientCount: 28,
          isBuiltIn: false,
          isInstalled: false,
        ),
        RegionPackCatalogEntry(
          id: 'india-delhi',
          name: 'India (Delhi & Northern Plains)',
          nativeName: 'भारत (दिल्ली व उत्तरी मैदान)',
          country: 'India',
          countryCode: 'IN',
          status: 'verified',
          version: '1.0.0',
          description:
              'Delhi NCR and Northern Plains featuring IFCT nutrition references, mandi volume units (katori, pao, seer), rajma, dal makhani, and festive Vrat rules.',
          elevationMeters: 216,
          climateZone: 'subtropical',
          seasonSystem: 'six-ritus',
          defaultLanguage: 'hi',
          calendar: 'gregorian',
          currencyCode: 'INR',
          currencySymbol: '₹',
          marketUnits: ['kg', 'g', 'katori', 'bunch', 'packet', 'pao', 'quintal', 'seer'],
          sizeBytes: 215040,
          recipeCount: 25,
          ingredientCount: 55,
          isBuiltIn: false,
          isInstalled: false,
        ),
        RegionPackCatalogEntry(
          id: 'australia-diaspora',
          name: 'Australia (Diaspora & Southern Seasons)',
          nativeName: 'Australia (Diaspora - Sydney / Melbourne)',
          country: 'Australia',
          countryCode: 'AU',
          status: 'verified',
          version: '1.0.0',
          description:
              'Australian diaspora households featuring Southern Hemisphere inverted seasons, Taste of Home ingredient substitutions (Tasmanian pepperberry, Aussie lamb), and metric units.',
          elevationMeters: 50,
          climateZone: 'temperate',
          seasonSystem: 'four-seasons-southern',
          defaultLanguage: 'en',
          calendar: 'gregorian',
          currencyCode: 'AUD',
          currencySymbol: '\$',
          marketUnits: ['kg', 'g', 'cup', 'bunch', 'punnet', 'pack', 'tray'],
          sizeBytes: 198656,
          recipeCount: 15,
          ingredientCount: 40,
          isBuiltIn: false,
          isInstalled: false,
        ),
      ];

  /// Pre-built sample packs for catalog entries to support immediate offline installation.
  static RegionPack? getSamplePack(String id) {
    switch (id) {
      case 'nepal-bagmati':
        return const RegionPack(
          manifest: RegionPackManifest(
            id: 'nepal-bagmati',
            version: '1.0.0',
            name: 'Nepal (Bagmati Province)',
            country: 'Nepal',
            countryCode: 'NP',
            region: 'Bagmati',
            status: 'verified',
            elevationMeters: 1400,
            defaultLanguage: 'ne',
            calendar: 'bikram-sambat',
            seasonSystem: 'six-ritus',
            currencyCode: 'NPR',
            currencySymbol: 'रू',
            marketUnits: ['pau', 'dharni', 'mana', 'muthi', 'kg', 'g'],
          ),
          seasonality: RegionSeasonality(
            regionId: 'nepal-bagmati',
            ritus: [
              RituSeason(
                id: 'sharad',
                name: 'शरद् ऋतु (Sharad)',
                monthsBS: ['Ashwin', 'Kartik'],
                monthsGregorian: ['September', 'October'],
                signatureProduce: ['cauliflower', 'radish', 'mustard_greens'],
              ),
              RituSeason(
                id: 'barsha',
                name: 'वर्षा ऋतु (Barsha)',
                monthsBS: ['Shrawan', 'Bhadra'],
                monthsGregorian: ['July', 'August'],
                signatureProduce: ['taro_leaves', 'bamboo_shoots'],
              ),
            ],
          ),
          ingredients: [
            RegionIngredient(
              id: 'cauliflower',
              nameEn: 'Cauliflower',
              nameNe: 'काउली',
              aliases: ['phool gobi'],
              category: 'vegetables',
              standardUnit: 'kg',
              marketPackageGrams: 1000,
              storageDays: 5,
              allergens: [],
              availability: {'sharad': 'peak', 'barsha': 'out_of_season'},
            ),
            RegionIngredient(
              id: 'kalo_dal',
              nameEn: 'Black Lentils (Urad)',
              nameNe: 'मासको दाल',
              aliases: ['urad dal'],
              category: 'pulses',
              standardUnit: 'kg',
              marketPackageGrams: 1000,
              storageDays: 180,
              allergens: [],
              availability: {'sharad': 'available', 'barsha': 'available'},
            ),
          ],
          recipes: [
            RegionRecipe(
              id: 'kalo-dal',
              titleEn: 'Kathmandu Kalo Dal',
              titleNe: 'कालो दाल (झारेको)',
              category: 'dal',
              cuisine: 'Newari/Nepali',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 25,
              servings: 4,
              difficulty: 'easy',
              pressureCooker: RecipeWhistleProfile(
                enabled: true,
                recommendedWhistles: 4,
                altitudeWhistleOffsetKathmandu: 1,
                heatLevel: 'medium',
                releaseType: 'natural',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'kalo_dal', quantity: 200, unit: 'g'),
              ],
              seasonality: ['sharad', 'hemanta'],
              tags: ['dal', 'comfort'],
            ),
          ],
          festivals: [
            RegionFestival(
              id: 'dashain',
              nameEn: 'Dashain',
              nameNe: 'बडा दसैँ',
              tithi: 'Ashwin Shukla Pratipada to Purnima',
              approxGregorianMonth: 'October',
              descriptionEn: 'The biggest festival of Nepal celebrating victory of good over evil.',
              descriptionNe: 'असत्यमाथि सत्यको विजयको प्रतीक महान् पर्व।',
              keyDishes: ['kalo-dal'],
            ),
          ],
        );

      case 'australia-nsw':
      case 'australia-diaspora':
        return RegionPack(
          manifest: RegionPackManifest(
            id: id,
            version: '1.0.0',
            name: id == 'australia-nsw'
                ? 'Australia (New South Wales / Sydney)'
                : 'Australia (Diaspora & Southern Seasons)',
            country: 'Australia',
            countryCode: 'AU',
            region: 'New South Wales',
            status: 'verified',
            elevationMeters: 50,
            defaultLanguage: 'en',
            calendar: 'gregorian',
            seasonSystem: 'four-seasons-southern',
            currencyCode: 'AUD',
            currencySymbol: '\$',
            marketUnits: const ['kg', 'g', 'cup', 'bunch', 'punnet', 'pack', 'tray'],
          ),
          seasonality: RegionSeasonality(
            regionId: id,
            ritus: const [
              RituSeason(
                id: 'spring',
                name: 'Spring',
                monthsBS: [],
                monthsGregorian: ['September', 'October', 'November'],
                signatureProduce: ['asparagus', 'spinach', 'peas', 'strawberries'],
              ),
              RituSeason(
                id: 'summer',
                name: 'Summer',
                monthsBS: [],
                monthsGregorian: ['December', 'January', 'February'],
                signatureProduce: ['tomatoes', 'zucchini', 'stone_fruit'],
              ),
              RituSeason(
                id: 'autumn',
                name: 'Autumn',
                monthsBS: [],
                monthsGregorian: ['March', 'April', 'May'],
                signatureProduce: ['pumpkin', 'apples', 'mushrooms'],
              ),
              RituSeason(
                id: 'winter',
                name: 'Winter',
                monthsBS: [],
                monthsGregorian: ['June', 'July', 'August'],
                signatureProduce: ['kale', 'broccoli', 'citrus'],
              ),
            ],
          ),
          ingredients: const [
            RegionIngredient(
              id: 'asparagus',
              nameEn: 'Fresh Asparagus',
              nameNe: 'कुरिलो (Asparagus)',
              aliases: ['spears'],
              category: 'vegetables',
              standardUnit: 'bunch',
              marketPackageGrams: 250,
              storageDays: 4,
              allergens: [],
              availability: {'spring': 'peak', 'summer': 'available', 'autumn': 'out_of_season', 'winter': 'out_of_season'},
            ),
            RegionIngredient(
              id: 'spinach',
              nameEn: 'Baby Spinach',
              nameNe: 'पालुङ्गो (Spinach)',
              aliases: ['english spinach'],
              category: 'greens',
              standardUnit: 'g',
              marketPackageGrams: 200,
              storageDays: 4,
              allergens: [],
              availability: {'spring': 'peak', 'winter': 'peak', 'summer': 'limited', 'autumn': 'available'},
            ),
            RegionIngredient(
              id: 'salmon',
              nameEn: 'Atlantic Salmon Fillet',
              nameNe: 'साल्मन माछा',
              aliases: ['salmon'],
              category: 'meat',
              standardUnit: 'g',
              marketPackageGrams: 400,
              storageDays: 2,
              allergens: ['fish'],
              availability: {'spring': 'available', 'summer': 'available', 'autumn': 'available', 'winter': 'available'},
            ),
            RegionIngredient(
              id: 'aussie_lamb',
              nameEn: 'Australian Grass-Fed Lamb',
              nameNe: 'अस्ट्रेलियन भेडा/खसी',
              aliases: ['lamb shoulder', 'aussie lamb'],
              category: 'meat',
              standardUnit: 'kg',
              marketPackageGrams: 1000,
              storageDays: 3,
              allergens: [],
              availability: {'spring': 'peak', 'summer': 'available', 'autumn': 'available', 'winter': 'peak'},
            ),
            RegionIngredient(
              id: 'tasmanian_pepperberry',
              nameEn: 'Tasmanian Mountain Pepperberry',
              nameNe: 'टास्मानियन मरिच/टिम्मुर',
              aliases: ['pepperberry', 'mountain pepper'],
              category: 'spices',
              standardUnit: 'g',
              marketPackageGrams: 50,
              storageDays: 365,
              allergens: [],
              availability: {'spring': 'available', 'summer': 'available', 'autumn': 'peak', 'winter': 'available'},
            ),
          ],
          recipes: const [
            RegionRecipe(
              id: 'sydney-spring-salmon',
              titleEn: 'Pan-seared Salmon with Spring Asparagus',
              titleNe: 'साल्मन माछा र कुरिलो (Spring Special)',
              category: 'tarkari',
              cuisine: 'Modern Australian',
              dietary: ['gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 15,
              servings: 2,
              difficulty: 'easy',
              pressureCooker: RecipeWhistleProfile(
                enabled: false,
                recommendedWhistles: 0,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'quick',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'salmon', quantity: 350, unit: 'g'),
                RecipeIngredientItem(ingredientId: 'asparagus', quantity: 200, unit: 'g'),
              ],
              seasonality: ['spring'],
              tags: ['high-protein', 'spring', 'quick'],
            ),
            RegionRecipe(
              id: 'sydney-spring-lamb-curry',
              titleEn: 'Diaspora Spring Lamb Curry (Dashain in Sydney)',
              titleNe: 'अस्ट्रेलियन खसी/भेडाको मासु (दसैँ विशेष)',
              category: 'masu',
              cuisine: 'Nepali Diaspora',
              dietary: ['gluten-free'],
              prepTimeMinutes: 15,
              cookTimeMinutes: 35,
              servings: 4,
              difficulty: 'medium',
              pressureCooker: RecipeWhistleProfile(
                enabled: true,
                recommendedWhistles: 4,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'natural',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'aussie_lamb', quantity: 800, unit: 'g'),
                RecipeIngredientItem(ingredientId: 'tasmanian_pepperberry', quantity: 5, unit: 'g'),
              ],
              seasonality: ['spring'],
              tags: ['diaspora', 'dashain', 'meat'],
            ),
          ],
          festivals: const [],
        );

      case 'bolivia-lapaz':
      case 'andes-lapaz':
        return RegionPack(
          manifest: RegionPackManifest(
            id: id,
            version: '1.0.0',
            name: id == 'bolivia-lapaz'
                ? 'Bolivia (La Paz & Altiplano)'
                : 'Andes (Bolivia / La Paz Altiplano)',
            country: 'Bolivia',
            countryCode: 'BO',
            region: 'La Paz',
            status: 'verified',
            elevationMeters: 3600,
            defaultLanguage: 'es',
            calendar: 'gregorian',
            seasonSystem: 'four-seasons-southern',
            currencyCode: 'BOB',
            currencySymbol: 'Bs',
            marketUnits: const ['kg', 'g', 'libra', 'arroba', 'monton', 'atado'],
          ),
          seasonality: RegionSeasonality(
            regionId: id,
            ritus: const [
              RituSeason(
                id: 'spring',
                name: 'Primavera (Spring)',
                monthsBS: [],
                monthsGregorian: ['September', 'October', 'November'],
                signatureProduce: ['quinoa', 'chuño', 'potato'],
              ),
            ],
          ),
          ingredients: const [
            RegionIngredient(
              id: 'quinoa',
              nameEn: 'Royal White Quinoa',
              nameNe: 'किनोवा',
              aliases: ['quinua real'],
              category: 'grains',
              standardUnit: 'kg',
              marketPackageGrams: 500,
              storageDays: 365,
              allergens: [],
              availability: {'spring': 'peak'},
            ),
            RegionIngredient(
              id: 'chuno',
              nameEn: 'Freeze-Dried Black Potato (Chuño)',
              nameNe: 'छुन्यो (कालो सुख्खा आलु)',
              aliases: ['chuno negro', 'freeze dried potato'],
              category: 'vegetables',
              standardUnit: 'kg',
              marketPackageGrams: 1000,
              storageDays: 730,
              allergens: [],
              availability: {'spring': 'available'},
            ),
          ],
          recipes: const [
            RegionRecipe(
              id: 'pesque-de-quinua',
              titleEn: 'Pesque de Quinua (High Altitude Stew)',
              titleNe: 'पेस्के दे किनोवा (उच्च उचाइको खाना)',
              category: 'khaja',
              cuisine: 'Andean',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 30,
              servings: 4,
              difficulty: 'medium',
              pressureCooker: RecipeWhistleProfile(
                enabled: true,
                recommendedWhistles: 4,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'natural',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'quinoa', quantity: 250, unit: 'g'),
              ],
              seasonality: ['spring'],
              tags: ['high-altitude', 'superfood'],
            ),
            RegionRecipe(
              id: 'sopa-de-mani-chuno',
              titleEn: 'Altiplano Peanut Soup with Chuño',
              titleNe: 'सोपा दे मानी र छुन्यो',
              category: 'soup',
              cuisine: 'Andean',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 20,
              cookTimeMinutes: 40,
              servings: 4,
              difficulty: 'hard',
              pressureCooker: RecipeWhistleProfile(
                enabled: true,
                recommendedWhistles: 6,
                altitudeWhistleOffsetKathmandu: 2,
                heatLevel: 'medium',
                releaseType: 'natural',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'chuno', quantity: 250, unit: 'g'),
                RecipeIngredientItem(ingredientId: 'quinoa', quantity: 100, unit: 'g'),
              ],
              seasonality: ['spring'],
              tags: ['high-altitude', 'chuño'],
            ),
          ],
          festivals: const [],
        );

      case 'nigeria-lagos':
        return const RegionPack(
          manifest: RegionPackManifest(
            id: 'nigeria-lagos',
            version: '1.0.0',
            name: 'Nigeria (Lagos State)',
            country: 'Nigeria',
            countryCode: 'NG',
            region: 'Lagos',
            status: 'community',
            elevationMeters: 10,
            defaultLanguage: 'en',
            calendar: 'gregorian',
            seasonSystem: 'wet-dry',
            currencyCode: 'NGN',
            currencySymbol: '₦',
            marketUnits: ['kg', 'derica', 'olodo', 'mudu', 'heap'],
          ),
          seasonality: RegionSeasonality(
            regionId: 'nigeria-lagos',
            ritus: [
              RituSeason(
                id: 'rainy',
                name: 'Rainy Season',
                monthsBS: [],
                monthsGregorian: ['April', 'May', 'June', 'July', 'August', 'September', 'October'],
                signatureProduce: ['yam', 'plantain', 'peppers'],
              ),
              RituSeason(
                id: 'dry',
                name: 'Dry Season',
                monthsBS: [],
                monthsGregorian: ['November', 'December', 'January', 'February', 'March'],
                signatureProduce: ['beans', 'groundnuts'],
              ),
            ],
          ),
          ingredients: [
            RegionIngredient(
              id: 'yam',
              nameEn: 'White Yam Tuber',
              nameNe: 'तरुल/याम',
              aliases: ['yam tuber'],
              category: 'vegetables',
              standardUnit: 'heap',
              marketPackageGrams: 2000,
              storageDays: 30,
              allergens: [],
              availability: {'rainy': 'peak', 'dry': 'available'},
            ),
          ],
          recipes: [
            RegionRecipe(
              id: 'boiled-yam',
              titleEn: 'Boiled Yam with Pepper Sauce',
              titleNe: 'उसिनेको याम र सस',
              category: 'khaja',
              cuisine: 'Nigerian',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 20,
              servings: 3,
              difficulty: 'easy',
              pressureCooker: RecipeWhistleProfile(
                enabled: false,
                recommendedWhistles: 0,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'quick',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'yam', quantity: 600, unit: 'g'),
              ],
              seasonality: ['rainy', 'dry'],
              tags: ['comfort', 'staple'],
            ),
          ],
          festivals: [],
        );

      case 'nepal-terai':
        return const RegionPack(
          manifest: RegionPackManifest(
            id: 'nepal-terai',
            version: '1.0.0',
            name: 'Nepal (Terai Plains)',
            country: 'Nepal',
            countryCode: 'NP',
            region: 'Terai',
            status: 'verified',
            elevationMeters: 200,
            defaultLanguage: 'ne',
            calendar: 'bikram-sambat',
            seasonSystem: 'six-ritus',
            currencyCode: 'NPR',
            currencySymbol: 'रू',
            marketUnits: ['kg', 'g', 'pau', 'bunch'],
          ),
          seasonality: RegionSeasonality(
            regionId: 'nepal-terai',
            ritus: [
              RituSeason(
                id: 'sharad',
                name: 'शरद् ऋतु (Sharad)',
                monthsBS: ['Ashwin', 'Kartik'],
                monthsGregorian: ['September', 'October'],
                signatureProduce: ['pointed_gourd', 'okra'],
              ),
            ],
          ),
          ingredients: [
            RegionIngredient(
              id: 'pointed_gourd',
              nameEn: 'Pointed Gourd (Parwal)',
              nameNe: 'परवर',
              aliases: ['parwal'],
              category: 'vegetables',
              standardUnit: 'kg',
              marketPackageGrams: 500,
              storageDays: 6,
              allergens: [],
              availability: {'sharad': 'peak'},
            ),
          ],
          recipes: [
            RegionRecipe(
              id: 'terai-parwal-bhaja',
              titleEn: 'Terai Parwal Bhaja',
              titleNe: 'तराई परवर भाजा',
              category: 'tarkari',
              cuisine: 'Maithil',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 15,
              servings: 4,
              difficulty: 'easy',
              pressureCooker: RecipeWhistleProfile(
                enabled: false,
                recommendedWhistles: 0,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'quick',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'pointed_gourd', quantity: 400, unit: 'g'),
              ],
              seasonality: ['sharad'],
              tags: ['terai', 'mithila'],
            ),
          ],
          festivals: [],
        );

      case 'uk-london':
        return const RegionPack(
          manifest: RegionPackManifest(
            id: 'uk-london',
            version: '1.0.0',
            name: 'United Kingdom (London & SE)',
            country: 'United Kingdom',
            countryCode: 'GB',
            region: 'Greater London',
            status: 'verified',
            elevationMeters: 35,
            defaultLanguage: 'en',
            calendar: 'gregorian',
            seasonSystem: 'four-seasons',
            currencyCode: 'GBP',
            currencySymbol: '£',
            marketUnits: ['kg', 'g', 'punnet', 'pack', 'bunch'],
          ),
          seasonality: RegionSeasonality(
            regionId: 'uk-london',
            ritus: [
              RituSeason(
                id: 'autumn',
                name: 'Autumn',
                monthsBS: [],
                monthsGregorian: ['September', 'October', 'November'],
                signatureProduce: ['leek', 'beetroot', 'apples'],
              ),
            ],
          ),
          ingredients: [
            RegionIngredient(
              id: 'leek',
              nameEn: 'British Leeks',
              nameNe: 'छ्यापी/लिक',
              aliases: ['leek'],
              category: 'vegetables',
              standardUnit: 'kg',
              marketPackageGrams: 500,
              storageDays: 7,
              allergens: [],
              availability: {'autumn': 'peak'},
            ),
          ],
          recipes: [
            RegionRecipe(
              id: 'london-leek-soup',
              titleEn: 'Autumn Leek & Potato Soup',
              titleNe: 'लिक र आलुको तातो सुप',
              category: 'soup',
              cuisine: 'British',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 10,
              cookTimeMinutes: 20,
              servings: 4,
              difficulty: 'easy',
              pressureCooker: RecipeWhistleProfile(
                enabled: true,
                recommendedWhistles: 3,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'natural',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'leek', quantity: 300, unit: 'g'),
              ],
              seasonality: ['autumn'],
              tags: ['soup', 'comfort'],
            ),
          ],
          festivals: [],
        );

      case 'india-delhi':
        return const RegionPack(
          manifest: RegionPackManifest(
            id: 'india-delhi',
            version: '1.0.0',
            name: 'India (Delhi & Northern Plains)',
            country: 'India',
            countryCode: 'IN',
            region: 'Delhi NCR',
            status: 'verified',
            elevationMeters: 216,
            defaultLanguage: 'hi',
            calendar: 'gregorian',
            seasonSystem: 'six-ritus',
            currencyCode: 'INR',
            currencySymbol: '₹',
            marketUnits: ['kg', 'g', 'katori', 'bunch', 'packet', 'pao', 'quintal', 'seer'],
          ),
          seasonality: RegionSeasonality(
            regionId: 'india-delhi',
            ritus: [
              RituSeason(
                id: 'hemant',
                name: 'हेमन्त (Hemant / Late Autumn)',
                monthsBS: ['Margashirsha', 'Pausha'],
                monthsGregorian: ['November', 'December'],
                signatureProduce: ['palak', 'rajma', 'cauliflower'],
              ),
            ],
          ),
          ingredients: [
            RegionIngredient(
              id: 'rajma',
              nameEn: 'Red Kidney Beans (Rajma)',
              nameNe: 'राजमा',
              aliases: ['chitra rajma', 'kidney beans'],
              category: 'pulses',
              standardUnit: 'kg',
              marketPackageGrams: 1000,
              storageDays: 365,
              allergens: [],
              availability: {'hemant': 'peak'},
            ),
            RegionIngredient(
              id: 'urad_dal_black',
              nameEn: 'Whole Black Gram (Sabut Urad)',
              nameNe: 'साबुत उड़द दाल',
              aliases: ['kali dal', 'makhani dal'],
              category: 'pulses',
              standardUnit: 'kg',
              marketPackageGrams: 1000,
              storageDays: 365,
              allergens: [],
              availability: {'hemant': 'peak'},
            ),
          ],
          recipes: [
            RegionRecipe(
              id: 'delhi-rajma-masala',
              titleEn: 'Delhi Punjabi Style Rajma Masala',
              titleNe: 'दिल्ली पंजाबी राजमा मसाला',
              category: 'dal',
              cuisine: 'North Indian / Punjabi',
              dietary: ['vegetarian', 'gluten-free'],
              prepTimeMinutes: 15,
              cookTimeMinutes: 35,
              servings: 4,
              difficulty: 'easy',
              pressureCooker: RecipeWhistleProfile(
                enabled: true,
                recommendedWhistles: 4,
                altitudeWhistleOffsetKathmandu: 0,
                heatLevel: 'medium',
                releaseType: 'natural',
              ),
              ingredients: [
                RecipeIngredientItem(ingredientId: 'rajma', quantity: 250, unit: 'g'),
              ],
              seasonality: ['hemant'],
              tags: ['high-protein', 'comfort'],
            ),
          ],
          festivals: [
            RegionFestival(
              id: 'diwali',
              nameEn: 'Deepawali',
              nameNe: 'दीपावली',
              tithi: 'Kartik Amavasya',
              approxGregorianMonth: 'November',
              descriptionEn: 'Festival of lights celebrated across India.',
              descriptionNe: 'प्रकाश र समृद्धिको महापर्व।',
              keyDishes: ['delhi-rajma-masala'],
            ),
          ],
        );

      default:
        return null;
    }
  }
}
