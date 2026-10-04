import { Hono } from 'hono'
import { createHmac, randomBytes } from 'node:crypto'
import {
  PppPricingResolver,
  PPP_PRICING_CATALOG,
  FREE_TIER_FEATURES,
  PREMIUM_FEATURES,
  OfflineEntitlementSigner,
  SignedOfflineEntitlement
} from '@siti-counter/kitchen-engine'

export interface StoredSubscription {
  id: string;
  householdId: string;
  tier: 'free' | 'householdAnnual';
  status: 'active' | 'past_due' | 'cancelled' | 'expired';
  provider: 'khalti' | 'esewa' | 'stripe' | 'in_app' | 'gift';
  transactionId?: string;
  currency: string;
  amount: number;
  isGift: boolean;
  purchaserEmail?: string;
  recipientEmail?: string;
  recipientName?: string;
  giftMessage?: string;
  giftCode?: string;
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface StoredGiftCode {
  code: string;
  purchaserHouseholdId?: string;
  purchaserEmail?: string;
  recipientEmail?: string;
  recipientName?: string;
  giftMessage?: string;
  subscriptionId: string;
  status: 'unredeemed' | 'redeemed' | 'expired';
  redeemedByHouseholdId?: string;
  redeemedAt?: Date;
  createdAt: Date;
  expiresAt: Date;
}

export interface StoredEntitlement {
  id: string;
  householdId: string;
  tier: 'free' | 'householdAnnual';
  status: 'active' | 'expired';
  features: string[];
  offlineToken: Record<string, unknown>;
  signature: string;
  expiresAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

// In-memory backing stores for local tests / D1 fallback
export const subscriptionsStore = new Map<string, StoredSubscription>()
export const giftCodesStore = new Map<string, StoredGiftCode>()
export const entitlementsStore = new Map<string, StoredEntitlement>()
export const pendingOrdersStore = new Map<string, Record<string, any>>()

export const checkoutRouter = new Hono()

// Helper: generate gift code formatted like GIFT-SITI-ABCD-1234
function generateGiftCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  const part1 = Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
  const part2 = Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
  return `GIFT-SITI-${part1}-${part2}`
}

// 1. Pricing endpoint with Purchasing Power Parity (PPP)
checkoutRouter.get('/v1/checkout/pricing', (c) => {
  const countryParam = c.req.query('country') || c.req.header('CF-IPCountry') || 'NP'
  const pricing = PppPricingResolver.resolvePrice(countryParam)

  const isNepal = pricing.countryCode === 'NP' || pricing.currencyCode === 'NPR'
  const isIndia = pricing.countryCode === 'IN' || pricing.currencyCode === 'INR'

  const supportedProviders = isNepal
    ? ['khalti', 'esewa', 'stripe']
    : isIndia
    ? ['stripe']
    : ['stripe']

  return c.json({
    pricing,
    allCatalogs: PPP_PRICING_CATALOG,
    supportedProviders,
    freeCoreFeatures: FREE_TIER_FEATURES,
    premiumFeatures: PREMIUM_FEATURES,
  })
})

// 2. Khalti Checkout Initiate
checkoutRouter.post('/v1/checkout/khalti/initiate', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    householdId?: string;
    returnUrl?: string;
    purchaseOrderId?: string;
    amount?: number;
    isGift?: boolean;
    recipientEmail?: string;
    recipientName?: string;
    giftMessage?: string;
    purchaserEmail?: string;
  }

  if (!body.householdId && !body.isGift) {
    return c.json({ error: 'BAD_REQUEST', message: 'householdId is required unless isGift is true' }, 400)
  }

  const pidx = `kht_pidx_${randomBytes(12).toString('hex')}`
  const purchaseOrderId = body.purchaseOrderId || `ord_kht_${Date.now()}`
  const returnUrl = body.returnUrl || 'https://sitiecounter.app/checkout/callback'
  const amountPaisa = (body.amount ?? 999) * 100 // in Paisa for NPR

