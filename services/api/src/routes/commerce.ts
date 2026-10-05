import { Hono } from 'hono'

export const commerceRouter = new Hono()

export interface TransferCartItem {
  itemId: string;
  name: string;
  nameNe?: string;
  quantity: number;
  unit: string;
  estimatedPriceNpr?: number;
}

export interface PartnerCartSession {
  cartId: string;
  householdId: string;
  retailerId: string;
  retailerName: string;
  status: 'ready' | 'expired' | 'completed';
  totalItems: number;
  transferredItemsCount: number;
  unmatchedItems: Array<{ itemId: string; name: string }>;
  estimatedSubtotalNpr: number;
  cartWebUrl: string;
  cartAppUrl: string;
  createdAt: string;
  expiresAt: string;
  disclosureEn: string;
  disclosureNe: string;
}

// In-memory partner cart store for active sessions
const activeCartSessions = new Map<string, PartnerCartSession>()

const SUPPORTED_DIRECT_PARTNERS: Record<string, {
  name: string;
  nameNe: string;
  countryCode: string;
  webBase: string;
  appBase: string;
  affiliateTag: string;
}> = {
  daraz: {
    name: 'Daraz',
    nameNe: 'दराज',
    countryCode: 'NP',
    webBase: 'https://www.daraz.com.np/cart/import',
    appBase: 'daraz://cart/import',
    affiliateTag: 'siticounter',
  },
  bhatbhateni: {
    name: 'Bhatbhateni Supermarket',
    nameNe: 'भातभटेनी सुपरमार्केट',
    countryCode: 'NP',
    webBase: 'https://bhatbhatenionline.com/cart/import',
    appBase: 'bbsm://cart/import',
    affiliateTag: 'siticounter',
  },
  bigmart: {
    name: 'BigMart Online',
    nameNe: 'बिग मार्ट',
    countryCode: 'NP',
    webBase: 'https://bigmart.com.np/cart/import',
    appBase: 'bigmart://cart/import',
    affiliateTag: '',
  },
  blinkit: {
    name: 'Blinkit',
    nameNe: 'ब्लिङ्किट',
    countryCode: 'IN',
    webBase: 'https://blinkit.com/cart/import',
    appBase: 'blinkit://cart/import',
    affiliateTag: 'siticounter',
  },
  amazon_fresh: {
    name: 'Amazon Fresh',
    nameNe: 'अमेजन फ्रेस',
    countryCode: 'US',
    webBase: 'https://www.amazon.com/fresh/cart/import',
    appBase: 'amazon://fresh/cart/import',
    affiliateTag: 'siticounter-20',
  },
}

// 1. Direct Partner Cart Transfer (Section 26.4 - Level 3 One-Tap Checkout)
commerceRouter.post('/v1/commerce/cart/transfer', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    householdId?: string;
    retailerId?: string;
    items?: TransferCartItem[];
    userNote?: string;
  }

  if (!body.householdId) {
    return c.json({ error: 'BAD_REQUEST', message: 'householdId is required' }, 400)
  }
  if (!body.retailerId) {
    return c.json({ error: 'BAD_REQUEST', message: 'retailerId is required' }, 400)
  }
  if (!Array.isArray(body.items) || body.items.length === 0) {
    return c.json({ error: 'BAD_REQUEST', message: 'items array must contain at least one item' }, 400)
  }

  const partner = SUPPORTED_DIRECT_PARTNERS[body.retailerId.toLowerCase()]
  if (!partner) {
    return c.json({
      error: 'UNSUPPORTED_RETAILER',
      message: `Retailer '${body.retailerId}' does not support Level 3 direct cart transfers. Use Level 1/2 search links.`,
    }, 422)
  }

  const cartId = `cart_${crypto.randomUUID()}`
  const now = new Date()
  const expiresAt = new Date(now.getTime() + 2 * 60 * 60 * 1000) // 2 hours validity

  let totalNpr = 0
  const unmatched: Array<{ itemId: string; name: string }> = []
  let transferredCount = 0

  for (const item of body.items) {
    if (!item.name || item.name.trim().length === 0) {
      unmatched.push({ itemId: item.itemId, name: item.name || 'Unknown item' })
      continue
    }

    const price = item.estimatedPriceNpr ?? (item.quantity * 80) // fallback ~Rs 80/unit
    totalNpr += price
    transferredCount++
  }

  const tokenPayload = Buffer.from(
    JSON.stringify({
      cartId,
      householdId: body.householdId,
      retailerId: body.retailerId,
      itemCount: transferredCount,
      timestamp: now.toISOString(),
      tag: partner.affiliateTag,
    })
  ).toString('base64url')

  const queryParams = new URLSearchParams({
    token: tokenPayload,
    ref: partner.affiliateTag || 'siticounter',
    items: String(transferredCount),
  })

  const cartWebUrl = `${partner.webBase}?${queryParams.toString()}`
  const cartAppUrl = `${partner.appBase}?${queryParams.toString()}`

  const session: PartnerCartSession = {
    cartId,
    householdId: body.householdId,
    retailerId: body.retailerId,
    retailerName: partner.name,
    status: 'ready',
    totalItems: body.items.length,
    transferredItemsCount: transferredCount,
    unmatchedItems: unmatched,
    estimatedSubtotalNpr: totalNpr,
    cartWebUrl,
    cartAppUrl,
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    disclosureEn:
      'Affiliate Disclosure: Siti Counter may earn a commission from purchases made via partner cart handoff at no extra cost to you. Shopping partners are integrated without advertising rank bias.',
    disclosureNe:
      'सहयोगी लिङ्क प्रकटीकरण: सिट्ठी काउन्टरले तपाईंलाई कुनै अतिरिक्त शुल्क बिना पार्टनर कार्टबाट कमिसन प्राप्त गर्न सक्छ। व्यापारीहरूको सूची विज्ञापन वा भुक्तानी पूर्वाग्रह बिना निष्पक्ष राखिएको छ।',
  }

  activeCartSessions.set(cartId, session)

  return c.json(session, 201)
})

// 2. Get Cart Transfer Status
commerceRouter.get('/v1/commerce/cart/:cartId/status', (c) => {
  const cartId = c.req.param('cartId')
  const session = activeCartSessions.get(cartId)

  if (!session) {
    return c.json({ error: 'NOT_FOUND', message: `Cart session '${cartId}' not found or expired.` }, 404)
  }

  return c.json(session)
})

// 3. Supported Direct Cart Partners Directory
commerceRouter.get('/v1/commerce/partners', (c) => {
  const country = (c.req.query('country') || 'NP').toUpperCase()
  const partners = Object.entries(SUPPORTED_DIRECT_PARTNERS)
    .filter(([_, p]) => p.countryCode === country)
    .map(([id, p]) => ({
      id,
      name: p.name,
      nameNe: p.nameNe,
      countryCode: p.countryCode,
      tier: 'level3_direct_cart',
      features: ['one_tap_transfer', 'sku_matching', 'in_app_cart_import'],
    }))

  return c.json({
    country,
    totalPartners: partners.length,
    partners,
  })
})
