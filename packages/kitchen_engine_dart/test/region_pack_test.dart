import 'dart:convert';
import 'dart:io';
import 'package:kitchen_engine/region_pack.dart';
import 'package:test/test.dart';

void main() {
  group('Nepal Bagmati Region Pack Dart deserialization', () {
    final packDir = Directory('../region-packs/nepal-bagmati');

    test('loads manifest correctly', () {
      final manifestFile = File('${packDir.path}/manifest.json');
      expect(manifestFile.existsSync(), isTrue);

      final jsonMap = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final manifest = RegionPackManifest.fromJson(jsonMap);

      expect(manifest.id, equals('nepal-bagmati'));
      expect(manifest.countryCode, equals('NP'));
      expect(manifest.elevationMeters, equals(1400));
      expect(manifest.calendar, equals('bikram-sambat'));
      expect(manifest.seasonSystem, equals('six-ritus'));
    });

    test('loads ingredients correctly with six ritus availability', () {
      final file = File('${packDir.path}/ingredients.json');
      expect(file.existsSync(), isTrue);

      final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      expect(list.length, greaterThanOrEqualTo(60));

      final ingredients = list.map((i) => RegionIngredient.fromJson(i as Map<String, dynamic>)).toList();
      final potato = ingredients.firstWhere((i) => i.id == 'potato');

      expect(potato.nameNe, equals('आलु'));
      expect(potato.availability.containsKey('basanta'), isTrue);
      expect(potato.availability.containsKey('hemanta'), isTrue);
    });

    test('loads recipes correctly with pressure cooker profiles', () {
      final file = File('${packDir.path}/recipes.json');
      expect(file.existsSync(), isTrue);

      final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      expect(list.length, greaterThanOrEqualTo(150));

      final recipes = list.map((r) => RegionRecipe.fromJson(r as Map<String, dynamic>)).toList();
      final dal = recipes.firstWhere((r) => r.id == 'kalo-dal-jimbu');

      expect(dal.titleNe, contains('कालो दाल'));
      expect(dal.pressureCooker.enabled, isTrue);
      expect(dal.pressureCooker.effectiveWhistlesForKathmandu(), equals(4));
    });

    test('loads festivals correctly', () {
      final file = File('${packDir.path}/festivals.json');
      expect(file.existsSync(), isTrue);

      final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      expect(list.length, greaterThanOrEqualTo(10));

      final festivals = list.map((f) => RegionFestival.fromJson(f as Map<String, dynamic>)).toList();
      final dashain = festivals.firstWhere((f) => f.id == 'dashain');

      expect(dashain.nameNe, contains('दसैँ'));
      expect(dashain.keyDishes.isNotEmpty, isTrue);
    });

    test('loads seasonality and constructs RegionPack correctly', () {
      final seasonFile = File('${packDir.path}/seasonality.json');
      expect(seasonFile.existsSync(), isTrue);

      final seasonJson = jsonDecode(seasonFile.readAsStringSync()) as Map<String, dynamic>;
      final seasonality = RegionSeasonality.fromJson(seasonJson);
      expect(seasonality.ritus.length, equals(6));

      final sharad = seasonality.ritus.firstWhere((r) => r.id == 'sharad');
      expect(sharad.monthsBS, contains('Ashwin'));

      final manifest = RegionPackManifest.fromJson(
        jsonDecode(File('${packDir.path}/manifest.json').readAsStringSync()) as Map<String, dynamic>,
      );
      final ingredients = (jsonDecode(File('${packDir.path}/ingredients.json').readAsStringSync()) as List)
          .map((i) => RegionIngredient.fromJson(i as Map<String, dynamic>))
          .toList();
      final recipes = (jsonDecode(File('${packDir.path}/recipes.json').readAsStringSync()) as List)
          .map((r) => RegionRecipe.fromJson(r as Map<String, dynamic>))
          .toList();
      final festivals = (jsonDecode(File('${packDir.path}/festivals.json').readAsStringSync()) as List)
          .map((f) => RegionFestival.fromJson(f as Map<String, dynamic>))
          .toList();

      final pack = RegionPack(
        manifest: manifest,
        seasonality: seasonality,
        ingredients: ingredients,
        recipes: recipes,
        festivals: festivals,
      );

      final potatoRecipes = pack.getRecipesForIngredient('potato');
      expect(potatoRecipes.isNotEmpty, isTrue);

      final potatoSharad = pack.getIngredientAvailability('potato', 'sharad');
      expect(potatoSharad, equals(AvailabilityLevel.peak));
      expect(potatoSharad.labelEn, equals('Peak Season'));
      expect(potatoSharad.labelNe, contains('उत्कृष्ट सिजन'));
    });
  });
}