  const orderData = {
    pidx,
    provider: 'khalti',
    purchaseOrderId,
    householdId: body.householdId,
    amount: body.amount ?? 999,
    currency: 'NPR',
    isGift: Boolean(body.isGift),
    recipientEmail: body.recipientEmail,
    recipientName: body.recipientName,
    giftMessage: body.giftMessage,
    purchaserEmail: body.purchaserEmail,
    status: 'pending',
    createdAt: new Date().toISOString()
  }

  pendingOrdersStore.set(pidx, orderData)
  pendingOrdersStore.set(purchaseOrderId, orderData)

  const paymentUrl = `https://pay.khalti.com/?pidx=${pidx}`

  return c.json({
    pidx,
    purchaseOrderId,
    paymentUrl,
    amount: body.amount ?? 999,
    currency: 'NPR',
    expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString()
  })
})

// 3. Khalti Checkout Verify & Entitlement Provisioning
checkoutRouter.post('/v1/checkout/khalti/verify', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    pidx?: string;
    purchaseOrderId?: string;
    transactionId?: string;
  }

  const key = body.pidx || body.purchaseOrderId
  if (!key) {
    return c.json({ error: 'BAD_REQUEST', message: 'pidx or purchaseOrderId is required' }, 400)
  }

  const order = pendingOrdersStore.get(key)
  if (!order) {
    return c.json({ error: 'NOT_FOUND', message: 'Order not found or expired' }, 404)
  }

  const transactionId = body.transactionId || `kht_txn_${randomBytes(8).toString('hex')}`
  const now = new Date()
  const oneYearLater = new Date(now.getTime() + 365 * 24 * 3600 * 1000)
  const subId = `sub_${randomBytes(10).toString('hex')}`

  let giftCode: string | undefined = undefined
  let entitlementToken: SignedOfflineEntitlement | undefined = undefined

  if (order.isGift) {
    giftCode = generateGiftCode()
    const giftRecord: StoredGiftCode = {
      code: giftCode,
      purchaserHouseholdId: order.householdId,
      purchaserEmail: order.purchaserEmail,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      subscriptionId: subId,
      status: 'unredeemed',
      createdAt: now,
      expiresAt: new Date(now.getTime() + 365 * 24 * 3600 * 1000)
    }
    giftCodesStore.set(giftCode, giftRecord)

    const subRecord: StoredSubscription = {
      id: subId,
      householdId: order.householdId || 'gift_pending',
      tier: 'householdAnnual',
      status: 'active',
      provider: 'khalti',
      transactionId,
      currency: order.currency,
      amount: order.amount,
      isGift: true,
      purchaserEmail: order.purchaserEmail,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      giftCode,
      currentPeriodStart: now,
      currentPeriodEnd: oneYearLater,
      createdAt: now,
      updatedAt: now
    }
    subscriptionsStore.set(subId, subRecord)

    order.status = 'completed'

    return c.json({
      success: true,
      subscriptionId: subId,
      isGift: true,
      giftCode,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      transactionId
    })
  }

  // Normal Direct Household Subscription
  const targetHouseholdId = order.householdId!
  const subRecord: StoredSubscription = {
    id: subId,
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    status: 'active',
    provider: 'khalti',
    transactionId,
    currency: order.currency,
    amount: order.amount,
    isGift: false,
    purchaserEmail: order.purchaserEmail,
    currentPeriodStart: now,
    currentPeriodEnd: oneYearLater,
    createdAt: now,
    updatedAt: now
  }
  subscriptionsStore.set(subId, subRecord)

  // Issue Cryptographically Signed Offline Entitlement Token
  entitlementToken = OfflineEntitlementSigner.issueToken({
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    validityDays: 365,
    issuanceDate: now
  })

  entitlementsStore.set(targetHouseholdId, {
    id: `ent_${randomBytes(8).toString('hex')}`,
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    status: 'active',
    features: PREMIUM_FEATURES,
    offlineToken: entitlementToken.toJSON(),
    signature: entitlementToken.signature,
    expiresAt: oneYearLater,
    createdAt: now,
    updatedAt: now
  })

  order.status = 'completed'

  return c.json({
    success: true,
    subscriptionId: subId,
    householdId: targetHouseholdId,
    isGift: false,
    transactionId,
    entitlementToken: entitlementToken.toJSON()
  })
})

