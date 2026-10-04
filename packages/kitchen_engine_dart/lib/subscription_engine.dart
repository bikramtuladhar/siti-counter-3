import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Subscription Tier definition
enum SubscriptionTier {
  free,
  householdAnnual;

  bool get isPremium => this == SubscriptionTier.householdAnnual;
}

/// Feature flags unlocked by subscription
class SubscriptionFeatures {
  static const String coreCookingLoop = 'core_cooking_loop';
  static const String whistleCounter = 'whistle_counter';
  static const String mealPlanner = 'meal_planner';
  static const String groceryHaatBazaar = 'grocery_haat_bazaar';
  static const String offlineSync = 'offline_sync';

  // Premium Features
  static const String unlimitedAiAssistant = 'unlimited_ai_assistant';
  static const String liveMarketPrices = 'live_market_prices';
  static const String partyModeBhoj = 'party_mode_bhoj';
  static const String familyCookbook = 'family_cookbook';
  static const String multiDeviceHousehold = 'multi_device_household';

  static const List<String> freeTierFeatures = [
    coreCookingLoop,
    whistleCounter,
    mealPlanner,
    groceryHaatBazaar,
    offlineSync,
  ];

  static const List<String> premiumFeatures = [
    ...freeTierFeatures,
    unlimitedAiAssistant,
    liveMarketPrices,
    partyModeBhoj,
    familyCookbook,
    multiDeviceHousehold,
  ];
}

/// Purchasing-Power Parity (PPP) Pricing Information
class PppPlanPrice {
  final String countryCode;
  final String currencyCode;
  final String currencySymbol;
  final double amount;
  final String formattedPriceEn;
  final String formattedPriceNe;

  const PppPlanPrice({
    required this.countryCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.amount,
    required this.formattedPriceEn,
    required this.formattedPriceNe,
  });
}

class PppPricingCatalog {
  static const Map<String, PppPlanPrice> catalog = {
    'NP': PppPlanPrice(
      countryCode: 'NP',
      currencyCode: 'NPR',
      currencySymbol: 'NPR',
      amount: 999.0,
      formattedPriceEn: 'NPR 999 / year',
      formattedPriceNe: 'रु ९९९ / वर्ष',
    ),
    'IN': PppPlanPrice(
      countryCode: 'IN',
      currencyCode: 'INR',
      currencySymbol: '₹',
      amount: 499.0,
      formattedPriceEn: '₹499 / year',
      formattedPriceNe: '₹४९९ / वर्ष',
    ),
    'US': PppPlanPrice(
      countryCode: 'US',
      currencyCode: 'USD',
      currencySymbol: '\$',
      amount: 14.99,
      formattedPriceEn: '\$14.99 / year',
      formattedPriceNe: '\$१४.९९ / वर्ष',
    ),
    'GB': PppPlanPrice(
      countryCode: 'GB',
      currencyCode: 'GBP',
      currencySymbol: '£',
      amount: 12.99,
      formattedPriceEn: '£12.99 / year',
      formattedPriceNe: '£१२.९९ / वर्ष',
    ),
    'AU': PppPlanPrice(
      countryCode: 'AU',
      currencyCode: 'AUD',
      currencySymbol: 'A\$',
      amount: 19.99,
      formattedPriceEn: 'A\$19.99 / year',
      formattedPriceNe: 'A\$१९.९९ / वर्ष',
    ),
    'EU': PppPlanPrice(
      countryCode: 'EU',
      currencyCode: 'EUR',
      currencySymbol: '€',
      amount: 13.99,
      formattedPriceEn: '€13.99 / year',
      formattedPriceNe: '€१३.९९ / वर्ष',
    ),
  };

  static PppPlanPrice resolvePrice(String countryOrCurrency) {
    final upper = countryOrCurrency.toUpperCase();
    if (catalog.containsKey(upper)) {
      return catalog[upper]!;
    }
    for (final p in catalog.values) {
      if (p.currencyCode == upper) {
        return p;
      }
    }
    // Default to US / International
    return catalog['US']!;
  }
}

/// Signed Offline Entitlement Token for local-first verification
class SignedOfflineEntitlement {
  final String householdId;
  final SubscriptionTier tier;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<String> features;
  final String issuer;
  final String signature;

  const SignedOfflineEntitlement({
    required this.householdId,
    required this.tier,
    required this.issuedAt,
    required this.expiresAt,
    required this.features,
    required this.issuer,
    required this.signature,
  });

  bool isValid([DateTime? asOf]) {
    final now = asOf ?? DateTime.now();
    return now.isBefore(expiresAt);
  }

  bool hasFeature(String featureName, [DateTime? asOf]) {
    if (!isValid(asOf)) return false;
    return features.contains(featureName);
  }

  Map<String, dynamic> toJson() => {
        'householdId': householdId,
        'tier': tier.name,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'features': features,
        'issuer': issuer,
        'signature': signature,
      };

  factory SignedOfflineEntitlement.fromJson(Map<String, dynamic> json) {
    return SignedOfflineEntitlement(
      householdId: json['householdId'] as String,
      tier: (json['tier'] as String) == 'householdAnnual'
          ? SubscriptionTier.householdAnnual
          : SubscriptionTier.free,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      features: List<String>.from(json['features'] as List),
      issuer: json['issuer'] as String,
      signature: json['signature'] as String,
    );
  }
}

class OfflineEntitlementSigner {
  static const String defaultSecretKey = 'siti-counter-offline-token-secret-2026';

  /// Generates a signed offline entitlement token valid for [validityDays]
  static SignedOfflineEntitlement issueToken({
    required String householdId,
    required SubscriptionTier tier,
    int validityDays = 365,
    DateTime? issuanceDate,
    String secretKey = defaultSecretKey,
  }) {
    final now = issuanceDate ?? DateTime.now();
    final expiresAt = now.add(Duration(days: validityDays));
    final features = tier.isPremium
        ? SubscriptionFeatures.premiumFeatures
        : SubscriptionFeatures.freeTierFeatures;
    const issuer = 'siti_counter_authority';

    final payloadString = '$householdId:${tier.name}:${now.millisecondsSinceEpoch}:${expiresAt.millisecondsSinceEpoch}:${features.join(",")}:$issuer';
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final signature = hmac.convert(utf8.encode(payloadString)).toString();

    return SignedOfflineEntitlement(
      householdId: householdId,
      tier: tier,
      issuedAt: now,
      expiresAt: expiresAt,
      features: features,
      issuer: issuer,
      signature: signature,
    );
  }

  /// Verifies cryptographic signature and expiry of the offline entitlement token
  static bool verifyToken({
    required SignedOfflineEntitlement token,
    String secretKey = defaultSecretKey,
    DateTime? verificationDate,
  }) {
    final now = verificationDate ?? DateTime.now();
    if (now.isAfter(token.expiresAt)) {
      return false;
    }

    final payloadString = '${token.householdId}:${token.tier.name}:${token.issuedAt.millisecondsSinceEpoch}:${token.expiresAt.millisecondsSinceEpoch}:${token.features.join(",")}:${token.issuer}';
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final expectedSignature = hmac.convert(utf8.encode(payloadString)).toString();

    return expectedSignature == token.signature;
  }
}
