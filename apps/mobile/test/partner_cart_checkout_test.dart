import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/commerce/retailer_handoff_service.dart';
import 'package:siti_counter/commerce/retailer_handoff_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Partner Cart Direct Transfer (Issue #47) Unit Tests', () {
    test('Service transfers grocery cart to Daraz with tokenized payload', () {
      final service = RetailerHandoffService(countryCode: 'NP');
      final fixedDate = DateTime.utc(2026, 10, 5, 8, 30, 0);

      final items = [
        const PartnerCartItem(
          itemId: 'i1',
          name: 'Mustard Oil (तोरीको तेल)',
          quantity: 2,
          unit: 'L',
          estimatedPriceNpr: 640,
        ),
        const PartnerCartItem(
          itemId: 'i2',
          name: 'Basmati Rice',
          quantity: 5,
          unit: 'kg',
          estimatedPriceNpr: 950,
        ),
      ];

      final result = service.transferGroceryCart(
        householdId: 'hh_ktm_test',
        retailerId: 'daraz',
        items: items,
        cartId: 'cart_test_daraz_47',
        now: fixedDate,
      );

      expect(result, isNotNull);
      expect(result!.cartId, 'cart_test_daraz_47');
      expect(result.householdId, 'hh_ktm_test');
      expect(result.retailerId, 'daraz');
      expect(result.retailerName, 'Daraz');
      expect(result.status, 'ready');
      expect(result.totalItems, 2);
      expect(result.transferredItemsCount, 2);
      expect(result.unmatchedItems, isEmpty);
      expect(result.estimatedSubtotalNpr, 1590);
      expect(result.cartWebUrl, startsWith('https://www.daraz.com.np/cart/import?token='));
      expect(result.cartAppUrl, startsWith('daraz://cart/import?token='));
      expect(result.cartWebUrl, contains('ref=siticounter'));
      expect(result.disclosureEn, contains('Affiliate Disclosure'));
      expect(result.disclosureNe, contains('सहयोगी लिङ्क प्रकटीकरण'));
    });

    test('Service transfers grocery cart to Bhatbhateni and BigMart', () {
      final service = RetailerHandoffService(countryCode: 'NP');
      final items = [
        const PartnerCartItem(
          itemId: 'i1',
          name: 'Black Lentils (मासको दाल)',
          quantity: 1,
          unit: 'kg',
          estimatedPriceNpr: 210,
        ),
      ];

      // Bhatbhateni
      final bbsm = service.transferGroceryCart(
        householdId: 'hh_ktm_test',
        retailerId: 'bhatbhateni',
        items: items,
      );
      expect(bbsm, isNotNull);
      expect(bbsm!.retailerId, 'bhatbhateni');
      expect(bbsm.cartWebUrl, startsWith('https://bhatbhatenionline.com/cart/import?token='));
      expect(bbsm.cartAppUrl, startsWith('bbsm://cart/import?token='));

      // BigMart
      final bm = service.transferGroceryCart(
        householdId: 'hh_ktm_test',
        retailerId: 'bigmart',
        items: items,
      );
      expect(bm, isNotNull);
      expect(bm!.retailerId, 'bigmart');
      expect(bm.cartWebUrl, startsWith('https://bigmart.com.np/cart/import?token='));
      expect(bm.cartAppUrl, startsWith('bigmart://cart/import?token='));
    });

    test('Opt-out returns null on transfer attempt', () {
      final service = RetailerHandoffService(partnerLinksEnabled: false);
      final items = [
        const PartnerCartItem(itemId: 'i1', name: 'Salt', quantity: 1, unit: 'pkt'),
      ];

      final res = service.transferGroceryCart(
        householdId: 'hh_opt_out',
        retailerId: 'daraz',
        items: items,
      );
      expect(res, isNull);
    });
  });

  group('Partner Cart Direct Transfer Widget Tests', () {
    testWidgets('Renders One-Tap Cart Checkout button and executes direct handoff',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      PartnerCartTransferResult? transferredCart;
      String? launchedUrl;
      bool? isAppScheme;

      final service = RetailerHandoffService(countryCode: 'NP');
      final testItems = [
        const PartnerCartItem(
          itemId: 'item_1',
          name: 'Mustard Oil (तोरीको तेल)',
          nameNe: 'तोरीको तेल',
          quantity: 2,
          unit: 'L',
          estimatedPriceNpr: 640,
        ),
        const PartnerCartItem(
          itemId: 'item_2',
          name: 'Basmati Rice (बासमती चामल)',
          nameNe: 'बासमती चामल',
          quantity: 5,
          unit: 'kg',
          estimatedPriceNpr: 950,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_cart_sheet_btn'),
                onPressed: () {
                  RetailerHandoffSheet.show(
                    context: context,
                    retailerService: service,
                    householdId: 'hh_test_daraz_checkout',
                    cartItems: testItems,
                    basketItemNames: ['Mustard Oil', 'Basmati Rice'],
                    currentLanguage: 'ne',
                    onLaunchUrl: (url, isApp) {
                      launchedUrl = url;
                      isAppScheme = isApp;
                    },
                    onDirectCartTransfer: (result) {
                      transferredCart = result;
                    },
                  );
                },
                child: const Text('Open Cart Transfer'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.byKey(const Key('open_cart_sheet_btn')));
      await tester.pumpAndSettle();

      // 1. Verify One-Tap Cart Transfer button exists for Daraz
      final darazOneTapBtn = find.byKey(const Key('btn_direct_cart_transfer_daraz'));
      expect(darazOneTapBtn, findsOneWidget);
      expect(find.text('एक-ट्याप कार्ट अर्डर (One-Tap Cart)'), findsWidgets);

      // 2. Tap One-Tap Cart button
      await tester.ensureVisible(darazOneTapBtn);
      await tester.tap(darazOneTapBtn);
      await tester.pumpAndSettle();

      // 3. Verify transfer result was generated and callback triggered
      expect(transferredCart, isNotNull);
      expect(transferredCart!.householdId, 'hh_test_daraz_checkout');
      expect(transferredCart!.retailerId, 'daraz');
      expect(transferredCart!.totalItems, 2);
      expect(transferredCart!.transferredItemsCount, 2);
      expect(transferredCart!.estimatedSubtotalNpr, 1590);
      expect(transferredCart!.status, 'ready');

      // 4. Verify deep link URL launch
      expect(launchedUrl, isNotNull);
      expect(launchedUrl, startsWith('daraz://cart/import?token='));
      expect(isAppScheme, isTrue);
    });

    testWidgets('Supports English locale and Bhatbhateni One-Tap transfer', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      PartnerCartTransferResult? transferredCart;
      final service = RetailerHandoffService(countryCode: 'NP');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_cart_sheet_btn'),
                onPressed: () {
                  RetailerHandoffSheet.show(
                    context: context,
                    retailerService: service,
                    householdId: 'hh_test_bbsm_checkout',
                    basketItemNames: ['Potato', 'Cauliflower'],
                    currentLanguage: 'en',
                    onDirectCartTransfer: (result) {
                      transferredCart = result;
                    },
                  );
                },
                child: const Text('Open English Cart Transfer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_cart_sheet_btn')));
      await tester.pumpAndSettle();

      // Verify English title & button text
      expect(find.text('Order 2 Items Online'), findsOneWidget);
      expect(find.text('One-Tap Cart Checkout'), findsWidgets);

      // Tap Bhatbhateni One-Tap
      final bbsmOneTapBtn = find.byKey(const Key('btn_direct_cart_transfer_bhatbhateni'));
      expect(bbsmOneTapBtn, findsOneWidget);
      await tester.ensureVisible(bbsmOneTapBtn);
      await tester.tap(bbsmOneTapBtn);
      await tester.pumpAndSettle();

      expect(transferredCart, isNotNull);
      expect(transferredCart!.retailerId, 'bhatbhateni');
      expect(transferredCart!.cartAppUrl, startsWith('bbsm://cart/import?token='));
      expect(transferredCart!.transferredItemsCount, 2);
    });
  });
}
