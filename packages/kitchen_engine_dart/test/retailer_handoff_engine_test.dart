import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('RetailerHandoffEngine Dart Parity Tests', () {
    test('cleanSearchQuery normalizes queries and removes parentheticals', () {
      expect(cleanSearchQuery('Potato Red (Local)'), 'Potato');
      expect(cleanSearchQuery('गोलभेडा सानो(लोकल)'), 'गोलभेडा सानो');
      expect(cleanSearchQuery('Mustard Oil'), 'Mustard Oil');
      expect(cleanSearchQuery('  cauliflower local  '), 'cauliflower');
    });

    test('Daraz deep-link generation with affiliate tag and scheme', () {
      final engine = RetailerHandoffEngine();
      final link = engine.generateItemDeepLink('daraz', 'Mustard Oil');

      expect(link, isNotNull);
      expect(link!.retailerId, 'daraz');
      expect(link.searchTerm, 'Mustard Oil');
      expect(link.webUrl, startsWith('https://www.daraz.com.np/catalog/?q=Mustard%20Oil&tag=siticounter'));
      expect(link.appDeepLinkUrl, startsWith('daraz://catalog?q=Mustard%20Oil&tag=siticounter'));
      expect(link.isAffiliate, isTrue);
      expect(link.disclosureEn, defaultAffiliateDisclosureEn);
      expect(link.disclosureNe, defaultAffiliateDisclosureNe);
    });

    test('Bhatbhateni deep-link generation with ref tag and scheme', () {
      final engine = RetailerHandoffEngine();
      final link = engine.generateItemDeepLink('bhatbhateni', 'Basmati Rice');

      expect(link, isNotNull);
      expect(link!.retailerId, 'bhatbhateni');
      expect(link.retailerName, 'Bhatbhateni Supermarket');
      expect(link.webUrl, startsWith('https://bhatbhatenionline.com/search?q=Basmati%20Rice&ref=siticounter'));
      expect(link.appDeepLinkUrl, startsWith('bbsm://search?q=Basmati%20Rice&ref=siticounter'));
      expect(link.isAffiliate, isTrue);
    });

    test('Devanagari query encoding in URLs', () {
      final engine = RetailerHandoffEngine();
      final link = engine.generateItemDeepLink('daraz', 'आलु');

      expect(link, isNotNull);
      expect(link!.searchTerm, 'आलु');
      expect(link.webUrl, contains(Uri.encodeComponent('आलु')));
      expect(link.appDeepLinkUrl, contains(Uri.encodeComponent('आलु')));
    });

    test('Zero Advertising Rank Bias Guarantee', () {
      final engine = RetailerHandoffEngine();
      final retailers = engine.getAvailableRetailers('NP');

      final ids = retailers.map((r) => r.id).toList();
      expect(ids, contains('daraz'));
      expect(ids, contains('bhatbhateni'));
      expect(ids, contains('bigmart'));

      // Strictly neutral alphabetical order: 'Bhatbhateni Supermarket', 'BigMart Online', 'Daraz'
      expect(retailers[0].name, 'Bhatbhateni Supermarket');
      expect(retailers[1].name, 'BigMart Online');
      expect(retailers[2].name, 'Daraz');

      // User preference moves preferred partner to top
      engine.setPreferredRetailer('daraz');
      final preferred = engine.getAvailableRetailers('NP');
      expect(preferred.first.id, 'daraz');
    });

    test('Opt-Out Privacy setting disables partner links entirely', () {
      final engine = RetailerHandoffEngine(partnerLinksEnabled: false);

      expect(engine.isPartnerLinksEnabled, isFalse);
      expect(engine.getAvailableRetailers('NP'), isEmpty);

      final link = engine.generateItemDeepLink('daraz', 'potato');
      expect(link, isNull);

      final basket = engine.generateBasketHandoff('daraz', ['potato', 'tomato']);
      expect(basket, isNull);

      // Re-enabling restores access
      engine.setPartnerLinksEnabled(true);
      expect(engine.isPartnerLinksEnabled, isTrue);
      expect(engine.generateItemDeepLink('daraz', 'potato'), isNotNull);
    });

    test('Basket handoff generates combined multi-item search query', () {
      final engine = RetailerHandoffEngine();
      final basket = engine.generateBasketHandoff('bhatbhateni', [
        'Potato Red',
        'Tomato (Local)',
        'Mustard Oil',
      ]);

      expect(basket, isNotNull);
      expect(basket!.retailerId, 'bhatbhateni');
      expect(basket.itemCount, 3);
      expect(basket.combinedSearchQuery, 'Potato Tomato Mustard Oil');
      expect(basket.webUrl, contains('Potato%20Tomato%20Mustard%20Oil'));
      expect(basket.appDeepLinkUrl, contains('Potato%20Tomato%20Mustard%20Oil'));
    });

    test('Level 3 One-Tap Grocery Cart direct transfer', () {
      final engine = RetailerHandoffEngine();
      final fixedDate = DateTime.utc(2026, 10, 5, 8, 0, 0);

      final items = [
        const PartnerCartItem(itemId: 'item_1', name: 'Mustard Oil (तोरीको तेल)', quantity: 2, unit: 'L', estimatedPriceNpr: 640),
        const PartnerCartItem(itemId: 'item_2', name: 'Basmati Rice', quantity: 5, unit: 'kg', estimatedPriceNpr: 950),
        const PartnerCartItem(itemId: 'item_3', name: '', quantity: 1, unit: 'pkt'), // empty name -> unmatched
      ];

      // Daraz Direct Transfer
      final darazResult = engine.transferGroceryCart('hh_123', 'daraz', items,
          cartId: 'cart_test_daraz_99', now: fixedDate);

      expect(darazResult, isNotNull);
      expect(darazResult!.cartId, 'cart_test_daraz_99');
      expect(darazResult.householdId, 'hh_123');
      expect(darazResult.retailerId, 'daraz');
      expect(darazResult.totalItems, 3);
      expect(darazResult.transferredItemsCount, 2);
      expect(darazResult.unmatchedItems.length, 1);
      expect(darazResult.estimatedSubtotalNpr, 1590);
      expect(darazResult.cartWebUrl, startsWith('https://www.daraz.com.np/cart/import?token='));
      expect(darazResult.cartAppUrl, startsWith('daraz://cart/import?token='));
      expect(darazResult.cartWebUrl, contains('ref=siticounter'));

      // Bhatbhateni Direct Transfer
      final bbsmResult = engine.transferGroceryCart('hh_123', 'bhatbhateni', items, now: fixedDate);
      expect(bbsmResult, isNotNull);
      expect(bbsmResult!.cartWebUrl, startsWith('https://bhatbhatenionline.com/cart/import?token='));
      expect(bbsmResult.cartAppUrl, startsWith('bbsm://cart/import?token='));

      // BigMart Direct Transfer
      final bmResult = engine.transferGroceryCart('hh_123', 'bigmart', items, now: fixedDate);
      expect(bmResult, isNotNull);
      expect(bmResult!.cartWebUrl, startsWith('https://bigmart.com.np/cart/import?token='));
      expect(bmResult.cartAppUrl, startsWith('bigmart://cart/import?token='));

      // Opt-out disables cart transfer
      engine.setPartnerLinksEnabled(false);
      expect(engine.transferGroceryCart('hh_123', 'daraz', items), isNull);
    });
  });
}
