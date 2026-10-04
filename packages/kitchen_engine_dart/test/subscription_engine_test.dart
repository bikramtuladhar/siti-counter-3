import 'package:test/test.dart';
import 'package:kitchen_engine/subscription_engine.dart';

void main() {
  group('PPP Pricing Catalog Tests', () {
    test('resolves correct PPP price for Nepal, India, US, UK, and Australia', () {
      final nepal = PppPricingCatalog.resolvePrice('NP');
      expect(nepal.amount, equals(999.0));
      expect(nepal.currencyCode, equals('NPR'));
      expect(nepal.formattedPriceEn, equals('NPR 999 / year'));
      expect(nepal.formattedPriceNe, equals('रु ९९९ / वर्ष'));

      final india = PppPricingCatalog.resolvePrice('IN');
      expect(india.amount, equals(499.0));
      expect(india.currencyCode, equals('INR'));
      expect(india.formattedPriceEn, equals('₹499 / year'));

      final us = PppPricingCatalog.resolvePrice('US');
      expect(us.amount, equals(14.99));
      expect(us.currencyCode, equals('USD'));

      final uk = PppPricingCatalog.resolvePrice('GB');
      expect(uk.amount, equals(12.99));
      expect(uk.currencyCode, equals('GBP'));

      final aus = PppPricingCatalog.resolvePrice('AU');
      expect(aus.amount, equals(19.99));
      expect(aus.currencyCode, equals('AUD'));
    });

    test('resolves price by currency code and defaults unknown regions to US', () {
      final byCurrency = PppPricingCatalog.resolvePrice('npr');
      expect(byCurrency.countryCode, equals('NP'));

      final unknown = PppPricingCatalog.resolvePrice('XX');
      expect(unknown.countryCode, equals('US'));
      expect(unknown.amount, equals(14.99));
    });
  });

  group('Signed Offline Entitlement Tests', () {
    const householdId = 'household-tuladhar-101';

    test('issues valid signed premium entitlement with all premium features', () {
      final token = OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.householdAnnual,
        validityDays: 365,
      );

      expect(token.householdId, equals(householdId));
      expect(token.tier, equals(SubscriptionTier.householdAnnual));
      expect(token.isValid(), isTrue);

      // Verify features
      expect(token.hasFeature(SubscriptionFeatures.coreCookingLoop), isTrue);
      expect(token.hasFeature(SubscriptionFeatures.unlimitedAiAssistant), isTrue);
      expect(token.hasFeature(SubscriptionFeatures.partyModeBhoj), isTrue);
      expect(token.hasFeature(SubscriptionFeatures.liveMarketPrices), isTrue);

      // Verify cryptographic signature
      final isSignatureValid = OfflineEntitlementSigner.verifyToken(token: token);
      expect(isSignatureValid, isTrue);
    });

    test('free tier entitlement lacks premium features', () {
      final token = OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.free,
      );

      expect(token.hasFeature(SubscriptionFeatures.coreCookingLoop), isTrue);
      expect(token.hasFeature(SubscriptionFeatures.unlimitedAiAssistant), isFalse);
      expect(token.hasFeature(SubscriptionFeatures.partyModeBhoj), isFalse);
    });

    test('verifies signature failure on tampered tokens', () {
      final token = OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.householdAnnual,
      );

      // Tampered household ID
      final tampered = SignedOfflineEntitlement(
        householdId: 'household-hacker-999',
        tier: token.tier,
        issuedAt: token.issuedAt,
        expiresAt: token.expiresAt,
        features: token.features,
        issuer: token.issuer,
        signature: token.signature,
      );

      expect(OfflineEntitlementSigner.verifyToken(token: tampered), isFalse);
    });

    test('verifies signature failure on expired tokens', () {
      final expiredToken = OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.householdAnnual,
        validityDays: -1, // Expired yesterday
      );

      expect(expiredToken.isValid(), isFalse);
      expect(OfflineEntitlementSigner.verifyToken(token: expiredToken), isFalse);
    });

    test('serializes and deserializes token to/from JSON cleanly', () {
      final original = OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.householdAnnual,
      );

      final json = original.toJson();
      final restored = SignedOfflineEntitlement.fromJson(json);

      expect(restored.householdId, equals(original.householdId));
      expect(restored.signature, equals(original.signature));
      expect(restored.tier, equals(original.tier));
      expect(OfflineEntitlementSigner.verifyToken(token: restored), isTrue);
    });
  });
}