// 4. eSewa ePay Checkout Initiate
checkoutRouter.post('/v1/checkout/esewa/initiate', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    householdId?: string;
    successUrl?: string;
    failureUrl?: string;
    amount?: number;
    isGift?: boolean;
    recipientEmail?: string;
    recipientName?: string;
    giftMessage?: string;
    purchaserEmail?: string;
  }

  if (!body.householdId && !body.isGift) {
    return c.json({ error: 'BAD_REQUEST', message: 'householdId is required unless isGift is true' }, 400)
  }

  const transactionUuid = `esw_${Date.now()}_${randomBytes(4).toString('hex')}`
  const totalAmount = body.amount ?? 999
  const productCode = 'EPAYTEST' // eSewa standard test/sandbox product code

  // eSewa signature message: total_amount,transaction_uuid,product_code
  const signaturePayload = `total_amount=${totalAmount},transaction_uuid=${transactionUuid},product_code=${productCode}`
  const secretKey = '8gBm/:&EnhH.1/q' // eSewa test secret
  const hmac = createHmac('sha256', secretKey)
  hmac.update(signaturePayload)
  const signature = hmac.digest('base64')

  const orderData = {
    transactionUuid,
    provider: 'esewa',
    householdId: body.householdId,
    amount: totalAmount,
    currency: 'NPR',
    isGift: Boolean(body.isGift),
    recipientEmail: body.recipientEmail,
    recipientName: body.recipientName,
    giftMessage: body.giftMessage,
    purchaserEmail: body.purchaserEmail,
    status: 'pending',
    createdAt: new Date().toISOString()
  }

  pendingOrdersStore.set(transactionUuid, orderData)

  const formFields = {
    amount: totalAmount.toString(),
    tax_amount: '0',
    total_amount: totalAmount.toString(),
    transaction_uuid: transactionUuid,
    product_code: productCode,
    product_service_charge: '0',
    product_delivery_charge: '0',
    success_url: body.successUrl || 'https://sitiecounter.app/checkout/esewa/success',
    failure_url: body.failureUrl || 'https://sitiecounter.app/checkout/esewa/failure',
    signed_field_names: 'total_amount,transaction_uuid,product_code',
    signature
  }

  const paymentUrl = 'https://rc-epay.esewa.com.np/api/epay/main/v2/form'

  return c.json({
    transactionUuid,
    paymentUrl,
    formFields,
    amount: totalAmount,
    currency: 'NPR'
  })
})

