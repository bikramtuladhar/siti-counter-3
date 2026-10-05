import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/ocr/food_label_scanner_sheet.dart';
import 'package:siti_counter/ocr/ocr_scanner_service.dart';
import 'package:siti_counter/ocr/receipt_scanner_screen.dart';
import 'package:siti_counter/planner/planner_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const scannerService = OcrScannerService();

  Future<WeeklyPlannerRepository> makeRepo(WidgetTester tester) async {
    final repo = await tester.runAsync(() async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await WeeklyPlannerRepository.createTables(db);
      return WeeklyPlannerRepository(db);
    });
    return repo!;
  }

  group('OcrScannerService & Pantry Sync Unit Tests', () {
    test('parses receipt and synchronizes confirmed items into SQLite pantry', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await WeeklyPlannerRepository.createTables(db);
      final repository = WeeklyPlannerRepository(db);
      addTearDown(() => db.close());

      const sampleReceipt = '''
BHATBHATENI SUPERMARKET
DATE: 2026-03-24
POTATO RED 1.5 KG      Rs 97.50
BBSM MUSTARD OIL 1L    Rs 320.00
TOMATO LOCAL 500G      Rs 45.00
TOTAL:                 Rs 462.50
''';

      final parsed = scannerService.parseReceipt(sampleReceipt);
      expect(parsed.items.length, 3);

      final count = await scannerService.syncItemsToPantry(repository, parsed.items);
      expect(count, 3);

      final pantry = await repository.getPantryItems();
      expect(pantry['potato'], 1500.0);
      expect(pantry['mustard_oil'], 1000.0);
      expect(pantry['tomato'], 500.0);

      // Re-sync adds to existing quantities
      await scannerService.syncItemsToPantry(repository, [
        const ParsedReceiptItem(
          rawLine: 'POTATO 500G',
          name: 'Potato',
          matchedIngredientId: 'potato',
          quantityGrams: 500.0,
        ),
      ]);

      final updatedPantry = await repository.getPantryItems();
      expect(updatedPantry['potato'], 2000.0);
    });

    test('scans food label and detects severe allergens and trace warnings', () {
      const labelText = '''
Ingredients: Refined wheat flour, Sugar, Milk solids, Salt.
Allergy Information: Contains Gluten and Milk.
May contain traces of Peanuts and Tree Nuts. Processed on shared equipment.
''';

      const household = [
        HouseholdMemberAllergyInput(
          memberId: 'm1',
          memberName: 'Aayush',
          allergen: AllergenCatalog.peanuts,
          severity: AllergySeverity.severe,
        ),
        HouseholdMemberAllergyInput(
          memberId: 'm2',
          memberName: 'Sita',
          allergen: AllergenCatalog.milk,
          severity: AllergySeverity.mild,
        ),
      ];

      final result = scannerService.scanFoodLabel(labelText, householdMembers: household);

      expect(result.isSafeForHousehold, isFalse);
      expect(result.detectedAllergens, contains(AllergenCatalog.gluten));
      expect(result.detectedAllergens, contains(AllergenCatalog.milk));
      expect(result.facilityWarnings, contains(AllergenCatalog.peanuts));
      expect(result.facilityWarnings, contains(AllergenCatalog.nuts));
      expect(result.memberAlerts.length, 2);
      expect(result.highlightSpans.length, greaterThanOrEqualTo(4));
    });
  });

  group('ReceiptScannerScreen Widget Tests', () {
    testWidgets('renders receipt items and syncs to pantry upon tapping button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = await makeRepo(tester);

      const receiptText = '''
BHATBHATENI SUPERMARKET
DATE: 2026-03-24
POTATO RED 1.5 KG      Rs 97.50
TOMATO LOCAL 500G      Rs 45.00
TOTAL:                 Rs 142.50
''';

      bool synced = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            plannerRepository: repository,
            initialReceiptText: receiptText,
            onPantrySynced: () => synced = true,
          ),
        ),
      );
      await settle(tester);

      // Verify merchant and items displayed
      expect(find.text('Bhatbhateni Supermarket'), findsOneWidget);
      expect(find.text('POTATO RED'), findsOneWidget);
      expect(find.text('TOMATO LOCAL'), findsOneWidget);
      expect(find.text('potato'), findsOneWidget);
      expect(find.text('tomato'), findsOneWidget);

      // Verify Add to Pantry button
      final addBtnFinder = find.byKey(const Key('add_to_pantry_btn'));
      expect(addBtnFinder, findsOneWidget);

      await tester.ensureVisible(addBtnFinder);
      await tester.pump();
      await tester.tap(addBtnFinder);
      await settle(tester);

      expect(synced, isTrue);

      final pantry = await tester.runAsync(() => repository.getPantryItems());
      expect(pantry!['potato'], 1500.0);
      expect(pantry['tomato'], 500.0);
    });

    testWidgets('switches to sample Haat Bazaar bill when sample button tapped', (tester) async {
      final repository = await makeRepo(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            plannerRepository: repository,
            isNepali: true,
          ),
        ),
      );
      await settle(tester);

      final sampleBtn = find.text('हाट बजार / किराना');
      expect(sampleBtn, findsOneWidget);

      await tester.tap(sampleBtn);
      await settle(tester);

      expect(find.text('Haat Bazaar Bill'), findsOneWidget);
      expect(find.text('potato'), findsOneWidget);
      expect(find.text('tomato'), findsOneWidget);
    });
  });

  group('FoodLabelScannerSheet Widget Tests', () {
    testWidgets('displays NOT SAFE FOR HOUSEHOLD banner when severe allergen matched', (tester) async {
      const household = [
        HouseholdMemberAllergyInput(
          memberId: 'm1',
          memberName: 'Aayush',
          allergen: AllergenCatalog.peanuts,
          severity: AllergySeverity.severe,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodLabelScannerSheet(
              householdMembers: household,
              initialLabelText: 'Ingredients: Wheat flour, Peanuts, Salt.\nContains Peanuts.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('verdict_danger_banner')), findsOneWidget);
      expect(find.text('NOT SAFE FOR HOUSEHOLD!'), findsOneWidget);
      expect(find.text('Aayush'), findsOneWidget);
      expect(find.text('SEVERE'), findsOneWidget);
    });

    testWidgets('displays PROCEED WITH CAUTION when only facility/trace warning present', (tester) async {
      const household = [
        HouseholdMemberAllergyInput(
          memberId: 'm1',
          memberName: 'Nabin',
          allergen: AllergenCatalog.nuts,
          severity: AllergySeverity.mild,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodLabelScannerSheet(
              householdMembers: household,
              initialLabelText: 'Ingredients: Rice flour, Sugar.\nMay contain traces of Tree Nuts.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('verdict_caution_banner')), findsOneWidget);
      expect(find.text('PROCEED WITH CAUTION'), findsOneWidget);
    });

    testWidgets('displays SAFE FOR ALL MEMBERS when food is clean', (tester) async {
      const household = [
        HouseholdMemberAllergyInput(
          memberId: 'm1',
          memberName: 'Aayush',
          allergen: AllergenCatalog.peanuts,
          severity: AllergySeverity.severe,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodLabelScannerSheet(
              householdMembers: household,
              initialLabelText: 'Ingredients: 100% Organic Rice, Water, Salt.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('verdict_safe_banner')), findsOneWidget);
      expect(find.text('SAFE FOR ALL MEMBERS'), findsOneWidget);
    });
  });
}
