/**
 * Kalimati Wholesale Market Ingestion & Price Board Service
 * Daily produce price index for Kathmandu Valley (KFVMDB)
 */

export interface MarketCommodityPrice {
  id: string;
  marketCode: string;
  marketName: string;
  commodityId: string;
  commodityNameEn: string;
  commodityNameNe: string;
  category: 'vegetables' | 'greens' | 'fruit' | 'spices';
  unit: string;
  minPrice: number;
  maxPrice: number;
  avgPrice: number;
  priceTrend: 'rising' | 'stable' | 'falling';
  date: string; // YYYY-MM-DD
  nepaliDate?: string;
  updatedAt: string;
}

export interface CrowdsourcedObservation {
  id: string;
  marketName: string;
  marketType: 'haat_bazaar' | 'supermarket' | 'local_kirana' | 'wholesale';
  commodityId: string;
  observedPrice: number;
  unit: string;
  reporterHouseholdId?: string;
  verified: boolean;
  createdAt: string;
}

// In-memory store for static snapshot and historical records
export const dailyPricesStore = new Map<string, MarketCommodityPrice>()
export const historicalPricesStore = new Map<string, MarketCommodityPrice[]>() // keyed by commodityId
export const crowdsourcedStore: CrowdsourcedObservation[] = []

export const KALIMATI_CANONICAL_COMMODITIES: Array<{
  commodityId: string;
  nameEn: string;
  nameNe: string;
  category: 'vegetables' | 'greens' | 'fruit' | 'spices';
  unit: string;
  baseMin: number;
  baseMax: number;
  baseAvg: number;
}> = [
  { commodityId: 'potato', nameEn: 'Potato Red', nameNe: 'आलु रातो', category: 'vegetables', unit: 'kg', baseMin: 55, baseMax: 65, baseAvg: 60 },
  { commodityId: 'potato_white', nameEn: 'Potato White', nameNe: 'आलु सेतो', category: 'vegetables', unit: 'kg', baseMin: 45, baseMax: 52, baseAvg: 48 },
  { commodityId: 'tomato_big', nameEn: 'Tomato Big', nameNe: 'गोलभेडा ठूलो', category: 'vegetables', unit: 'kg', baseMin: 70, baseMax: 80, baseAvg: 75 },
  { commodityId: 'tomato', nameEn: 'Tomato Local', nameNe: 'गोलभेडा सानो(लोकल)', category: 'vegetables', unit: 'kg', baseMin: 40, baseMax: 50, baseAvg: 45 },
  { commodityId: 'onion', nameEn: 'Onion Dry', nameNe: 'प्याज सुकेको', category: 'vegetables', unit: 'kg', baseMin: 78, baseMax: 88, baseAvg: 83 },
  { commodityId: 'cauliflower', nameEn: 'Cauliflower Local', nameNe: 'काउली स्थानीय', category: 'vegetables', unit: 'kg', baseMin: 50, baseMax: 65, baseAvg: 58 },
  { commodityId: 'cabbage', nameEn: 'Cabbage Local', nameNe: 'बन्दा(लोकल)', category: 'vegetables', unit: 'kg', baseMin: 35, baseMax: 45, baseAvg: 40 },
  { commodityId: 'spinach', nameEn: 'Spinach Greens', nameNe: 'पालुङ्गो साग', category: 'greens', unit: 'kg', baseMin: 80, baseMax: 100, baseAvg: 90 },
  { commodityId: 'mustard_greens', nameEn: 'Mustard Greens (Rayo)', nameNe: 'रायो साग', category: 'greens', unit: 'kg', baseMin: 45, baseMax: 55, baseAvg: 50 },
  { commodityId: 'ginger', nameEn: 'Ginger', nameNe: 'अदुवा', category: 'spices', unit: 'kg', baseMin: 160, baseMax: 190, baseAvg: 175 },
  { commodityId: 'garlic', nameEn: 'Garlic Dry', nameNe: 'लसुन सुकेको', category: 'spices', unit: 'kg', baseMin: 240, baseMax: 270, baseAvg: 255 },
  { commodityId: 'cilantro', nameEn: 'Coriander Green', nameNe: 'धनिया हरियो', category: 'greens', unit: 'kg', baseMin: 100, baseMax: 130, baseAvg: 115 },
  { commodityId: 'chilli_green', nameEn: 'Green Chilli', nameNe: 'खुर्सानी हरियो', category: 'spices', unit: 'kg', baseMin: 85, baseMax: 105, baseAvg: 95 },
  { commodityId: 'eggplant', nameEn: 'Eggplant (Brinjal)', nameNe: 'भन्टा लाम्चो', category: 'vegetables', unit: 'kg', baseMin: 50, baseMax: 60, baseAvg: 55 },
  { commodityId: 'radish', nameEn: 'White Radish', nameNe: 'मूला सेतो(लोकल)', category: 'vegetables', unit: 'kg', baseMin: 30, baseMax: 40, baseAvg: 35 },
  { commodityId: 'okra', nameEn: 'Okra (Bhindi)', nameNe: 'भिण्डी', category: 'vegetables', unit: 'kg', baseMin: 65, baseMax: 75, baseAvg: 70 },
  { commodityId: 'bitter_gourd', nameEn: 'Bitter Gourd', nameNe: 'तितो करेला', category: 'vegetables', unit: 'kg', baseMin: 60, baseMax: 70, baseAvg: 65 },
  { commodityId: 'apple', nameEn: 'Apple', nameNe: 'स्याउ(झोले)', category: 'fruit', unit: 'kg', baseMin: 200, baseMax: 240, baseAvg: 220 },
  { commodityId: 'banana', nameEn: 'Banana', nameNe: 'केरा', category: 'fruit', unit: 'dozen', baseMin: 120, baseMax: 140, baseAvg: 130 },
  { commodityId: 'lemon', nameEn: 'Lemon', nameNe: 'कागति', category: 'fruit', unit: 'kg', baseMin: 150, baseMax: 170, baseAvg: 160 },
]

