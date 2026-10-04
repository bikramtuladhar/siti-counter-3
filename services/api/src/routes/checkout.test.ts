import { test } from 'node:test'
import assert from 'node:assert'
import { app } from '../index.js'
import {
  OfflineEntitlementSigner,
  SignedOfflineEntitlement,
  SUBSCRIPTION_FEATURES
} from '@siti-counter/kitchen-engine'

test('GET /v1/checkout/pricing returns PPP catalog and supported providers', async () => {
  // Nepal
  const resNp = await app.request('/v1/checkout/pricing?country=NP')
  assert.strictEqual(resNp.status, 200)
  const dataNp = (await resNp.json()) as any
  assert.strictEqual(dataNp.pricing.currencyCode, 'NPR')
  assert.strictEqual(dataNp.pricing.amount, 999)
  assert.deepStrictEqual(dataNp.supportedProviders, ['khalti', 'esewa', 'stripe'])
  assert.ok(dataNp.freeCoreFeatures.includes('whistle_counter'))
  assert.ok(dataNp.premiumFeatures.includes('unlimited_ai_assistant'))

  // India
  const resIn = await app.request('/v1/checkout/pricing?country=IN')
  assert.strictEqual(resIn.status, 200)
  const dataIn = (await resIn.json()) as any
  assert.strictEqual(dataIn.pricing.currencyCode, 'INR')
  assert.strictEqual(dataIn.pricing.amount, 499)

  // US / Global
  const resUs = await app.request('/v1/checkout/pricing?country=US')
  assert.strictEqual(resUs.status, 200)
  const dataUs = (await resUs.json()) as any
  assert.strictEqual(dataUs.pricing.currencyCode, 'USD')
  assert.strictEqual(dataUs.pricing.amount, 14.99)
})

test('Khalti Checkout Flow: initiate, verify, and entitlements provisioning', async () => {
  const householdId = 'hh_khalti_test_001'

  // Initiate
  const initRes = await app.request('/v1/checkout/khalti/initiate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      householdId,
      amount: 999,
      purchaserEmail: 'user@example.com'
    })
  })
  assert.strictEqual(initRes.status, 200)
  const initData = (await initRes.json()) as any
  assert.ok(initData.pidx.startsWith('kht_pidx_'))
  assert.ok(initData.paymentUrl.includes(initData.pidx))

  // Verify
  const verifyRes = await app.request('/v1/checkout/khalti/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      pidx: initData.pidx,
      transactionId: 'kht_txn_123456'
    })
  })
  assert.strictEqual(verifyRes.status, 200)
  const verifyData = (await verifyRes.json()) as any
  assert.strictEqual(verifyData.success, true)
  assert.strictEqual(verifyData.householdId, householdId)
  assert.strictEqual(verifyData.isGift, false)
  assert.ok(verifyData.subscriptionId.startsWith('sub_'))

  // Verify Cryptographic Entitlement Token
  const token = SignedOfflineEntitlement.fromJSON(verifyData.entitlementToken)
  assert.strictEqual(token.householdId, householdId)
  assert.strictEqual(token.tier, 'householdAnnual')
  assert.strictEqual(token.hasFeature(SUBSCRIPTION_FEATURES.unlimitedAiAssistant), true)
  assert.strictEqual(OfflineEntitlementSigner.verifyToken({ token }), true)

  // Entitlements Service Check
  const entRes = await app.request(`/v1/entitlements/${householdId}`)
  assert.strictEqual(entRes.status, 200)
  const entData = (await entRes.json()) as any
  assert.strictEqual(entData.tier, 'householdAnnual')
  assert.strictEqual(entData.status, 'active')

  // Subscriptions Status Check
  const subRes = await app.request(`/v1/subscriptions/household/${householdId}`)
  assert.strictEqual(subRes.status, 200)
  const subData = (await subRes.json()) as any
  assert.strictEqual(subData.hasActiveSubscription, true)
  assert.strictEqual(subData.provider, 'khalti')
  assert.strictEqual(subData.amount, 999)
})

test('eSewa Checkout Flow: initiate, signed formFields, verify and entitlement', async () => {
  const householdId = 'hh_esewa_test_002'

  // Initiate
  const initRes = await app.request('/v1/checkout/esewa/initiate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      householdId,
      amount: 999
    })
  })
  assert.strictEqual(initRes.status, 200)
  const initData = (await initRes.json()) as any
  assert.ok(initData.transactionUuid.startsWith('esw_'))
  assert.ok(initData.formFields.signature)
  assert.strictEqual(initData.formFields.product_code, 'EPAYTEST')

  // Verify
  const verifyRes = await app.request('/v1/checkout/esewa/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      transaction_uuid: initData.transactionUuid,
      transaction_code: 'esw_txn_success_789',
      total_amount: 999
    })
  })
  assert.strictEqual(verifyRes.status, 200)
  const verifyData = (await verifyRes.json()) as any
  assert.strictEqual(verifyData.success, true)
  assert.strictEqual(verifyData.householdId, householdId)

  const token = SignedOfflineEntitlement.fromJSON(verifyData.entitlementToken)
  assert.strictEqual(token.householdId, householdId)
  assert.strictEqual(OfflineEntitlementSigner.verifyToken({ token }), true)
})

