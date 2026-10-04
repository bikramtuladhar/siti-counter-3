import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

/// Subscription Service managing in-app subscriptions, PPP pricing, and offline entitlement tokens
class SubscriptionService extends ChangeNotifier {
  final String householdId;
  final String countryCode;

  SignedOfflineEntitlement? _cachedEntitlement;
  bool _isLoading = false;

  SubscriptionService({
    required this.householdId,
    this.countryCode = 'NP',
    SignedOfflineEntitlement? initialEntitlement,
  }) {
    if (initialEntitlement != null) {
      _cachedEntitlement = initialEntitlement;
    } else {
      // Default to free tier
      _cachedEntitlement = OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.free,
      );
    }
  }

  SignedOfflineEntitlement get currentEntitlement =>
      _cachedEntitlement ??
      OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.free,
      );

  bool get isPremium =>
      currentEntitlement.tier.isPremium && currentEntitlement.isValid();

  bool get isLoading => _isLoading;

  PppPlanPrice get planPrice => PppPricingCatalog.resolvePrice(countryCode);

  bool hasFeature(String featureName) {
    return currentEntitlement.hasFeature(featureName);
  }

  /// Simulates / triggers purchasing the annual household subscription
  Future<bool> purchaseAnnualSubscription() async {
    _isLoading = true;
    notifyListeners();

    try {
      // In production, delegates to RevenueCat Purchases.purchasePackage() or in_app_purchase
      await Future.delayed(const Duration(milliseconds: 600));

      final newEntitlement = OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.householdAnnual,
        validityDays: 365,
      );

      _cachedEntitlement = newEntitlement;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Restores previous in-app purchases
  Future<bool> restorePurchases() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      // Restore active entitlement
      final restored = OfflineEntitlementSigner.issueToken(
        householdId: householdId,
        tier: SubscriptionTier.householdAnnual,
        validityDays: 365,
      );

      _cachedEntitlement = restored;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Manually loads a cached signed offline token string
  bool loadCachedTokenString(String tokenJsonString) {
    try {
      final decoded = jsonDecode(tokenJsonString) as Map<String, dynamic>;
      final token = SignedOfflineEntitlement.fromJson(decoded);
      if (OfflineEntitlementSigner.verifyToken(token: token)) {
        _cachedEntitlement = token;
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