export class KalimatiService {
  /**
   * Ingest daily price table from Kalimati wholesale market
   */
  public static async ingestDailyPrices(params?: {
    date?: string;
    rawPayload?: Array<{
      commodity_name: string;
      commodity_unit: string;
      min_price: number;
      max_price: number;
      avg_price: number;
    }>;
  }): Promise<{ ingestedCount: number; date: string; prices: MarketCommodityPrice[] }> {
    const today = params?.date || new Date().toISOString().split('T')[0]
    const results: MarketCommodityPrice[] = []

    if (params?.rawPayload && params.rawPayload.length > 0) {
      // Ingest from external scraper/webhook payload
      for (const item of params.rawPayload) {
        const canonical = KalimatiService.matchCanonical(item.commodity_name)
        const commodityId = canonical ? canonical.commodityId : item.commodity_name.toLowerCase().replace(/[^a-z0-9]/g, '_')
        const nameEn = canonical ? canonical.nameEn : item.commodity_name
        const nameNe = canonical ? canonical.nameNe : item.commodity_name
        const category = canonical ? canonical.category : 'vegetables'
        const unit = item.commodity_unit || 'kg'

        const prevPrice = KalimatiService.getLatestPrice(commodityId)
        const prevAvg = prevPrice?.avgPrice ?? canonical?.baseAvg
        const trend = KalimatiService.calculateTrend(item.avg_price, prevAvg)

        const record: MarketCommodityPrice = {
          id: `kalimati_${today}_${commodityId}`,
          marketCode: 'kalimati',
          marketName: 'Kalimati Wholesale Market',
          commodityId,
          commodityNameEn: nameEn,
          commodityNameNe: nameNe,
          category,
          unit,
          minPrice: Math.round(item.min_price),
          maxPrice: Math.round(item.max_price),
          avgPrice: Math.round(item.avg_price),
          priceTrend: trend,
          date: today,
          updatedAt: new Date().toISOString()
        }

        dailyPricesStore.set(record.id, record)
        dailyPricesStore.set(`latest_${commodityId}`, record)

        const hist = historicalPricesStore.get(commodityId) || []
        hist.push(record)
        historicalPricesStore.set(commodityId, hist)

        results.push(record)
      }
    } else {
      // Generate / Ingest canonical daily snapshot
      for (const c of KALIMATI_CANONICAL_COMMODITIES) {
        const prevPrice = KalimatiService.getLatestPrice(c.commodityId)
        const trend = prevPrice ? KalimatiService.calculateTrend(c.baseAvg, prevPrice.avgPrice) : 'stable'

        const record: MarketCommodityPrice = {
          id: `kalimati_${today}_${c.commodityId}`,
          marketCode: 'kalimati',
          marketName: 'Kalimati Wholesale Market',
          commodityId: c.commodityId,
          commodityNameEn: c.nameEn,
          commodityNameNe: c.nameNe,
          category: c.category,
          unit: c.unit,
          minPrice: c.baseMin,
          maxPrice: c.baseMax,
          avgPrice: c.baseAvg,
          priceTrend: trend,
          date: today,
          updatedAt: new Date().toISOString()
        }

        dailyPricesStore.set(record.id, record)
        dailyPricesStore.set(`latest_${c.commodityId}`, record)

        const hist = historicalPricesStore.get(c.commodityId) || []
        hist.push(record)
        historicalPricesStore.set(c.commodityId, hist)

        results.push(record)
      }
    }

    return {
      ingestedCount: results.length,
      date: today,
      prices: results
    }
  }