test('Stripe Checkout Flow: session creation, verification and offline entitlement', async () => {
  const householdId = 'hh_stripe_test_003'

  // Create session
  const sessionRes = await app.request('/v1/checkout/stripe/create-session', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      householdId,
      country: 'US',
      purchaserEmail: 'diaspora@example.com'
    })
  })
  assert.strictEqual(sessionRes.status, 200)
  const sessionData = (await sessionRes.json()) as any
  assert.ok(sessionData.sessionId.startsWith('cs_test_'))
  assert.strictEqual(sessionData.currency, 'USD')
  assert.strictEqual(sessionData.amount, 14.99)

  // Verify
  const verifyRes = await app.request('/v1/checkout/stripe/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      sessionId: sessionData.sessionId
    })
  })
  assert.strictEqual(verifyRes.status, 200)
  const verifyData = (await verifyRes.json()) as any
  assert.strictEqual(verifyData.success, true)
  assert.strictEqual(verifyData.householdId, householdId)
  assert.strictEqual(verifyData.isGift, false)

  const token = SignedOfflineEntitlement.fromJSON(verifyData.entitlementToken)
  assert.strictEqual(token.householdId, householdId)
  assert.strictEqual(OfflineEntitlementSigner.verifyToken({ token }), true)
})

test('Family Gifting Flow: diaspora purchase abroad and redemption in Nepal', async () => {
  // 1. Diaspora user in US buys a gift subscription for family in Nepal
  const giftSessionRes = await app.request('/v1/checkout/stripe/create-session', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      isGift: true,
      country: 'US',
      purchaserEmail: 'pramod.diaspora@gmail.com',
      recipientEmail: 'aama.nepal@gmail.com',
      recipientName: 'Aama (Kathmandu)',
      giftMessage: 'दशैंको धेरै धेरै शुभकामना आमा! सिट्ठी काउन्टर प्रिमियम तपाईंको भान्साको लागि!'
    })
  })
  assert.strictEqual(giftSessionRes.status, 200)
  const giftSession = (await giftSessionRes.json()) as any

  // 2. Stripe payment completes
  const verifyGiftRes = await app.request('/v1/checkout/stripe/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      sessionId: giftSession.sessionId
    })
  })
  assert.strictEqual(verifyGiftRes.status, 200)
  const verifyGift = (await verifyGiftRes.json()) as any
  assert.strictEqual(verifyGift.isGift, true)
  assert.ok(verifyGift.giftCode.startsWith('GIFT-SITI-'))

  const giftCode = verifyGift.giftCode

  // 3. Recipient attempts redemption with invalid code
  const invalidRes = await app.request('/v1/checkout/gift/redeem', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      giftCode: 'GIFT-SITI-INVALID-CODE',
      householdId: 'hh_family_ktm_001'
    })
  })
  assert.strictEqual(invalidRes.status, 404)

  // 4. Family in Nepal redeems the valid gift code
  const recipientHouseholdId = 'hh_family_ktm_001'
  const redeemRes = await app.request('/v1/checkout/gift/redeem', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      giftCode,
      householdId: recipientHouseholdId
    })
  })
  assert.strictEqual(redeemRes.status, 200)
  const redeemData = (await redeemRes.json()) as any
  assert.strictEqual(redeemData.success, true)
  assert.strictEqual(redeemData.householdId, recipientHouseholdId)
  assert.strictEqual(redeemData.purchaserEmail, 'pramod.diaspora@gmail.com')
  assert.strictEqual(redeemData.giftMessage, 'दशैंको धेरै धेरै शुभकामना आमा! सिट्ठी काउन्टर प्रिमियम तपाईंको भान्साको लागि!')

  // Check Cryptographic Offline Entitlement for recipient household
  const recipientToken = SignedOfflineEntitlement.fromJSON(redeemData.entitlementToken)
  assert.strictEqual(recipientToken.householdId, recipientHouseholdId)
  assert.strictEqual(recipientToken.tier, 'householdAnnual')
  assert.strictEqual(recipientToken.hasFeature(SUBSCRIPTION_FEATURES.partyModeBhoj), true)
  assert.strictEqual(OfflineEntitlementSigner.verifyToken({ token: recipientToken }), true)

  // 5. Attempting to redeem the same gift code again should be rejected with 409
  const duplicateRes = await app.request('/v1/checkout/gift/redeem', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      giftCode,
      householdId: 'hh_another_unauthorized_user'
    })
  })
  assert.strictEqual(duplicateRes.status, 409)

  // 6. Household Entitlements endpoint reflects the active subscription
  const entRes = await app.request(`/v1/entitlements/${recipientHouseholdId}`)
  assert.strictEqual(entRes.status, 200)
  const entData = (await entRes.json()) as any
  assert.strictEqual(entData.tier, 'householdAnnual')
  assert.strictEqual(entData.status, 'active')
})

test('Household with no subscription returns free tier offline entitlement', async () => {
  const freeHouseholdId = 'hh_free_user_never_paid'
  const res = await app.request(`/v1/entitlements/${freeHouseholdId}`)
  assert.strictEqual(res.status, 200)
  const data = (await res.json()) as any
  assert.strictEqual(data.tier, 'free')
  assert.strictEqual(data.features.includes('whistle_counter'), true)
  assert.strictEqual(data.features.includes('unlimited_ai_assistant'), false)

  const token = SignedOfflineEntitlement.fromJSON(data.offlineToken)
  assert.strictEqual(token.householdId, freeHouseholdId)
  assert.strictEqual(token.tier, 'free')
  assert.strictEqual(OfflineEntitlementSigner.verifyToken({ token }), true)
})
