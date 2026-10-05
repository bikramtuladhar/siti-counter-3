import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/data/region_pack_repository.dart';
import 'package:siti_counter/screens/region_manager_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RegionPackRepository repository;

  setUp(() {
    repository = RegionPackRepository();
    repository.setPack(RegionPackManager.getSamplePack('nepal-bagmati')!);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: RegionManagerScreen(
        repository: repository,
        currentLanguage: 'en',
      ),
    );
  }

  group('Region Pack Expansion Framework & Asset Tests (Issue #44)', () {
    test('catalog contains verified entries for India Delhi, Australia Diaspora, and Andes', () {
      final catalog = repository.catalog;

      final delhi = catalog.firstWhere((c) => c.id == 'india-delhi');
      expect(delhi.countryCode, equals('IN'));
      expect(delhi.currencyCode, equals('INR'));
      expect(delhi.marketUnits, contains('katori'));
      expect(delhi.marketUnits, contains('pao'));
      expect(delhi.marketUnits, contains('seer'));

      final australia = catalog.firstWhere((c) => c.id == 'australia-diaspora');
      expect(australia.countryCode, equals('AU'));
      expect(australia.currencyCode, equals('AUD'));
      expect(australia.seasonSystem, equals('four-seasons-southern'));

      final andes = catalog.firstWhere((c) => c.id == 'andes-lapaz');
      expect(andes.countryCode, equals('BO'));
      expect(andes.elevationMeters, equals(3600));
      expect(andes.marketUnits, contains('arroba'));
      expect(andes.marketUnits, contains('monton'));
    });

    testWidgets('India Delhi Pack: loads asset bundle, verifies IFCT nutrition, mandi units, and renders in UI', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pack = await repository.loadRegionPack(regionId: 'india-delhi');
      expect(pack.manifest.id, equals('india-delhi'));
      expect(pack.manifest.currencyCode, equals('INR'));
      expect(pack.manifest.marketUnits, contains('katori'));
      expect(pack.manifest.marketUnits, contains('pao'));
      expect(pack.ingredients.any((i) => i.id == 'rajma'), isTrue);
      expect(pack.recipes.any((r) => r.id == 'delhi-rajma-masala'), isTrue);
      expect(pack.festivals.any((f) => f.id == 'diwali'), isTrue);

      // Set as primary residence in mobile repository
      repository.setPack(pack);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Primary Residence'), findsOneWidget);
      expect(find.text('India (Delhi & Northern Plains)'), findsOneWidget);
      expect(find.text('216 m'), findsOneWidget);
      expect(find.text('99.2°C'), findsOneWidget); // 100 - (216/285) = 99.24°C

      final context = repository.manager.resolveContext(forDate: DateTime(2026, 11, 15));
      expect(context.activeSeasonId, equals('hemant'));
      expect(context.currencySymbol, equals('₹'));
    });

    testWidgets('Australia Diaspora Pack: loads asset bundle, inverted seasons, and Taste of Home substitutes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pack = await repository.loadRegionPack(regionId: 'australia-diaspora');
      expect(pack.manifest.countryCode, equals('AU'));
      expect(pack.manifest.seasonSystem, equals('four-seasons-southern'));
      expect(pack.ingredients.any((i) => i.id == 'tasmanian_pepperberry'), isTrue);
      expect(pack.ingredients.any((i) => i.id == 'aussie_lamb'), isTrue);

      // Setup primary Australia + secondary Bagmati
      repository.setPack(pack);
      repository.addSecondaryPack('nepal-bagmati');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Australia (Diaspora & Southern Seasons)'), findsOneWidget);
      expect(find.text('50 m'), findsOneWidget);
      expect(find.text('99.8°C'), findsOneWidget);

      final springContext = repository.manager.resolveContext(forDate: DateTime(2026, 10, 15));
      expect(springContext.activeSeasonId, equals('spring'));
      expect(springContext.combinedRecipes.any((r) => r.id == 'sydney-spring-lamb-curry'), isTrue);
      expect(springContext.combinedRecipes.any((r) => r.id == 'kalo-dal'), isTrue);
    });

    testWidgets('Andes High-Altitude Pack: loads asset bundle, 3,600m calibration, chuño, and +2 whistles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pack = await repository.loadRegionPack(regionId: 'andes-lapaz');
      expect(pack.manifest.elevationMeters, equals(3600));
      expect(pack.ingredients.any((i) => i.id == 'chuno'), isTrue);
      expect(pack.ingredients.any((i) => i.id == 'quinoa'), isTrue);

      repository.setPack(pack);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Andes (Bolivia / La Paz Altiplano)'), findsOneWidget);
      expect(find.text('3600 m'), findsOneWidget);
      expect(find.text('87.4°C'), findsOneWidget); // 100 - (3600/285) = 87.368 -> 87.4°C

      final context = repository.manager.resolveContext();
      expect(context.effectiveBoilingPointCelsius, closeTo(87.4, 0.3));
      final soup = context.combinedRecipes.firstWhere((r) => r.id == 'sopa-de-mani-chuno');
      expect(context.adjustWhistlesForRecipe(soup), equals(8)); // 6 base + 2 altitude
    });
  });
}
