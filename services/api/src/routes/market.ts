import { Hono } from 'hono'
import { KalimatiService } from '../market/kalimati_service.js'

export const marketRouter = new Hono()

// 1. Get Daily Market Price Board
marketRouter.get('/v1/market/prices/daily', (c) => {
  const date = c.req.query('date')
  const category = c.req.query('category')
  const search = c.req.query('search')

  const prices = KalimatiService.getDailyPrices({ date, category, search })

  return c.json({
    market: 'Kalimati Fruit and Vegetable Market (KFVMDB)',
    marketNe: 'कालीमाटी फलफूल तथा तरकारी बजार विकास समिति',
    date: date || new Date().toISOString().split('T')[0],
    totalCommodities: prices.length,
    prices,
  })
})

// 2. Get Commodity Price History & Trend
marketRouter.get('/v1/market/prices/commodity/:commodityId', (c) => {
  const commodityId = c.req.param('commodityId')
  const latest = KalimatiService.getLatestPrice(commodityId)
  const history = KalimatiService.getCommodityHistory(commodityId)
  const crowdsourced = KalimatiService.getCrowdsourcedForCommodity(commodityId)

  if (!latest && history.length === 0) {
    // Check if it exists in daily prices
    const daily = KalimatiService.getDailyPrices().find((p) => p.commodityId === commodityId)
    if (!daily) {
      return c.json({ error: 'NOT_FOUND', message: `Commodity '${commodityId}' not found` }, 404)
    }
    return c.json({
      commodityId,
      latest: daily,
      history: [daily],
      crowdsourced,
    })
  }

  return c.json({
    commodityId,
    latest: latest || history[history.length - 1],
    history,
    crowdsourced,
  })
})

// 3. Ingest Kalimati Wholesale Market Prices (Cron / Manual trigger)
marketRouter.post('/v1/market/kalimati/ingest', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    date?: string;
    rawPayload?: Array<{
      commodity_name: string;
      commodity_unit: string;
      min_price: number;
      max_price: number;
      avg_price: number;
    }>;
  }

  const result = await KalimatiService.ingestDailyPrices(body)

  return c.json({
    success: true,
    message: `Ingested ${result.ingestedCount} commodity prices for ${result.date}`,
    ingestedCount: result.ingestedCount,
    date: result.date,
    prices: result.prices,
  })
})

// 4. Record Crowdsourced Price Observation
marketRouter.post('/v1/market/prices/crowdsource', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    marketName?: string;
    marketType?: 'haat_bazaar' | 'supermarket' | 'local_kirana' | 'wholesale';
    commodityId?: string;
    observedPrice?: number;
    unit?: string;
    reporterHouseholdId?: string;
  }

  if (!body.marketName || !body.commodityId || typeof body.observedPrice !== 'number') {
    return c.json(
      {
        error: 'BAD_REQUEST',
        message: 'marketName, commodityId, and numeric observedPrice are required',
      },
      400
    )
  }

  const obs = KalimatiService.recordCrowdsourcedObservation({
    marketName: body.marketName,
    marketType: body.marketType || 'haat_bazaar',
    commodityId: body.commodityId,
    observedPrice: body.observedPrice,
    unit: body.unit,
    reporterHouseholdId: body.reporterHouseholdId,
  })

  return c.json({
    success: true,
    observation: obs,
  })
})

// 5. Get Crowdsourced Price Observations for Commodity
marketRouter.get('/v1/market/prices/crowdsource/:commodityId', (c) => {
  const commodityId = c.req.param('commodityId')
  const observations = KalimatiService.getCrowdsourcedForCommodity(commodityId)

  return c.json({
    commodityId,
    totalObservations: observations.length,
    observations,
  })
})

// 6. Calculate Estimated Market Basket Cost for Grocery List
marketRouter.post('/v1/market/basket-cost', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    items?: Array<{
      commodityId: string;
      quantityGrams?: number;
      quantityUnits?: number;
      unit?: string;
    }>;
  }

  if (!body.items || !Array.isArray(body.items)) {
    return c.json({ error: 'BAD_REQUEST', message: 'items array is required' }, 400)
  }

  let totalEstimatedNpr = 0
  const itemEstimates: Array<{
    commodityId: string;
    nameEn: string;
    nameNe: string;
    quantityGrams?: number;
    estimatedCostNpr: number;
    pricePerKgNpr: number;
    priceTrend: 'rising' | 'stable' | 'falling';
    isBudgetHero: boolean;
  }> = []

  const budgetHeroes: string[] = []

  for (const it of body.items) {
    const priceInfo = KalimatiService.getDailyPrices().find((p) => p.commodityId === it.commodityId)
    const avgPricePerKg = priceInfo?.avgPrice ?? 60
    const grams = it.quantityGrams ?? (it.quantityUnits ? it.quantityUnits * 1000 : 500)
    const cost = Math.round((grams / 1000.0) * avgPricePerKg)

    totalEstimatedNpr += cost
    const isBudgetHero = priceInfo?.priceTrend === 'falling' || avgPricePerKg < 50

    if (isBudgetHero) {
      budgetHeroes.push(priceInfo?.commodityNameEn || it.commodityId)
    }

    itemEstimates.push({
      commodityId: it.commodityId,
      nameEn: priceInfo?.commodityNameEn || it.commodityId,
      nameNe: priceInfo?.commodityNameNe || it.commodityId,
      quantityGrams: grams,
      estimatedCostNpr: cost,
      pricePerKgNpr: avgPricePerKg,
      priceTrend: priceInfo?.priceTrend || 'stable',
      isBudgetHero,
    })
  }

  return c.json({
    totalEstimatedNpr,
    totalEstimatedFormatted: `रु ${totalEstimatedNpr}`,
    itemEstimates,
    budgetHeroes,
  })
})
