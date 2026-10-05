import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('RegionPackManager - Catalog & Discovery', () {
    test('default catalog contains verified and community packs with correct metadata', () {
      final manager = RegionPackManager();
      final catalog = manager.catalog;

      expect(catalog.length, greaterThanOrEqualTo(6));

      final bagmati = catalog.firstWhere((c) => c.id == 'nepal-bagmati');
      expect(bagmati.status, equals('verified'));
      expect(bagmati.isBuiltIn, isTrue);
      expect(bagmati.elevationMeters, equals(1400));
      expect(bagmati.seasonSystem, equals('six-ritus'));

      final nsw = catalog.firstWhere((c) => c.id == 'australia-nsw');
      expect(nsw.status, equals('verified'));
      expect(nsw.isBuiltIn, isFalse);
      expect(nsw.elevationMeters, equals(50));
      expect(nsw.seasonSystem, equals('four-seasons-southern'));

      final lagos = catalog.firstWhere((c) => c.id == 'nigeria-lagos');
      expect(lagos.status, equals('community'));
      expect(lagos.marketUnits, contains('derica'));
      expect(lagos.seasonSystem, equals('wet-dry'));

      final lapaz = catalog.firstWhere((c) => c.id == 'bolivia-lapaz');
      expect(lapaz.status, equals('community'));
      expect(lapaz.elevationMeters, equals(3600));
    });
  });

  group('RegionPackManager - Installation & Offline Caching', () {
    test('installs and uninstalls packs from catalog', () async {
      final manager = RegionPackManager();
      expect(manager.isInstalled('australia-nsw'), isFalse);

      await manager.installFromCatalog('australia-nsw');
      expect(manager.isInstalled('australia-nsw'), isTrue);
      expect(manager.getPack('australia-nsw')?.manifest.countryCode, equals('AU'));

      // Check catalog reflects installed status
      final entry = manager.catalog.firstWhere((c) => c.id == 'australia-nsw');
      expect(entry.isInstalled, isTrue);

      // Uninstall
      manager.uninstallPack('australia-nsw');
      expect(manager.isInstalled('australia-nsw'), isFalse);
    });

    test('refuses to uninstall built-in bagmati pack', () {
      final manager = RegionPackManager();
      manager.loadBuiltInPack(RegionPackManager.getSamplePack('nepal-bagmati')!);

      expect(
        () => manager.uninstallPack('nepal-bagmati'),
        throwsUnsupportedError,
      );
    });
  });

  group('RegionPackManager - Multi-Pack Diaspora Setup (Journey 19.3)', () {
    test('Nepali family in Sydney: dual packs, southern spring, altitude whistle adjustment', () async {
      final manager = RegionPackManager();
      // Install Sydney pack and load Bagmati pack
      await manager.installFromCatalog('australia-nsw');
      manager.loadBuiltInPack(RegionPackManager.getSamplePack('nepal-bagmati')!);

      // Set Sydney as residence (primary), Nepal as heritage (secondary)
      manager.setPrimaryPack('australia-nsw');
      manager.addSecondaryPack('nepal-bagmati');

      expect(manager.activeConfig.primaryPackId, equals('australia-nsw'));
      expect(manager.activeConfig.secondaryPackIds, contains('nepal-bagmati'));
      expect(manager.activeConfig.isDiasporaActive, isTrue);

      // October date: in Sydney it is Southern Spring; in Kathmandu it is Sharad
      final octoberDate = DateTime(2026, 10, 15);
      final context = manager.resolveContext(forDate: octoberDate);

      // Primary residence environment
      expect(context.effectiveElevationMeters, equals(50));
      expect(context.activeSeasonId, equals('spring'));
      expect(context.effectiveBoilingPointCelsius, closeTo(99.8, 0.2));
      expect(context.currencyCode, equals('AUD'));

      // Combined recipes: includes Sydney salmon and Kathmandu kalo dal
      final recipeIds = context.combinedRecipes.map((r) => r.id).toList();
      expect(recipeIds, contains('sydney-spring-salmon'));
      expect(recipeIds, contains('kalo-dal'));

      // Whistle adjustment at Sydney altitude (50m):
      // Kathmandu kalo dal has base 4 whistles + 1 for Kathmandu 1400m = 5 whistles in KTM.
      // At 50m (sea level), AltitudeCalculator does not add the altitude whistle!
      final kaloDal = context.combinedRecipes.firstWhere((r) => r.id == 'kalo-dal');
      final whistlesInSydney = context.adjustWhistlesForRecipe(kaloDal);
      expect(whistlesInSydney, equals(4)); // Safe 4 whistles instead of 5 to avoid overcooking!

      // Ingredient availability in primary environment (Sydney Spring)
      final asparagusAvailability = context.getIngredientAvailability('asparagus');
      expect(asparagusAvailability, equals(AvailabilityLevel.peak));
    });

    test('High altitude cooking in La Paz (3,600m - Journey 19.4)', () async {
      final manager = RegionPackManager();
      await manager.installFromCatalog('bolivia-lapaz');
      manager.setPrimaryPack('bolivia-lapaz');

      final context = manager.resolveContext();
      expect(context.effectiveElevationMeters, equals(3600));
      // Water boils at ~87.4°C at 3,600m
      expect(context.effectiveBoilingPointCelsius, closeTo(87.4, 0.2));

      // Whistle adjustment: 4 whistles base * 1.3 ≈ 5 whistles
      final pesque = context.combinedRecipes.firstWhere((r) => r.id == 'pesque-de-quinua');
      final whistles = context.adjustWhistlesForRecipe(pesque);
      expect(whistles, equals(5));
    });
  });

  group('RegionPackManager - Custom Region Authoring', () {
    test('validates input and authors custom region pack', () {
      final manager = RegionPackManager();

      // Test validation errors
      const invalidInput = CustomRegionInput(
        id: '',
        name: '',
        nativeName: '',
        country: '',
        countryCode: '',
        elevationMeters: -50,
        climateZone: 'temperate',
        seasonSystem: 'four-seasons',
        marketUnits: [],
      );
      final errors = invalidInput.validate();
      expect(errors.length, greaterThanOrEqualTo(4));

      // Author valid custom region
      final customInput = CustomRegionInput(
        id: 'germany-bavaria',
        name: 'Germany (Bavaria / Munich)',
        nativeName: 'Bayern (München)',
        country: 'Germany',
        countryCode: 'DE',
        elevationMeters: 520,
        climateZone: 'temperate',
        seasonSystem: 'four-seasons',
        marketUnits: const ['kg', 'g', 'bund', 'stuck'],
        currencyCode: 'EUR',
        currencySymbol: '€',
        customIngredients: const [
          RegionIngredient(
            id: 'baerlauch',
            nameEn: 'Wild Garlic (Bärlauch)',
            nameNe: 'जङ्गली लसुन (Bärlauch)',
            aliases: ['ramsons'],
            category: 'herbs',
            standardUnit: 'bund',
            marketPackageGrams: 100,
            storageDays: 3,
            allergens: [],
            availability: {'spring': 'peak'},
          ),
        ],
      );

      final customPack = manager.createCustomRegion(customInput);
      expect(customPack.manifest.id, equals('germany-bavaria'));
      expect(customPack.manifest.status, equals('custom'));
      expect(customPack.manifest.currencyCode, equals('EUR'));
      expect(manager.isInstalled('germany-bavaria'), isTrue);

      // Verify presence in catalog
      final entry = manager.catalog.firstWhere((c) => c.id == 'germany-bavaria');
      expect(entry.status, equals('custom'));
      expect(entry.isInstalled, isTrue);

      // Switch to custom region
      manager.setPrimaryPack('germany-bavaria');
      final context = manager.resolveContext(forDate: DateTime(2026, 4, 15)); // April = Spring
      expect(context.effectiveElevationMeters, equals(520));
      expect(context.activeSeasonId, equals('spring'));
      expect(context.currencySymbol, equals('€'));
      expect(context.combinedIngredients.map((i) => i.id), contains('baerlauch'));

      // Delete custom region
      manager.deleteCustomRegion('germany-bavaria');
      expect(manager.isInstalled('germany-bavaria'), isFalse);
      expect(manager.activeConfig.primaryPackId, equals('nepal-bagmati'));
    });
  });

  group('RegionPackManager - Household Overrides', () {
    test('layers elevation and unit overrides without mutating pack files', () {
      final manager = RegionPackManager();
      manager.loadBuiltInPack(RegionPackManager.getSamplePack('nepal-bagmati')!);
      manager.setPrimaryPack('nepal-bagmati');

      // Household in Nagarkot (2,100m) above Kathmandu Valley
      const override = HouseholdPackOverride(
        elevationMeters: 2100,
        preferredUnits: ['kg', 'g', 'dharni'],
        whistleOffsets: {'kalo-dal': 1}, // +1 personal cooker preference
      );
      manager.setHouseholdOverride(override);

      final context = manager.resolveContext();
      expect(context.effectiveElevationMeters, equals(2100));
      expect(context.effectiveBoilingPointCelsius, closeTo(92.6, 0.2));
      expect(context.effectiveMarketUnits, equals(['kg', 'g', 'dharni']));

      final kaloDal = context.combinedRecipes.firstWhere((r) => r.id == 'kalo-dal');
      // At 2100m: base 4 * 1.3 = 5, plus household offset +1 = 6 whistles!
      final whistles = context.adjustWhistlesForRecipe(kaloDal);
      expect(whistles, equals(6));
    });
  });

  group('RegionPackManager - Expanded Region Packs (Issue #44)', () {
    test('India Delhi Pack: IFCT references, mandi units (katori, pao, seer), rajma, and Diwali festival', () async {
      final manager = RegionPackManager();
      final delhiEntry = manager.catalog.firstWhere((c) => c.id == 'india-delhi');
      expect(delhiEntry.countryCode, equals('IN'));
      expect(delhiEntry.currencyCode, equals('INR'));
      expect(delhiEntry.marketUnits, contains('katori'));
      expect(delhiEntry.marketUnits, contains('pao'));
      expect(delhiEntry.marketUnits, contains('seer'));

      await manager.installFromCatalog('india-delhi');
      expect(manager.isInstalled('india-delhi'), isTrue);

      manager.setPrimaryPack('india-delhi');
      final novDate = DateTime(2026, 11, 15);
      final context = manager.resolveContext(forDate: novDate);

      expect(context.effectiveElevationMeters, equals(216));
      expect(context.activeSeasonId, equals('hemant'));
      expect(context.currencySymbol, equals('₹'));

      final rajma = context.combinedIngredients.firstWhere((i) => i.id == 'rajma');
      expect(rajma.nameNe, equals('राजमा'));

      final rajmaRecipe = context.combinedRecipes.firstWhere((r) => r.id == 'delhi-rajma-masala');
      expect(rajmaRecipe.pressureCooker.recommendedWhistles, equals(4));

      final diwali = context.combinedFestivals.firstWhere((f) => f.id == 'diwali');
      expect(diwali.tithi, equals('Kartik Amavasya'));
    });

    test('Australia Diaspora Pack: Taste of Home substitutions (Tasmanian pepperberry, Aussie lamb)', () async {
      final manager = RegionPackManager();
      await manager.installFromCatalog('australia-diaspora');
      manager.loadBuiltInPack(RegionPackManager.getSamplePack('nepal-bagmati')!);
      manager.setPrimaryPack('australia-diaspora');
      manager.addSecondaryPack('nepal-bagmati');

      final octoberDate = DateTime(2026, 10, 20); // October = Spring in Southern Hemisphere
      final context = manager.resolveContext(forDate: octoberDate);

      expect(context.activeSeasonId, equals('spring'));
      expect(context.effectiveElevationMeters, equals(50));

      final lambCurry = context.combinedRecipes.firstWhere((r) => r.id == 'sydney-spring-lamb-curry');
      expect(lambCurry.ingredients.any((i) => i.ingredientId == 'aussie_lamb'), isTrue);
      expect(lambCurry.ingredients.any((i) => i.ingredientId == 'tasmanian_pepperberry'), isTrue);

      final pepperberry = context.combinedIngredients.firstWhere((i) => i.id == 'tasmanian_pepperberry');
      expect(pepperberry.category, equals('spices'));
    });

    test('Andes High-Altitude Pack: 3,600m calibration, chuño, peanut soup, and +2 whistle offset', () async {
      final manager = RegionPackManager();
      await manager.installFromCatalog('andes-lapaz');
      manager.setPrimaryPack('andes-lapaz');

      final context = manager.resolveContext();
      expect(context.effectiveElevationMeters, equals(3600));
      expect(context.effectiveBoilingPointCelsius, closeTo(87.4, 0.3));
      expect(context.effectiveMarketUnits, contains('arroba'));
      expect(context.effectiveMarketUnits, contains('monton'));

      final chuno = context.combinedIngredients.firstWhere((i) => i.id == 'chuno');
      expect(chuno.category, equals('vegetables'));

      final peanutSoup = context.combinedRecipes.firstWhere((r) => r.id == 'sopa-de-mani-chuno');
      expect(peanutSoup.pressureCooker.recommendedWhistles, equals(6));
      expect(peanutSoup.pressureCooker.altitudeWhistleOffsetKathmandu, equals(2));

      final whistles = context.adjustWhistlesForRecipe(peanutSoup);
      expect(whistles, equals(8)); // 6 recommended + 2 altitude offset
    });
  });
}