// 5. eSewa Checkout Verify & Entitlement Provisioning
checkoutRouter.post('/v1/checkout/esewa/verify', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    data?: string; // base64 encoded response from eSewa redirect
    transaction_uuid?: string;
    total_amount?: string | number;
    transaction_code?: string;
  }

  let transactionUuid = body.transaction_uuid
  let totalAmount = body.total_amount
  let transactionCode = body.transaction_code

  if (body.data) {
    try {
      const decodedStr = Buffer.from(body.data, 'base64').toString('utf-8')
      const parsed = JSON.parse(decodedStr)
      transactionUuid = parsed.transaction_uuid
      totalAmount = parsed.total_amount
      transactionCode = parsed.transaction_code
    } catch (_) {
      return c.json({ error: 'BAD_REQUEST', message: 'Invalid base64 eSewa response payload' }, 400)
    }
  }

  if (!transactionUuid) {
    return c.json({ error: 'BAD_REQUEST', message: 'transaction_uuid is required' }, 400)
  }

  const order = pendingOrdersStore.get(transactionUuid)
  if (!order) {
    return c.json({ error: 'NOT_FOUND', message: 'Order not found or expired' }, 404)
  }

  const transactionId = transactionCode || `esw_txn_${randomBytes(8).toString('hex')}`
  const now = new Date()
  const oneYearLater = new Date(now.getTime() + 365 * 24 * 3600 * 1000)
  const subId = `sub_${randomBytes(10).toString('hex')}`

  if (order.isGift) {
    const giftCode = generateGiftCode()
    const giftRecord: StoredGiftCode = {
      code: giftCode,
      purchaserHouseholdId: order.householdId,
      purchaserEmail: order.purchaserEmail,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      subscriptionId: subId,
      status: 'unredeemed',
      createdAt: now,
      expiresAt: new Date(now.getTime() + 365 * 24 * 3600 * 1000)
    }
    giftCodesStore.set(giftCode, giftRecord)

    const subRecord: StoredSubscription = {
      id: subId,
      householdId: order.householdId || 'gift_pending',
      tier: 'householdAnnual',
      status: 'active',
      provider: 'esewa',
      transactionId,
      currency: order.currency,
      amount: order.amount,
      isGift: true,
      purchaserEmail: order.purchaserEmail,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      giftCode,
      currentPeriodStart: now,
      currentPeriodEnd: oneYearLater,
      createdAt: now,
      updatedAt: now
    }
    subscriptionsStore.set(subId, subRecord)

    order.status = 'completed'

    return c.json({
      success: true,
      subscriptionId: subId,
      isGift: true,
      giftCode,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      transactionId
    })
  }

  const targetHouseholdId = order.householdId!
  const subRecord: StoredSubscription = {
    id: subId,
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    status: 'active',
    provider: 'esewa',
    transactionId,
    currency: order.currency,
    amount: order.amount,
    isGift: false,
    purchaserEmail: order.purchaserEmail,
    currentPeriodStart: now,
    currentPeriodEnd: oneYearLater,
    createdAt: now,
    updatedAt: now
  }
  subscriptionsStore.set(subId, subRecord)

  const entitlementToken = OfflineEntitlementSigner.issueToken({
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    validityDays: 365,
    issuanceDate: now
  })

  entitlementsStore.set(targetHouseholdId, {
    id: `ent_${randomBytes(8).toString('hex')}`,
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    status: 'active',
    features: PREMIUM_FEATURES,
    offlineToken: entitlementToken.toJSON(),
    signature: entitlementToken.signature,
    expiresAt: oneYearLater,
    createdAt: now,
    updatedAt: now
  })

  order.status = 'completed'

  return c.json({
    success: true,
    subscriptionId: subId,
    householdId: targetHouseholdId,
    isGift: false,
    transactionId,
    entitlementToken: entitlementToken.toJSON()
  })
})

// 6. Stripe Checkout Session Create
checkoutRouter.post('/v1/checkout/stripe/create-session', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    householdId?: string;
    successUrl?: string;
    cancelUrl?: string;
    country?: string;
    currency?: string;
    isGift?: boolean;
    recipientEmail?: string;
    recipientName?: string;
    giftMessage?: string;
    purchaserEmail?: string;
  }

  if (!body.householdId && !body.isGift) {
    return c.json({ error: 'BAD_REQUEST', message: 'householdId is required unless isGift is true' }, 400)
  }

  const countryParam = body.country || 'US'
  const pricing = PppPricingResolver.resolvePrice(countryParam)
  const currency = (body.currency || pricing.currencyCode).toUpperCase()
  const amount = pricing.amount

  const sessionId = `cs_test_${randomBytes(16).toString('hex')}`
  const orderData = {
    sessionId,
    provider: 'stripe',
    householdId: body.householdId,
    amount,
    currency,
    isGift: Boolean(body.isGift),
    recipientEmail: body.recipientEmail,
    recipientName: body.recipientName,
    giftMessage: body.giftMessage,
    purchaserEmail: body.purchaserEmail,
    status: 'pending',
    createdAt: new Date().toISOString()
  }

  pendingOrdersStore.set(sessionId, orderData)

  const checkoutUrl = `https://checkout.stripe.com/pay/${sessionId}`

  return c.json({
    sessionId,
    checkoutUrl,
    amount,
    currency,
    formattedPriceEn: pricing.formattedPriceEn,
    formattedPriceNe: pricing.formattedPriceNe
  })
})

