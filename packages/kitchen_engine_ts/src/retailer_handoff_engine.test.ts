import test from 'node:test';
import assert from 'node:assert/strict';
import {
  RetailerHandoffEngine,
  cleanSearchQuery,
  DEFAULT_AFFILIATE_DISCLOSURE_EN,
  DEFAULT_AFFILIATE_DISCLOSURE_NE,
} from './retailer_handoff_engine.js';

test('RetailerHandoffEngine - cleanSearchQuery normalizes ingredients', () => {
  assert.equal(cleanSearchQuery('Potato Red (Local)'), 'Potato');
  assert.equal(cleanSearchQuery('गोलभेडा सानो(लोकल)'), 'गोलभेडा सानो');
  assert.equal(cleanSearchQuery('Mustard Oil'), 'Mustard Oil');
  assert.equal(cleanSearchQuery('  cauliflower local  '), 'cauliflower');
});

test('RetailerHandoffEngine - Daraz deep-link generation with affiliate tag', () => {
  const engine = new RetailerHandoffEngine();
  const link = engine.generateItemDeepLink('daraz', 'Mustard Oil');

  assert.ok(link);
  assert.equal(link.retailerId, 'daraz');
  assert.equal(link.searchTerm, 'Mustard Oil');
  assert.ok(link.webUrl.startsWith('https://www.daraz.com.np/catalog/?q=Mustard%20Oil&tag=siticounter'));
  assert.ok(link.appDeepLinkUrl.startsWith('daraz://catalog?q=Mustard%20Oil&tag=siticounter'));
  assert.equal(link.isAffiliate, true);
  assert.equal(link.disclosureEn, DEFAULT_AFFILIATE_DISCLOSURE_EN);
  assert.equal(link.disclosureNe, DEFAULT_AFFILIATE_DISCLOSURE_NE);
});

test('RetailerHandoffEngine - Bhatbhateni deep-link generation with ref tag', () => {
  const engine = new RetailerHandoffEngine();
  const link = engine.generateItemDeepLink('bhatbhateni', 'Basmati Rice');

  assert.ok(link);
  assert.equal(link.retailerId, 'bhatbhateni');
  assert.equal(link.retailerName, 'Bhatbhateni Supermarket');
  assert.ok(link.webUrl.startsWith('https://bhatbhatenionline.com/search?q=Basmati%20Rice&ref=siticounter'));
  assert.ok(link.appDeepLinkUrl.startsWith('bbsm://search?q=Basmati%20Rice&ref=siticounter'));
  assert.equal(link.isAffiliate, true);
});

test('RetailerHandoffEngine - Devanagari query encoding', () => {
  const engine = new RetailerHandoffEngine();
  const link = engine.generateItemDeepLink('daraz', 'आलु');

  assert.ok(link);
  assert.equal(link.searchTerm, 'आलु');
  assert.ok(link.webUrl.includes(encodeURIComponent('आलु')));
  assert.ok(link.appDeepLinkUrl.includes(encodeURIComponent('आलु')));
});

test('RetailerHandoffEngine - Zero Advertising Rank Bias Guarantee', () => {
  const engine = new RetailerHandoffEngine();
  const retailers = engine.getAvailableRetailers('NP');

  // Must contain Daraz, Bhatbhateni, BigMart
  const ids = retailers.map((r) => r.id);
  assert.ok(ids.includes('daraz'));
  assert.ok(ids.includes('bhatbhateni'));
  assert.ok(ids.includes('bigmart'));

  // Strictly neutral alphabetical order: 'Bhatbhateni Supermarket', 'BigMart Online', 'Daraz'
  assert.equal(retailers[0].name, 'Bhatbhateni Supermarket');
  assert.equal(retailers[1].name, 'BigMart Online');
  assert.equal(retailers[2].name, 'Daraz');

  // Verify that setting user preference moves preferred partner to top
  engine.setPreferredRetailer('daraz');
  const preferredList = engine.getAvailableRetailers('NP');
  assert.equal(preferredList[0].id, 'daraz');
});

