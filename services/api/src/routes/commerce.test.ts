import { test } from 'node:test'
import assert from 'node:assert'
import { app } from '../index.js'

test('POST /v1/commerce/cart/transfer - successfully transfers grocery items to supported partner', async () => {
  const payload = {
    householdId: 'hh_test_ktm_01',
    retailerId: 'daraz',
    items: [
      { itemId: 'item_1', name: 'Mustard Oil (तोरीको तेल)', quantity: 1, unit: 'L', estimatedPriceNpr: 320 },
      { itemId: 'item_2', name: 'Basmati Rice (बासमती चामल)', quantity: 5, unit: 'kg', estimatedPriceNpr: 950 },
      { itemId: 'item_3', name: 'Turmeric Powder (बेसार)', quantity: 200, unit: 'g', estimatedPriceNpr: 120 },
    ],
  }

  const res = await app.request('/v1/commerce/cart/transfer', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })

  assert.strictEqual(res.status, 201)
  const data = (await res.json()) as any

  assert.ok(data.cartId)
  assert.strictEqual(data.householdId, 'hh_test_ktm_01')
  assert.strictEqual(data.retailerId, 'daraz')
  assert.strictEqual(data.retailerName, 'Daraz')
  assert.strictEqual(data.status, 'ready')
  assert.strictEqual(data.totalItems, 3)
  assert.strictEqual(data.transferredItemsCount, 3)
  assert.strictEqual(data.estimatedSubtotalNpr, 1390)
  assert.ok(data.cartWebUrl.startsWith('https://www.daraz.com.np/cart/import?token='))
  assert.ok(data.cartAppUrl.startsWith('daraz://cart/import?token='))
  assert.ok(data.disclosureEn.includes('Affiliate Disclosure'))
  assert.ok(data.disclosureNe.includes('सहयोगी लिङ्क प्रकटीकरण'))

  // Verify status retrieval
  const statusRes = await app.request(`/v1/commerce/cart/${data.cartId}/status`)
  assert.strictEqual(statusRes.status, 200)
  const statusData = (await statusRes.json()) as any
  assert.strictEqual(statusData.cartId, data.cartId)
  assert.strictEqual(statusData.status, 'ready')
})

test('POST /v1/commerce/cart/transfer - validation errors', async () => {
  // Missing householdId
  const resNoHousehold = await app.request('/v1/commerce/cart/transfer', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ retailerId: 'daraz', items: [{ itemId: '1', name: 'Salt', quantity: 1, unit: 'pkt' }] }),
  })
  assert.strictEqual(resNoHousehold.status, 400)

  // Missing retailerId
  const resNoRetailer = await app.request('/v1/commerce/cart/transfer', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ householdId: 'hh1', items: [{ itemId: '1', name: 'Salt', quantity: 1, unit: 'pkt' }] }),
  })
  assert.strictEqual(resNoRetailer.status, 400)

  // Empty items
  const resEmptyItems = await app.request('/v1/commerce/cart/transfer', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ householdId: 'hh1', retailerId: 'daraz', items: [] }),
  })
  assert.strictEqual(resEmptyItems.status, 400)

  // Unsupported retailer
  const resUnsupported = await app.request('/v1/commerce/cart/transfer', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      householdId: 'hh1',
      retailerId: 'local_kirana_unknown',
      items: [{ itemId: '1', name: 'Salt', quantity: 1, unit: 'pkt' }],
    }),
  })
  assert.strictEqual(resUnsupported.status, 422)
})

test('GET /v1/commerce/cart/:cartId/status - not found returns 404', async () => {
  const res = await app.request('/v1/commerce/cart/non_existent_cart_id/status')
  assert.strictEqual(res.status, 404)
})

test('GET /v1/commerce/partners - lists supported direct cart partners', async () => {
  // Nepal
  const resNp = await app.request('/v1/commerce/partners?country=NP')
  assert.strictEqual(resNp.status, 200)
  const dataNp = (await resNp.json()) as any
  assert.strictEqual(dataNp.country, 'NP')
  assert.ok(dataNp.totalPartners >= 3)
  const idsNp = dataNp.partners.map((p: any) => p.id)
  assert.ok(idsNp.includes('daraz'))
  assert.ok(idsNp.includes('bhatbhateni'))
  assert.ok(idsNp.includes('bigmart'))

  // India
  const resIn = await app.request('/v1/commerce/partners?country=IN')
  assert.strictEqual(resIn.status, 200)
  const dataIn = (await resIn.json()) as any
  assert.strictEqual(dataIn.country, 'IN')
  const idsIn = dataIn.partners.map((p: any) => p.id)
  assert.ok(idsIn.includes('blinkit'))

  // US
  const resUs = await app.request('/v1/commerce/partners?country=US')
  assert.strictEqual(resUs.status, 200)
  const dataUs = (await resUs.json()) as any
  assert.strictEqual(dataUs.country, 'US')
  const idsUs = dataUs.partners.map((p: any) => p.id)
  assert.ok(idsUs.includes('amazon_fresh'))
})