  public static getDailyPrices(options?: {
    date?: string;
    category?: string;
    search?: string;
  }): MarketCommodityPrice[] {
    const targetDate = options?.date || new Date().toISOString().split('T')[0]
    let all = Array.from(dailyPricesStore.values()).filter((p) => p.date === targetDate)

    // Fallback to latest records if date query returns empty
    if (all.length === 0) {
      all = KALIMATI_CANONICAL_COMMODITIES.map((c) => {
        const latest = dailyPricesStore.get(`latest_${c.commodityId}`)
        if (latest) return latest
        const record = {
          id: `kalimati_${targetDate}_${c.commodityId}`,
          marketCode: 'kalimati',
          marketName: 'Kalimati Wholesale Market',
          commodityId: c.commodityId,
          commodityNameEn: c.nameEn,
          commodityNameNe: c.nameNe,
          category: c.category,
          unit: c.unit,
          minPrice: c.baseMin,
          maxPrice: c.baseMax,
          avgPrice: c.baseAvg,
          priceTrend: 'stable',
          date: targetDate,
          updatedAt: new Date().toISOString()
        } as MarketCommodityPrice
        dailyPricesStore.set(`latest_${c.commodityId}`, record)
        return record
      })
    }

    if (options?.category) {
      const cat = options.category.toLowerCase()
      all = all.filter((p) => p.category === cat)
    }

    if (options?.search) {
      const q = options.search.toLowerCase()
      all = all.filter(
        (p) =>
          p.commodityNameEn.toLowerCase().includes(q) ||
          p.commodityNameNe.includes(q) ||
          p.commodityId.includes(q)
      )
    }

    return all
  }

  public static getCommodityHistory(commodityId: string): MarketCommodityPrice[] {
    return historicalPricesStore.get(commodityId) || []
  }

  public static getLatestPrice(commodityId: string): MarketCommodityPrice | undefined {
    return dailyPricesStore.get(`latest_${commodityId}`)
  }

  public static recordCrowdsourcedObservation(params: {
    marketName: string;
    marketType: 'haat_bazaar' | 'supermarket' | 'local_kirana' | 'wholesale';
    commodityId: string;
    observedPrice: number;
    unit?: string;
    reporterHouseholdId?: string;
  }): CrowdsourcedObservation {
    const obs: CrowdsourcedObservation = {
      id: `cobs_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      marketName: params.marketName,
      marketType: params.marketType,
      commodityId: params.commodityId,
      observedPrice: params.observedPrice,
      unit: params.unit || 'kg',
      reporterHouseholdId: params.reporterHouseholdId,
      verified: true,
      createdAt: new Date().toISOString()
    }
    crowdsourcedStore.push(obs)
    return obs
  }

  public static getCrowdsourcedForCommodity(commodityId: string): CrowdsourcedObservation[] {
    return crowdsourcedStore.filter((o) => o.commodityId === commodityId)
  }

  private static calculateTrend(current: number, previous?: number): 'rising' | 'stable' | 'falling' {
    if (!previous || previous <= 0) return 'stable'
    const pctChange = (current - previous) / previous
    if (pctChange > 0.05) return 'rising'
    if (pctChange < -0.05) return 'falling'
    return 'stable'
  }

  private static matchCanonical(rawName: string) {
    const lower = rawName.toLowerCase()
    for (const c of KALIMATI_CANONICAL_COMMODITIES) {
      if (
        lower.includes(c.nameEn.toLowerCase()) ||
        rawName.includes(c.nameNe) ||
        lower.includes(c.commodityId)
      ) {
        return c
      }
    }
    return undefined
  }
}
