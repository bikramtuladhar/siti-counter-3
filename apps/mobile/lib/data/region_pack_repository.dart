library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

class RegionPackRepository {
  static final RegionPackRepository _instance = RegionPackRepository._internal();
  factory RegionPackRepository() => _instance;
  RegionPackRepository._internal() : _manager = RegionPackManager();

  final RegionPackManager _manager;
  RegionPackManager get manager => _manager;

  RegionPack? _cachedPack;

  RegionPack? get currentPack =>
      _manager.getPack(_manager.activeConfig.primaryPackId) ?? _cachedPack;

  ResolvedRegionContext get context => _manager.resolveContext();
  List<RegionPackCatalogEntry> get catalog => _manager.catalog;
  ActiveRegionConfig get activeConfig => _manager.activeConfig;
  HouseholdPackOverride? get householdOverride => _manager.householdOverride;

  void setPack(RegionPack pack) {
    _cachedPack = pack;
    _manager.loadBuiltInPack(pack);
    _manager.setPrimaryPack(pack.manifest.id);
  }

  void reset() {
    _cachedPack = null;
  }

  Future<void> installPack(String packId) async {
    await _manager.installFromCatalog(packId);
  }

  void uninstallPack(String packId) {
    _manager.uninstallPack(packId);
  }

  void setPrimaryPack(String packId) {
    _manager.setPrimaryPack(packId);
  }

  void addSecondaryPack(String packId) {
    _manager.addSecondaryPack(packId);
  }

  void removeSecondaryPack(String packId) {
    _manager.removeSecondaryPack(packId);
  }

  RegionPack createCustomRegion(CustomRegionInput input) {
    return _manager.createCustomRegion(input);
  }

  void deleteCustomRegion(String packId) {
    _manager.deleteCustomRegion(packId);
  }

  void setHouseholdOverride(HouseholdPackOverride? override) {
    _manager.setHouseholdOverride(override);
  }

  Future<RegionPack> loadRegionPack({String regionId = 'nepal-bagmati'}) async {
    if (_cachedPack != null && _cachedPack!.manifest.id == regionId) {
      return _cachedPack!;
    }

    if (_manager.isInstalled(regionId)) {
      _cachedPack = _manager.getPack(regionId);
      return _cachedPack!;
    }

    try {
      final manifestString = await rootBundle
          .loadString('assets/region-packs/$regionId/manifest.json');
      final seasonalityString = await rootBundle
          .loadString('assets/region-packs/$regionId/seasonality.json');
      final ingredientsString = await rootBundle
          .loadString('assets/region-packs/$regionId/ingredients.json');
      final recipesString = await rootBundle
          .loadString('assets/region-packs/$regionId/recipes.json');
      final festivalsString = await rootBundle
          .loadString('assets/region-packs/$regionId/festivals.json');

      final manifest =
          RegionPackManifest.fromJson(jsonDecode(manifestString) as Map<String, dynamic>);
      final seasonality =
          RegionSeasonality.fromJson(jsonDecode(seasonalityString) as Map<String, dynamic>);
      final ingredients = (jsonDecode(ingredientsString) as List<dynamic>)
          .map((i) => RegionIngredient.fromJson(i as Map<String, dynamic>))
          .toList();
      final recipes = (jsonDecode(recipesString) as List<dynamic>)
          .map((r) => RegionRecipe.fromJson(r as Map<String, dynamic>))
          .toList();
      final festivals = (jsonDecode(festivalsString) as List<dynamic>)
          .map((f) => RegionFestival.fromJson(f as Map<String, dynamic>))
          .toList();

      final defaultPreservations = _getDefaultPreservations(regionId);

      _cachedPack = RegionPack(
        manifest: manifest,
        seasonality: seasonality,
        ingredients: ingredients,
        recipes: recipes,
        festivals: festivals,
        preservationSuggestions: defaultPreservations,
      );

      _manager.loadBuiltInPack(_cachedPack!);
      return _cachedPack!;
    } catch (_) {
      // Fallback to pre-built sample pack if assets are not bundled in current test runner
      final sample = RegionPackManager.getSamplePack(regionId);
      if (sample != null) {
        _cachedPack = sample;
        _manager.loadBuiltInPack(sample);
        return sample;
      }
      rethrow;
    }
  }

