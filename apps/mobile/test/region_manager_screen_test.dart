import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/data/region_pack_repository.dart';
import 'package:siti_counter/screens/region_manager_screen.dart';

void main() {
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

  group('RegionManagerScreen Widget Tests', () {
    testWidgets('renders primary residence card with altitude and boiling point', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Primary Residence'), findsOneWidget);
      expect(find.text('Nepal (Bagmati Province)'), findsOneWidget);
      expect(find.text('1400 m'), findsOneWidget);
      expect(find.text('95.1°C'), findsOneWidget); // 100 - 1400/285 = 95.088 -> 95.1°C
      expect(find.text('Switch Primary Region'), findsOneWidget);
    });

    testWidgets('browses pack store and installs a new region pack', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to Pack Store tab
      final storeTab = find.byKey(const Key('tab_catalog_store'));
      await tester.tap(storeTab);
      await tester.pumpAndSettle();

      expect(find.text('Available Region Packs'), findsOneWidget);
      expect(find.text('Australia (New South Wales / Sydney)'), findsOneWidget);

      // Verify Australia NSW is not installed yet
      final installNswBtn = find.byKey(const Key('btn_install_australia-nsw'));
      expect(installNswBtn, findsOneWidget);

      // Tap install
      await tester.tap(installNswBtn);
      await tester.pumpAndSettle();

      // Now Australia NSW should be installed
      expect(repository.manager.isInstalled('australia-nsw'), isTrue);
      expect(find.byKey(const Key('btn_installed_australia-nsw')), findsOneWidget);
    });

    testWidgets('switches active primary residence to installed region', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pre-install Australia NSW
      await repository.installPack('australia-nsw');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final switchBtn = find.byKey(const Key('btn_switch_primary_region'));
      await tester.tap(switchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Select Primary Residence'), findsOneWidget);

      final optionNsw = find.byKey(const Key('option_primary_australia-nsw'));
      expect(optionNsw, findsOneWidget);

      await tester.tap(optionNsw);
      await tester.pumpAndSettle();

      // Primary residence is now Sydney (50m)
      expect(repository.activeConfig.primaryPackId, equals('australia-nsw'));
      expect(find.text('Australia (New South Wales / Sydney)'), findsOneWidget);
      expect(find.text('50 m'), findsOneWidget);
      expect(find.text('99.8°C'), findsOneWidget);
    });

    testWidgets('enables diaspora mode with layered secondary heritage pack', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Sydney primary, add Nepal secondary
      await repository.installPack('australia-nsw');
      repository.setPrimaryPack('australia-nsw');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Diaspora Mode'), findsOneWidget);
      final addSecondaryBtn = find.byKey(const Key('btn_add_diaspora_pack'));
      await tester.tap(addSecondaryBtn);
      await tester.pumpAndSettle();

      final optionBagmati = find.byKey(const Key('option_secondary_nepal-bagmati'));
      expect(optionBagmati, findsOneWidget);

      await tester.tap(optionBagmati);
      await tester.pumpAndSettle();

      expect(repository.activeConfig.secondaryPackIds, contains('nepal-bagmati'));
      expect(find.text('Nepal (Bagmati Province)'), findsAtLeast(1));
    });

    testWidgets('authors a custom region via modal dialog with altitude and units', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final addCustomBtn = find.byKey(const Key('add_custom_region_appbar_btn'));
      await tester.tap(addCustomBtn);
      await tester.pumpAndSettle();

      expect(find.text('Author Custom Region'), findsOneWidget);

      // Enter custom region fields
      await tester.enterText(find.byKey(const Key('custom_region_name_field')), 'Germany - Bavaria');
      await tester.enterText(find.byKey(const Key('custom_region_country_field')), 'Germany');
      await tester.enterText(find.byKey(const Key('custom_region_elevation_field')), '520');
      await tester.pumpAndSettle();

      // Check boiling point preview updates dynamically: 100 - 520/285 = 98.2°C
      expect(find.textContaining('98.2°C'), findsOneWidget);

      // Save custom region
      final saveBtn = find.byKey(const Key('btn_save_custom_region'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Custom region is installed and set as active primary!
      expect(repository.activeConfig.primaryPackId, equals('custom-germany---bavaria'));
      expect(repository.manager.isInstalled('custom-germany---bavaria'), isTrue);
      expect(find.text('Germany - Bavaria'), findsOneWidget);
      expect(find.text('520 m'), findsOneWidget);
    });

    testWidgets('household altitude override applies without mutating pack elevation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap edit on altitude override
      final editOverrideBtn = find.byKey(const Key('btn_edit_altitude_override'));
      await tester.tap(editOverrideBtn);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Altitude Override')),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('input_altitude_override')), '2100');
      await tester.pumpAndSettle();

      final saveOverrideBtn = find.byKey(const Key('btn_save_altitude_override'));
      await tester.tap(saveOverrideBtn);
      await tester.pumpAndSettle();

      expect(repository.householdOverride?.elevationMeters, equals(2100));
      expect(find.text('2100 m'), findsAtLeast(1));
      expect(find.text('92.6°C'), findsOneWidget); // 100 - 2100/285 = 92.63°C
    });
  });
}
