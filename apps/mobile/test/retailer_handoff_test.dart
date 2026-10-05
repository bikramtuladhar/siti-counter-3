import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/commerce/retailer_handoff_service.dart';
import 'package:siti_counter/commerce/retailer_handoff_sheet.dart';
import 'package:siti_counter/data/region_pack_repository.dart';
import 'package:siti_counter/groceries/grocery_list_screen.dart';
import 'package:siti_counter/planner/planner_models.dart';
import 'package:siti_counter/planner/planner_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('RetailerHandoffService Unit Tests', () {
    test('Service provides neutral sorted retailers and generates valid links', () async {
      Uri? launchedUri;
      final service = RetailerHandoffService(
        countryCode: 'NP',
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );

      // Verify retailers and zero bias order
      final retailers = service.availableRetailers;
      expect(retailers.length, 3);
      expect(retailers[0].id, 'bhatbhateni');
      expect(retailers[1].id, 'bigmart');
      expect(retailers[2].id, 'daraz');

      // Generate Daraz link
      final darazLink = service.getItemDeepLink('daraz', 'Mustard Oil');
      expect(darazLink, isNotNull);
      expect(darazLink!.appDeepLinkUrl, contains('daraz://catalog?q=Mustard%20Oil&tag=siticounter'));
      expect(darazLink.webUrl, contains('https://www.daraz.com.np/catalog/?q=Mustard%20Oil&tag=siticounter'));

      // Launch test
      final success = await service.launchLink(darazLink.appDeepLinkUrl);
      expect(success, isTrue);
      expect(launchedUri.toString(), darazLink.appDeepLinkUrl);

      // Basket handoff
      final basket = service.getBasketHandoff('bhatbhateni', ['Potato', 'Tomato']);
      expect(basket, isNotNull);
      expect(basket!.combinedSearchQuery, 'Potato Tomato');
      expect(basket.appDeepLinkUrl, contains('bbsm://search?q=Potato%20Tomato&ref=siticounter'));
    });

    test('Opt-Out disables partner links and notifies listeners', () {
      final service = RetailerHandoffService();
      bool notified = false;
      service.addListener(() => notified = true);

      expect(service.partnerLinksEnabled, isTrue);
      service.setPartnerLinksEnabled(false);

      expect(notified, isTrue);
      expect(service.partnerLinksEnabled, isFalse);
      expect(service.availableRetailers, isEmpty);
      expect(service.getItemDeepLink('daraz', 'potato'), isNull);
    });
  });

  group('RetailerHandoffSheet Widget Tests', () {
    testWidgets('Renders disclosure banner, retailer cards, and triggers URL launch',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? launchedUrl;
      bool? isAppScheme;

      final service = RetailerHandoffService(countryCode: 'NP');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_sheet_btn'),
                onPressed: () {
                  RetailerHandoffSheet.show(
                    context: context,
                    retailerService: service,
                    singleItemName: 'आलु रातो',
                    currentLanguage: 'ne',
                    onLaunchUrl: (url, isApp) {
                      launchedUrl = url;
                      isAppScheme = isApp;
                    },
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // 1. Verify Header and Title
      expect(find.text('आलु रातो अनलाइन खोज्नुहोस्'), findsOneWidget);
      expect(find.text('नेपालका प्रमुख अनलाइन डेलिभरी पार्टनरहरू'), findsOneWidget);

      // 2. Verify Affiliate Disclosure Banner & Zero Bias notice
      expect(find.byKey(const Key('affiliate_disclosure_banner')), findsOneWidget);
      expect(find.textContaining('सिट्ठी काउन्टरले केही पार्टनरहरूबाट सानो कमिसन प्राप्त गर्न सक्छ'),
          findsOneWidget);
      expect(find.textContaining('कुनै विज्ञापन वा भुक्तानी पूर्वाग्रह बिना निष्पक्ष'),
          findsOneWidget);

      // 3. Verify Retailer Cards
      expect(find.byKey(const Key('retailer_card_daraz')), findsOneWidget);
      expect(find.byKey(const Key('retailer_card_bhatbhateni')), findsOneWidget);
      expect(find.byKey(const Key('retailer_card_bigmart')), findsOneWidget);

      // 4. Tap 'Open in App' for Daraz
      final darazAppBtn = find.byKey(const Key('open_app_btn_daraz'));
      expect(darazAppBtn, findsOneWidget);
      await tester.ensureVisible(darazAppBtn);
      await tester.tap(darazAppBtn);
      await tester.pumpAndSettle();

      expect(launchedUrl, isNotNull);
      expect(launchedUrl, startsWith('daraz://catalog?q=%E0%A4%86%E0%A4%B2%E0%A5%81%20%E0%A4%B0%E0%A4%BE%E0%A4%A4%E0%A5%8B&tag=siticounter'));
      expect(isAppScheme, isTrue);
    });

    testWidgets('Toggling partner links switch disables retailer list', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = RetailerHandoffService(countryCode: 'NP');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_sheet_btn'),
                onPressed: () {
                  RetailerHandoffSheet.show(
                    context: context,
                    retailerService: service,
                    singleItemName: 'potato',
                    currentLanguage: 'en',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      expect(service.partnerLinksEnabled, isTrue);
      expect(find.byKey(const Key('retailer_card_daraz')), findsOneWidget);

      // Toggle off
      final toggle = find.byKey(const Key('partner_links_toggle'));
      expect(toggle, findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(service.partnerLinksEnabled, isFalse);
      expect(find.text('Shopping partner links are disabled in your preferences.'), findsOneWidget);
      expect(find.byKey(const Key('retailer_card_daraz')), findsNothing);
    });
  });

  group('GroceryListScreen Retailer Integration Tests', () {
    testWidgets('GroceryListScreen renders online shopping entry points and respects opt-out',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = (await tester.runAsync(() async {
        final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await WeeklyPlannerRepository.createTables(db);
        final r = WeeklyPlannerRepository(db);
        await r.savePlannedMeal(
          const PlannedMeal(
            id: 'm1',
            dateIso: '2026-10-04',
            slotId: 'morning-dal-bhat',
            recipeId: 'alu_cauli_tarkari',
            recipeTitleEn: 'Aloo Cauli Tarkari',
            recipeTitleNe: 'आलु काउली तरकारी',
            servings: 4,
          ),
        );
        return r;
      }))!;

      final testPack = RegionPack(
        manifest: const RegionPackManifest(
          id: 'nepal-bagmati',
          version: '1.0.0',
          name: 'Bagmati',
          country: 'Nepal',
          countryCode: 'NP',
          region: 'Bagmati',
          status: 'beta',
          elevationMeters: 1400,
          defaultLanguage: 'ne',
          calendar: 'bikram-sambat',
          seasonSystem: 'six-ritus',
        ),
        seasonality: const RegionSeasonality(
          regionId: 'nepal-bagmati',
          ritus: [],
        ),
        ingredients: const [
          RegionIngredient(
            id: 'potato',
            nameEn: 'Potato',
            nameNe: 'आलु',
            aliases: ['alu'],
            category: 'vegetables',
            standardUnit: 'pau',
            marketPackageGrams: 250,
            storageDays: 14,
            allergens: [],
            availability: {},
          ),
        ],
        recipes: const [
          RegionRecipe(
            id: 'alu_cauli_tarkari',
            titleEn: 'Aloo Cauli Tarkari',
            titleNe: 'आलु काउली तरकारी',
            category: 'curry',
            cuisine: 'pan-nepali',
            prepTimeMinutes: 15,
            cookTimeMinutes: 20,
            servings: 4,
            difficulty: 'easy',
            costEstimateNpr: 180,
            dietary: ['vegetarian', 'vegan'],
            tags: ['curry'],
            ingredients: [
              RecipeIngredientItem(ingredientId: 'potato', quantity: 500, unit: 'g'),
            ],
            pressureCooker: RecipeWhistleProfile(
              enabled: true,
              recommendedWhistles: 2,
              altitudeWhistleOffsetKathmandu: 0,
              heatLevel: 'medium',
              releaseType: 'quick',
            ),
            seasonality: [],
          ),
        ],
        festivals: const [],
        preservationSuggestions: const [],
      );

      final regionRepo = RegionPackRepository();
      regionRepo.setPack(testPack);

      final retailerService = RetailerHandoffService();

      await tester.pumpWidget(
        MaterialApp(
          home: GroceryListScreen(
            weekStart: DateTime(2026, 10, 4),
            repository: repo,
            regionPackRepository: regionRepo,
            retailerHandoffService: retailerService,
            currentLanguage: 'ne',
          ),
        ),
      );

      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Online shopping button in AppBar exists
      expect(find.byKey(const Key('shop_online_btn')), findsOneWidget);

      // 2. Verify per-item online shopping button exists
      expect(find.byKey(const Key('item_retailer_btn_potato')), findsOneWidget);

      // 3. Tap shop_online_btn to open RetailerHandoffSheet
      await tester.tap(find.byKey(const Key('shop_online_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('affiliate_disclosure_banner')), findsOneWidget);
      expect(find.byKey(const Key('retailer_card_daraz')), findsOneWidget);

      // 4. Disable partner links via the toggle
      await tester.tap(find.byKey(const Key('partner_links_toggle')));
      await tester.pumpAndSettle();

      expect(retailerService.partnerLinksEnabled, isFalse);

      // Close sheet
      await tester.tap(find.byKey(const Key('close_retailer_sheet_btn')));
      await tester.pumpAndSettle();

      // Trigger rebuild
      await tester.pump();

      // When disabled, the buttons are hidden
      expect(find.byKey(const Key('shop_online_btn')), findsNothing);
      expect(find.byKey(const Key('item_retailer_btn_potato')), findsNothing);
    });
  });
}
