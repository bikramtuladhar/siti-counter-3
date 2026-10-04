import { test } from 'node:test'
import assert from 'node:assert'
import { app } from '../index.js'
import { KalimatiService } from '../market/kalimati_service.js'

test('GET /v1/market/prices/daily returns Kalimati market price board', async () => {
  const res = await app.request('/v1/market/prices/daily')
  assert.strictEqual(res.status, 200)
  const data = (await res.json()) as any

  assert.strictEqual(data.market, 'Kalimati Fruit and Vegetable Market (KFVMDB)')
  assert.ok(data.totalCommodities >= 10)
  assert.ok(Array.isArray(data.prices))

  const potato = data.prices.find((p: any) => p.commodityId === 'potato')
  assert.ok(potato)
  assert.strictEqual(potato.commodityNameEn, 'Potato Red')
  assert.strictEqual(potato.commodityNameNe, 'आलु रातो')
  assert.strictEqual(potato.unit, 'kg')
  assert.ok(potato.avgPrice > 0)
  assert.ok(potato.minPrice <= potato.avgPrice)
  assert.ok(potato.maxPrice >= potato.avgPrice)
})

test('GET /v1/market/prices/daily supports category and search query filters', async () => {
  // Category filter: greens
  const resGreens = await app.request('/v1/market/prices/daily?category=greens')
  assert.strictEqual(resGreens.status, 200)
  const dataGreens = (await resGreens.json()) as any
  assert.ok(dataGreens.prices.length > 0)
  for (const item of dataGreens.prices) {
    assert.strictEqual(item.category, 'greens')
  }

  // Search filter: 'आलु' (Potato in Devanagari)
  const query = encodeURIComponent('आलु')
  const resSearch = await app.request(`/v1/market/prices/daily?search=${query}`)
  assert.strictEqual(resSearch.status, 200)
  const dataSearch = (await resSearch.json()) as any
  assert.ok(dataSearch.prices.some((p: any) => p.commodityId.startsWith('potato')))
})

test('GET /v1/market/prices/commodity/:commodityId returns details and trend', async () => {
  const res = await app.request('/v1/market/prices/commodity/tomato')
  assert.strictEqual(res.status, 200)
  const data = (await res.json()) as any
  assert.strictEqual(data.commodityId, 'tomato')
  assert.ok(data.latest)
  assert.strictEqual(data.latest.commodityNameEn, 'Tomato Local')

  // Non-existent commodity returns 404
  const resMissing = await app.request('/v1/market/prices/commodity/dragonfruit_space')
  assert.strictEqual(resMissing.status, 404)
})

test('POST /v1/market/kalimati/ingest ingests payload and calculates trends', async () => {
  const ingestPayload = {
    date: '2026-10-05',
    rawPayload: [
      {
        commodity_name: 'Potato Red',
        commodity_unit: 'kg',
        min_price: 70,
        max_price: 80,
        avg_price: 75 // Price increased from baseAvg 60 -> rising
      },
      {
        commodity_name: 'Cauliflower Local',
        commodity_unit: 'kg',
        min_price: 30,
        max_price: 40,
        avg_price: 35 // Price dropped from baseAvg 58 -> falling
      }
    ]
  }

  const res = await app.request('/v1/market/kalimati/ingest', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(ingestPayload)
  })
  assert.strictEqual(res.status, 200)
  const data = (await res.json()) as any
  assert.strictEqual(data.success, true)
  assert.strictEqual(data.ingestedCount, 2)

  const potato = data.prices.find((p: any) => p.commodityId === 'potato')
  assert.ok(potato)
  assert.strictEqual(potato.priceTrend, 'rising')

  const cauliflower = data.prices.find((p: any) => p.commodityId === 'cauliflower')
  assert.ok(cauliflower)
  assert.strictEqual(cauliflower.priceTrend, 'falling')
})

test('Crowdsourced Price Observation: record and retrieve local community prices', async () => {
  const obsPayload = {
    marketName: 'Lagankhel Haat Bazaar (लगनखेल हाट बजार)',
    marketType: 'haat_bazaar',
    commodityId: 'potato',
    observedPrice: 65,
    unit: 'kg',
    reporterHouseholdId: 'hh_lalitpur_001'
  }

  const recordRes = await app.request('/v1/market/prices/crowdsource', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(obsPayload)
  })
  assert.strictEqual(recordRes.status, 200)
  const recordData = (await recordRes.json()) as any
  assert.strictEqual(recordData.success, true)
  assert.strictEqual(recordData.observation.commodityId, 'potato')
  assert.strictEqual(recordData.observation.observedPrice, 65)

  // Retrieve crowdsourced prices for commodity
  const getRes = await app.request('/v1/market/prices/crowdsource/potato')
  assert.strictEqual(getRes.status, 200)
  const getData = (await getRes.json()) as any
  assert.strictEqual(getData.commodityId, 'potato')
  assert.ok(getData.totalObservations >= 1)
})

test('POST /v1/market/basket-cost computes estimated market cost and budget heroes', async () => {
  const basketPayload = {
    items: [
      { commodityId: 'potato', quantityGrams: 2000 }, // 2 kg
      { commodityId: 'tomato', quantityGrams: 1000 }, // 1 kg
      { commodityId: 'cauliflower', quantityGrams: 1000 } // 1 kg (falling price -> budget hero)
    ]
  }

  const res = await app.request('/v1/market/basket-cost', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(basketPayload)
  })
  assert.strictEqual(res.status, 200)
  const data = (await res.json()) as any

  assert.ok(data.totalEstimatedNpr > 0)
  assert.strictEqual(data.itemEstimates.length, 3)
  assert.ok(data.budgetHeroes.length > 0)
  assert.ok(data.totalEstimatedFormatted.startsWith('रु '))
})
