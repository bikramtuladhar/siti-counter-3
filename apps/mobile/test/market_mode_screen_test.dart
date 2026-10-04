import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:siti_counter/groceries/market_mode_screen.dart';
import 'package:siti_counter/planner/planner_repository.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const sampleItems = [
    GroceryItem(
      ingredientId: 'potato',
      nameEn: 'Potato',
      nameNe: 'आलु',
      category: 'vegetables',
      stall: MarketStall.vegetables,
      standardUnit: 'pau',
      totalRequiredGrams: 500,
      pantryAvailableGrams: 0,
      netNeededGrams: 500,
      marketPackageGrams: 250,
      packagesToBuy: 2,
      totalPurchasedGrams: 500,
      surplusGrams: 0,
      vendorUnitLabelEn: '2 pau (500 g)',
      vendorUnitLabelNe: '२ पाउ (५०० ग्राम)',
      isSufficientInPantry: false,
    ),
    GroceryItem(
      ingredientId: 'cauliflower',
      nameEn: 'Cauliflower',
      nameNe: 'काउली',
      category: 'vegetables',
      stall: MarketStall.vegetables,
      standardUnit: 'kg',
      totalRequiredGrams: 1000,
      pantryAvailableGrams: 0,
      netNeededGrams: 1000,
      marketPackageGrams: 1000,
      packagesToBuy: 1,
      totalPurchasedGrams: 1000,
      surplusGrams: 0,
      vendorUnitLabelEn: '1 kg',
      vendorUnitLabelNe: '१ के.जी.',
      isSufficientInPantry: false,
    ),
    GroceryItem(
      ingredientId: 'jimbu',
      nameEn: 'Jimbu',
      nameNe: 'जिम्बु',
      category: 'spices',
      stall: MarketStall.spices,
      standardUnit: 'packet',
      totalRequiredGrams: 15,
      pantryAvailableGrams: 0,
      netNeededGrams: 15,
      marketPackageGrams: 50,
      packagesToBuy: 1,
      totalPurchasedGrams: 50,
      surplusGrams: 35,
      vendorUnitLabelEn: '1 packet (50 g)',
      vendorUnitLabelNe: '१ प्याकेट (५० ग्राम)',
      isSufficientInPantry: false,
    ),
  ];

  final sampleStalls = [
    GroceryStallGroup(
      stall: MarketStall.vegetables,
      nameEn: 'Vegetables',
      nameNe: 'तरकारी गल्ली (Vegetables)',
      shortNameNe: 'तरकारी',
      icon: '🥕',
      items: [sampleItems[0], sampleItems[1]],
    ),
    GroceryStallGroup(
      stall: MarketStall.spices,
      nameEn: 'Spices',
      nameNe: 'मसला गल्ली (Spices)',
      shortNameNe: 'मसला',
      icon: '🌶️',
      items: [sampleItems[2]],
    ),
  ];

  final sampleResult = GroceryListResult(
    items: sampleItems,
    stalls: sampleStalls,
    totalItems: 3,
    totalItemsToBuy: 3,
    totalPantryCoveredItems: 0,
    totalPurchasedGrams: 1550,
    totalSurplusGrams: 35,
  );

  Future<WeeklyPlannerRepository> makeRepo(WidgetTester tester) async {
    final repo = await tester.runAsync(() async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await WeeklyPlannerRepository.createTables(db);
      return WeeklyPlannerRepository(db);
    });
    return repo!;
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host({
    required WeeklyPlannerRepository repo,
    String language = 'ne',
    VoidCallback? onFinished,
  }) {
    return MaterialApp(
      home: MarketModeScreen(
        groceryResult: sampleResult,
        repository: repo,
        currentLanguage: language,
        onFinishedShopping: onFinished,
      ),
    );
  }

  group('MarketModeScreen Tests', () {
    testWidgets('renders high-contrast checklist with large tap targets and vendor units',
        (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(host(repo: repo));
      await settle(tester);

      // Verify Header & Progress Banner
      expect(find.text('MARKET'), findsOneWidget);
      expect(find.text('बजार मोड (चेकलिस्ट)'), findsOneWidget);
      expect(find.textContaining('सामग्री किनियो'), findsOneWidget);
      expect(find.text('०%'), findsOneWidget);

      // Verify Stalls and Items with prominent badges
      expect(find.text('तरकारी गल्ली (Vegetables)'), findsOneWidget);
      expect(find.text('मसला गल्ली (Spices)'), findsOneWidget);
      expect(find.text('आलु'), findsOneWidget);
      expect(find.text('काउली'), findsOneWidget);
      expect(find.text('जिम्बु'), findsOneWidget);

      expect(find.text('२ पाउ (५०० ग्राम)'), findsOneWidget);
      expect(find.text('१ के.जी.'), findsOneWidget);
      expect(find.text('१ प्याकेट (५० ग्राम)'), findsOneWidget);

      expect(find.byKey(const Key('market_mode_finish_btn')), findsOneWidget);
    });

    testWidgets('checking item automatically updates progress and persists in SQLite pantry',
        (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(host(repo: repo));
      await settle(tester);

      // Check potato
      final potatoItem = find.byKey(const Key('market_item_potato'));
      expect(potatoItem, findsOneWidget);
      await tester.tap(potatoItem);
      await settle(tester);

      // Progress should now reflect 1/3 (33%)
      expect(find.text('३३%'), findsOneWidget);

      // Verify persisted to SQLite pantry
      final pantry = await tester.runAsync(() => repo.getPantryItems());
      expect(pantry?['potato'], equals(500.0));

      // Uncheck potato
      await tester.tap(potatoItem);
      await settle(tester);

      expect(find.text('०%'), findsOneWidget);
      final pantryAfterUncheck = await tester.runAsync(() => repo.getPantryItems());
      expect(pantryAfterUncheck?['potato'], isNull);
    });

    testWidgets('filters checklist by stall chips', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(host(repo: repo));
      await settle(tester);

      // Tap Spices stall chip
      final spiceChip = find.byKey(const Key('market_filter_spices'));
      expect(spiceChip, findsOneWidget);
      await tester.tap(spiceChip);
      await tester.pump();

      expect(find.text('जिम्बु'), findsOneWidget);
      expect(find.text('आलु'), findsNothing);

      // Tap All stall chip
      final allChip = find.byKey(const Key('market_filter_all'));
      await tester.tap(allChip);
      await tester.pump();

      expect(find.text('आलु'), findsOneWidget);
      expect(find.text('जिम्बु'), findsOneWidget);
    });

    testWidgets('toggles language between Nepali and English in Market Mode',
        (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      await tester.pumpWidget(host(repo: repo, language: 'ne'));
      await settle(tester);

      expect(find.text('बजार मोड (चेकलिस्ट)'), findsOneWidget);

      // Tap language toggle
      final langBtn = find.byKey(const Key('market_mode_lang_toggle'));
      await tester.tap(langBtn);
      await tester.pump();

      expect(find.text('Market Mode Checklist'), findsOneWidget);
      expect(find.text('Vegetables'), findsWidgets);
      expect(find.text('Potato'), findsOneWidget);
    });

    testWidgets('share button opens export sheet with WhatsApp/SMS preview and copy action',
        (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(host(repo: repo));
      await settle(tester);

      // Tap share button
      final shareBtn = find.byKey(const Key('share_list_btn'));
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await settle(tester);

      // Verify Export Sheet opened
      expect(find.text('किनमेल सूची सेयर (Share List)'), findsOneWidget);
      expect(find.byKey(const Key('export_preview_text')), findsOneWidget);

      // Preview text contains WhatsApp header and items
      final previewTextFinder = find.byKey(const Key('export_preview_text'));
      final selectableText = tester.widget<SelectableText>(previewTextFinder);
      expect(selectableText.data, contains('🛒 सिटि काउन्टर'));
      expect(selectableText.data, contains('आलु'));

      // Switch language in export sheet to English
      final enChip = find.byKey(const Key('export_lang_en'));
      await tester.tap(enChip);
      await tester.pump();

      final selectableTextEn = tester.widget<SelectableText>(previewTextFinder);
      expect(selectableTextEn.data, contains('Siti Counter'));
      expect(selectableTextEn.data, contains('Potato'));

      // Tap Copy button
      final copyBtn = find.byKey(const Key('copy_grocery_list_btn'));
      expect(copyBtn, findsOneWidget);
      await tester.ensureVisible(copyBtn);
      await tester.tap(copyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify SnackBar feedback
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('finish shopping button triggers callback and pops', (tester) async {
      bigScreen(tester);
      final repo = await makeRepo(tester);
      bool finishedCalled = false;

      await tester.pumpWidget(
        host(
          repo: repo,
          onFinished: () => finishedCalled = true,
        ),
      );
      await settle(tester);

      final finishBtn = find.byKey(const Key('market_mode_finish_btn'));
      await tester.tap(finishBtn);
      await settle(tester);

      expect(finishedCalled, isTrue);
    });
  });
}