// 7. Stripe Checkout Verify / Webhook
checkoutRouter.post('/v1/checkout/stripe/verify', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    sessionId?: string;
    paymentIntentId?: string;
  }

  if (!body.sessionId) {
    return c.json({ error: 'BAD_REQUEST', message: 'sessionId is required' }, 400)
  }

  const order = pendingOrdersStore.get(body.sessionId)
  if (!order) {
    return c.json({ error: 'NOT_FOUND', message: 'Session not found or expired' }, 404)
  }

  const transactionId = body.paymentIntentId || `pi_${randomBytes(12).toString('hex')}`
  const now = new Date()
  const oneYearLater = new Date(now.getTime() + 365 * 24 * 3600 * 1000)
  const subId = `sub_${randomBytes(10).toString('hex')}`

  if (order.isGift) {
    const giftCode = generateGiftCode()
    const giftRecord: StoredGiftCode = {
      code: giftCode,
      purchaserHouseholdId: order.householdId,
      purchaserEmail: order.purchaserEmail,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      subscriptionId: subId,
      status: 'unredeemed',
      createdAt: now,
      expiresAt: new Date(now.getTime() + 365 * 24 * 3600 * 1000)
    }
    giftCodesStore.set(giftCode, giftRecord)

    const subRecord: StoredSubscription = {
      id: subId,
      householdId: order.householdId || 'gift_pending',
      tier: 'householdAnnual',
      status: 'active',
      provider: 'stripe',
      transactionId,
      currency: order.currency,
      amount: order.amount,
      isGift: true,
      purchaserEmail: order.purchaserEmail,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      giftCode,
      currentPeriodStart: now,
      currentPeriodEnd: oneYearLater,
      createdAt: now,
      updatedAt: now
    }
    subscriptionsStore.set(subId, subRecord)

    order.status = 'completed'

    return c.json({
      success: true,
      subscriptionId: subId,
      isGift: true,
      giftCode,
      recipientEmail: order.recipientEmail,
      recipientName: order.recipientName,
      giftMessage: order.giftMessage,
      transactionId
    })
  }

  const targetHouseholdId = order.householdId!
  const subRecord: StoredSubscription = {
    id: subId,
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    status: 'active',
    provider: 'stripe',
    transactionId,
    currency: order.currency,
    amount: order.amount,
    isGift: false,
    purchaserEmail: order.purchaserEmail,
    currentPeriodStart: now,
    currentPeriodEnd: oneYearLater,
    createdAt: now,
    updatedAt: now
  }
  subscriptionsStore.set(subId, subRecord)

  const entitlementToken = OfflineEntitlementSigner.issueToken({
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    validityDays: 365,
    issuanceDate: now
  })

  entitlementsStore.set(targetHouseholdId, {
    id: `ent_${randomBytes(8).toString('hex')}`,
    householdId: targetHouseholdId,
    tier: 'householdAnnual',
    status: 'active',
    features: PREMIUM_FEATURES,
    offlineToken: entitlementToken.toJSON(),
    signature: entitlementToken.signature,
    expiresAt: oneYearLater,
    createdAt: now,
    updatedAt: now
  })

  order.status = 'completed'

  return c.json({
    success: true,
    subscriptionId: subId,
    householdId: targetHouseholdId,
    isGift: false,
    transactionId,
    entitlementToken: entitlementToken.toJSON()
  })
})

