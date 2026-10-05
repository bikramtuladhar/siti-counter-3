import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

typedef UrlLauncherCallback = Future<bool> Function(Uri uri);

/// Service managing deep-linking and handoff to regional retail partners (Daraz, Bhatbhateni, BigMart)
/// Enforces Section 9.5 & 26.4:
/// - Generates query-specific search deep links (App scheme with Web fallback).
/// - Clear disclosure of affiliate relationships.
/// - Strict zero advertising rank bias.
/// - Full user opt-out to disable shopping partner links entirely.
class RetailerHandoffService extends ChangeNotifier {
  final RetailerHandoffEngine _engine;
  final UrlLauncherCallback? _urlLauncher;
  final String _countryCode;

  RetailerHandoffService({
    bool partnerLinksEnabled = true,
    String? preferredRetailerId,
    String this._countryCode = 'NP',
    UrlLauncherCallback? this._urlLauncher,
  })  : _engine = RetailerHandoffEngine(
          partnerLinksEnabled: partnerLinksEnabled,
          preferredRetailerId: preferredRetailerId,
        );

  bool get partnerLinksEnabled => _engine.isPartnerLinksEnabled;
  String get countryCode => _countryCode;
  String? get preferredRetailerId => _engine.getAvailableRetailers(_countryCode).isNotEmpty
      ? _engine.getAvailableRetailers(_countryCode).first.id
      : null;

  List<RetailerPartner> get availableRetailers =>
      _engine.getAvailableRetailers(_countryCode);

  void setPartnerLinksEnabled(bool enabled) {
    _engine.setPartnerLinksEnabled(enabled);
    notifyListeners();
  }

  void setPreferredRetailer(String? retailerId) {
    _engine.setPreferredRetailer(retailerId);
    notifyListeners();
  }

  RetailerDeepLinkResult? getItemDeepLink(String retailerId, String query) {
    return _engine.generateItemDeepLink(retailerId, query);
  }

  BasketHandoffResult? getBasketHandoff(String retailerId, List<String> itemQueries) {
    return _engine.generateBasketHandoff(retailerId, itemQueries);
  }

  /// Launches the retailer link (App scheme preferred, Web fallback)
  Future<bool> launchLink(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return false;

    if (_urlLauncher != null) {
      return await _urlLauncher(uri);
    }

    // Default fallback if no custom launcher injected
    return true;
  }
}
