import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  PppPricingResolver,
  OfflineEntitlementSigner,
  SignedOfflineEntitlement,
  SUBSCRIPTION_FEATURES,
} from './subscription_engine.js';

describe('SubscriptionEngine TypeScript Parity Tests', () => {
  it('resolves correct PPP price for Nepal, India, US, UK, and Australia', () => {
    const nepal = PppPricingResolver.resolvePrice('NP');
    assert.equal(nepal.amount, 999.0);
    assert.equal(nepal.currencyCode, 'NPR');
    assert.equal(nepal.formattedPriceEn, 'NPR 999 / year');
    assert.equal(nepal.formattedPriceNe, 'रु ९९९ / वर्ष');

    const india = PppPricingResolver.resolvePrice('IN');
    assert.equal(india.amount, 499.0);
    assert.equal(india.currencyCode, 'INR');

    const us = PppPricingResolver.resolvePrice('USD');
    assert.equal(us.amount, 14.99);

    const uk = PppPricingResolver.resolvePrice('GB');
    assert.equal(uk.amount, 12.99);

    const aus = PppPricingResolver.resolvePrice('AU');
    assert.equal(aus.amount, 19.99);
  });

  it('issues valid signed premium entitlement with cryptographic signature', () => {
    const householdId = 'household-ts-555';
    const token = OfflineEntitlementSigner.issueToken({
      householdId,
      tier: 'householdAnnual',
      validityDays: 365,
    });

    assert.equal(token.householdId, householdId);
    assert.equal(token.tier, 'householdAnnual');
    assert.equal(token.isValid(), true);
    assert.equal(token.hasFeature(SUBSCRIPTION_FEATURES.coreCookingLoop), true);
    assert.equal(token.hasFeature(SUBSCRIPTION_FEATURES.unlimitedAiAssistant), true);
    assert.equal(token.hasFeature(SUBSCRIPTION_FEATURES.partyModeBhoj), true);

    const isValidSig = OfflineEntitlementSigner.verifyToken({ token });
    assert.equal(isValidSig, true);
  });

  it('free tier entitlement lacks premium features', () => {
    const token = OfflineEntitlementSigner.issueToken({
      householdId: 'household-free',
      tier: 'free',
    });

    assert.equal(token.hasFeature(SUBSCRIPTION_FEATURES.coreCookingLoop), true);
    assert.equal(token.hasFeature(SUBSCRIPTION_FEATURES.unlimitedAiAssistant), false);
    assert.equal(token.hasFeature(SUBSCRIPTION_FEATURES.partyModeBhoj), false);
  });

  it('verifies signature failure on tampered tokens and expired tokens', () => {
    const token = OfflineEntitlementSigner.issueToken({
      householdId: 'household-valid',
      tier: 'householdAnnual',
    });

    const tampered = new SignedOfflineEntitlement({
      householdId: 'household-tampered',
      tier: token.tier,
      issuedAt: token.issuedAt,
      expiresAt: token.expiresAt,
      features: token.features,
      issuer: token.issuer,
      signature: token.signature,
    });
    assert.equal(OfflineEntitlementSigner.verifyToken({ token: tampered }), false);

    const expired = OfflineEntitlementSigner.issueToken({
      householdId: 'household-expired',
      tier: 'householdAnnual',
      validityDays: -1,
    });
    assert.equal(expired.isValid(), false);
    assert.equal(OfflineEntitlementSigner.verifyToken({ token: expired }), false);
  });

  it('serializes and deserializes token to/from JSON', () => {
    const original = OfflineEntitlementSigner.issueToken({
      householdId: 'household-json',
      tier: 'householdAnnual',
    });

    const json = original.toJSON();
    const restored = SignedOfflineEntitlement.fromJSON(json);

    assert.equal(restored.householdId, original.householdId);
    assert.equal(restored.signature, original.signature);
    assert.equal(OfflineEntitlementSigner.verifyToken({ token: restored }), true);
  });
});