// 8. Family Gifting Redemption endpoint
checkoutRouter.post('/v1/checkout/gift/redeem', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as {
    giftCode?: string;
    householdId?: string;
  }

  const rawCode = (body.giftCode || '').trim().toUpperCase()
  const householdId = (body.householdId || '').trim()

  if (!rawCode || !householdId) {
    return c.json({ error: 'BAD_REQUEST', message: 'giftCode and householdId are required' }, 400)
  }

  const gift = giftCodesStore.get(rawCode)
  if (!gift) {
    return c.json({ error: 'NOT_FOUND', message: 'Invalid or non-existent gift code' }, 404)
  }

  if (gift.status === 'redeemed') {
    return c.json({
      error: 'ALREADY_REDEEMED',
      message: 'This gift code has already been redeemed',
      redeemedAt: gift.redeemedAt?.toISOString()
    }, 409)
  }

  const now = new Date()
  if (now.getTime() > gift.expiresAt.getTime()) {
    gift.status = 'expired'
    return c.json({ error: 'EXPIRED', message: 'This gift code has expired' }, 410)
  }

  // Redeem the code
  gift.status = 'redeemed'
  gift.redeemedByHouseholdId = householdId
  gift.redeemedAt = now

  // Repoint or activate subscription for the recipient household
  const sub = subscriptionsStore.get(gift.subscriptionId)
  const oneYearLater = new Date(now.getTime() + 365 * 24 * 3600 * 1000)

  if (sub) {
    sub.householdId = householdId
    sub.currentPeriodStart = now
    sub.currentPeriodEnd = oneYearLater
    sub.updatedAt = now
  }

  // Issue Cryptographically Signed Offline Entitlement Token for the recipient household
  const entitlementToken = OfflineEntitlementSigner.issueToken({
    householdId,
    tier: 'householdAnnual',
    validityDays: 365,
    issuanceDate: now
  })

  entitlementsStore.set(householdId, {
    id: `ent_${randomBytes(8).toString('hex')}`,
    householdId,
    tier: 'householdAnnual',
    status: 'active',
    features: PREMIUM_FEATURES,
    offlineToken: entitlementToken.toJSON(),
    signature: entitlementToken.signature,
    expiresAt: oneYearLater,
    createdAt: now,
    updatedAt: now
  })

  return c.json({
    success: true,
    subscriptionId: gift.subscriptionId,
    householdId,
    giftMessage: gift.giftMessage,
    purchaserEmail: gift.purchaserEmail,
    recipientName: gift.recipientName,
    entitlementToken: entitlementToken.toJSON()
  })
})

// 9. Household Subscription Status
checkoutRouter.get('/v1/subscriptions/household/:householdId', (c) => {
  const householdId = c.req.param('householdId')

  // Find active subscription for household
  let activeSub: StoredSubscription | undefined = undefined
  for (const sub of subscriptionsStore.values()) {
    if (sub.householdId === householdId && sub.status === 'active') {
      activeSub = sub
      break
    }
  }

  if (!activeSub) {
    return c.json({
      householdId,
      hasActiveSubscription: false,
      tier: 'free',
      status: 'none'
    })
  }

  return c.json({
    householdId,
    hasActiveSubscription: true,
    tier: activeSub.tier,
    status: activeSub.status,
    provider: activeSub.provider,
    currency: activeSub.currency,
    amount: activeSub.amount,
    currentPeriodStart: activeSub.currentPeriodStart.toISOString(),
    currentPeriodEnd: activeSub.currentPeriodEnd.toISOString(),
    isGift: activeSub.isGift
  })
})

// 10. Household Entitlements Service
checkoutRouter.get('/v1/entitlements/:householdId', (c) => {
  const householdId = c.req.param('householdId')
  const ent = entitlementsStore.get(householdId)

  const now = new Date()

  if (ent && ent.status === 'active' && now.getTime() < ent.expiresAt.getTime()) {
    return c.json({
      householdId,
      tier: ent.tier,
      status: 'active',
      features: ent.features,
      offlineToken: ent.offlineToken,
      expiresAt: ent.expiresAt.toISOString()
    })
  }

  // Free Tier fallback
  const freeToken = OfflineEntitlementSigner.issueToken({
    householdId,
    tier: 'free',
    validityDays: 365,
    issuanceDate: now
  })

  return c.json({
    householdId,
    tier: 'free',
    status: 'active',
    features: FREE_TIER_FEATURES,
    offlineToken: freeToken.toJSON(),
    expiresAt: freeToken.expiresAt.toISOString()
  })
})