test('RetailerHandoffEngine - Opt-Out Privacy setting disables partner links entirely', () => {
  const engine = new RetailerHandoffEngine({ partnerLinksEnabled: false });

  assert.equal(engine.isPartnerLinksEnabled(), false);
  assert.deepEqual(engine.getAvailableRetailers('NP'), []);

  const link = engine.generateItemDeepLink('daraz', 'potato');
  assert.equal(link, null);

  const basket = engine.generateBasketHandoff('daraz', ['potato', 'tomato']);
  assert.equal(basket, null);

  // Re-enabling allows link generation again
  engine.setPartnerLinksEnabled(true);
  assert.equal(engine.isPartnerLinksEnabled(), true);
  assert.ok(engine.generateItemDeepLink('daraz', 'potato') !== null);
});

test('RetailerHandoffEngine - Basket handoff generates multi-item search query', () => {
  const engine = new RetailerHandoffEngine();
  const basket = engine.generateBasketHandoff('bhatbhateni', [
    'Potato Red',
    'Tomato (Local)',
    'Mustard Oil',
  ]);

  assert.ok(basket);
  assert.equal(basket.retailerId, 'bhatbhateni');
  assert.equal(basket.itemCount, 3);
  assert.equal(basket.combinedSearchQuery, 'Potato Tomato Mustard Oil');
  assert.ok(basket.webUrl.includes('Potato%20Tomato%20Mustard%20Oil'));
  assert.ok(basket.appDeepLinkUrl.includes('Potato%20Tomato%20Mustard%20Oil'));
});

test('RetailerHandoffEngine - Level 3 One-Tap Grocery Cart direct transfer', () => {
  const engine = new RetailerHandoffEngine();
  const fixedDate = new Date('2026-10-05T08:00:00.000Z');

  const items = [
    { itemId: 'item_1', name: 'Mustard Oil (तोरीको तेल)', quantity: 2, unit: 'L', estimatedPriceNpr: 640 },
    { itemId: 'item_2', name: 'Basmati Rice', quantity: 5, unit: 'kg', estimatedPriceNpr: 950 },
    { itemId: 'item_3', name: '', quantity: 1, unit: 'pkt' }, // empty name -> unmatched
  ];

  // Daraz Direct Transfer
  const darazResult = engine.transferGroceryCart('hh_123', 'daraz', items, {
    cartId: 'cart_test_daraz_99',
    now: fixedDate,
  });

  assert.ok(darazResult);
  assert.equal(darazResult.cartId, 'cart_test_daraz_99');
  assert.equal(darazResult.householdId, 'hh_123');
  assert.equal(darazResult.retailerId, 'daraz');
  assert.equal(darazResult.totalItems, 3);
  assert.equal(darazResult.transferredItemsCount, 2);
  assert.equal(darazResult.unmatchedItems.length, 1);
  assert.equal(darazResult.estimatedSubtotalNpr, 1590);
  assert.ok(darazResult.cartWebUrl.startsWith('https://www.daraz.com.np/cart/import?token='));
  assert.ok(darazResult.cartAppUrl.startsWith('daraz://cart/import?token='));
  assert.ok(darazResult.cartWebUrl.includes('ref=siticounter'));

  // Bhatbhateni Direct Transfer
  const bbsmResult = engine.transferGroceryCart('hh_123', 'bhatbhateni', items, { now: fixedDate });
  assert.ok(bbsmResult);
  assert.ok(bbsmResult.cartWebUrl.startsWith('https://bhatbhatenionline.com/cart/import?token='));
  assert.ok(bbsmResult.cartAppUrl.startsWith('bbsm://cart/import?token='));

  // BigMart Direct Transfer
  const bmResult = engine.transferGroceryCart('hh_123', 'bigmart', items, { now: fixedDate });
  assert.ok(bmResult);
  assert.ok(bmResult.cartWebUrl.startsWith('https://bigmart.com.np/cart/import?token='));
  assert.ok(bmResult.cartAppUrl.startsWith('bigmart://cart/import?token='));

  // Opt-out disables cart transfer
  engine.setPartnerLinksEnabled(false);
  assert.equal(engine.transferGroceryCart('hh_123', 'daraz', items), null);
});