  static List<PreservationSuggestion> _getDefaultPreservations(String regionId) {
    if (regionId == 'nepal-bagmati') {
      return const [
        PreservationSuggestion(
          id: 'gundruk-fermentation',
          titleEn: 'Gundruk Fermentation',
          titleNe: 'गुन्द्रुक बनाउने मौसम (किण्वन)',
          descriptionEn:
              'Rayo mustard and radish leaves are crisp and bountiful. Wilt in the autumn breeze, press firmly in clay vessels, and ferment naturally for winter saag and soup.',
          descriptionNe:
              'शरद ऋतुको नयाँ रायो र मूलाको साग ओइलाएर भाँडोमा खाँदी किण्वन गराउने र घाममा सुकाउने सर्वोत्तम समय हो।',
          targetSeason: 'sharad',
          primaryIngredients: ['mustard_greens', 'radish', 'cauliflower'],
          method: 'Lactic acid fermentation & sun-drying',
        ),
        PreservationSuggestion(
          id: 'masyaura-drying',
          titleEn: 'Sun-dried Masyaura (मस्यौरा)',
          titleNe: 'घाममा मस्यौरा सुकाउने परम्परा',
          descriptionEn:
              'Crisp post-monsoon sunshine is ideal for whipping airy black lentil batter with taro (पिँडालु) and drying delicious protein-rich nuggets on bamboo mats.',
          descriptionNe:
              'दसैँ-तिहारपछिको कडा घाममा मासको पिठो र पिँडालु वा कुभिण्डो मिसाएर सुकाइएको मस्यौरा वर्षभरि स्वादिलो तरकारी बन्छ।',
          targetSeason: 'sharad',
          primaryIngredients: ['black_gram', 'taro', 'ash_gourd'],
          method: 'Whipping batter & solar dehydration',
        ),
        PreservationSuggestion(
          id: 'mula-achar-khalpi',
          titleEn: 'Winter Radish & Mustard Pickle (मूलाको चाना/खाल्पी)',
          titleNe: 'मूलाको चाना र खाल्पी अचार',
          descriptionEn:
              'Large sweet winter radishes are at peak availability. Slice, salt, dry under bright sun, and pickle with cracked yellow mustard seeds and mustard oil.',
          descriptionNe:
              'शरद र हेमन्तको स्वादिलो मूलालाई चाना बनाएर घाममा सुकाई तोरीको छोप र शुद्ध तोरीको तेलमा मोलेर वर्षभरिका लागि अचार राख्ने समय।',
          targetSeason: 'sharad',
          primaryIngredients: ['radish', 'mustard_oil', 'mustard_seeds', 'turmeric'],
          method: 'Sun-drying & mustard seed lactic cure',
        ),
        PreservationSuggestion(
          id: 'lapsi-titaura',
          titleEn: 'Lapsi Titaura & Paun',
          titleNe: 'लप्सीको तितौरा र पाउँ',
          descriptionEn:
              'Autumn brings fresh tart Nepali hog plum (लप्सी). Boil, remove stones, blend with jaggery, salt, and cumin, and spread into sun-dried sheets.',
          descriptionNe:
              'शरद ऋतुमा फल्ने लप्सीलाई उसिनेर अमिलो-गुलियो मसला मोली घाममा सुकाएर स्वादिष्ट तितौरा तयार गर्ने समय।',
          targetSeason: 'sharad',
          primaryIngredients: ['lapsi', 'jaggery', 'chili_powder'],
          method: 'Boiling, pulp reduction & solar drying',
        ),
      ];
    }
    return const [];
  }
}
