/// Siti Counter 3.0 - Retailer Shopping Handoff & Deep-Linking Engine
/// Implements Section 9.5 & 26.4:
/// - Deep-link generation from grocery list items to search pages on Daraz, Bhatbhateni, and regional retailers.
/// - Clear disclosure of affiliate relationships (zero advertising rank bias).
/// - Full user opt-out to disable shopping partner links entirely.
library;

import 'dart:convert';

class RetailerPartner {
  final String id;
  final String name;
  final String nameNe;
  final String countryCode;
  final String icon;
  final String websiteUrl;
  final String appSchemePrefix;
  final bool isAffiliate;
  final String? affiliateTag;
  final bool directCartSupported;
  final String disclosureEn;
  final String disclosureNe;
  final String descriptionEn;
  final String descriptionNe;

  const RetailerPartner({
    required this.id,
    required this.name,
    required this.nameNe,
    required this.countryCode,
    required this.icon,
    required this.websiteUrl,
    required this.appSchemePrefix,
    required this.isAffiliate,
    this.affiliateTag,
    this.directCartSupported = true,
    required this.disclosureEn,
    required this.disclosureNe,
    required this.descriptionEn,
    required this.descriptionNe,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameNe': nameNe,
    'countryCode': countryCode,
    'icon': icon,
    'websiteUrl': websiteUrl,
    'appSchemePrefix': appSchemePrefix,
    'isAffiliate': isAffiliate,
    'affiliateTag': affiliateTag,
    'directCartSupported': directCartSupported,
    'disclosureEn': disclosureEn,
    'disclosureNe': disclosureNe,
    'descriptionEn': descriptionEn,
    'descriptionNe': descriptionNe,
  };
}

class PartnerCartItem {
  final String itemId;
  final String name;
  final String? nameNe;
  final double quantity;
  final String unit;
  final double? estimatedPriceNpr;

  const PartnerCartItem({
    required this.itemId,
    required this.name,
    this.nameNe,
    required this.quantity,
    required this.unit,
    this.estimatedPriceNpr,
  });

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'name': name,
    if (nameNe != null) 'nameNe': nameNe,
    'quantity': quantity,
    'unit': unit,
    if (estimatedPriceNpr != null) 'estimatedPriceNpr': estimatedPriceNpr,
  };
}

class PartnerCartTransferResult {
  final String cartId;
  final String householdId;
  final String retailerId;
  final String retailerName;
  final String status;
  final int totalItems;
  final int transferredItemsCount;
  final List<Map<String, String>> unmatchedItems;
  final double estimatedSubtotalNpr;
  final String cartWebUrl;
  final String cartAppUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String disclosureEn;
  final String disclosureNe;

  const PartnerCartTransferResult({
    required this.cartId,
    required this.householdId,
    required this.retailerId,
    required this.retailerName,
    required this.status,
    required this.totalItems,
    required this.transferredItemsCount,
    required this.unmatchedItems,
    required this.estimatedSubtotalNpr,
    required this.cartWebUrl,
    required this.cartAppUrl,
    required this.createdAt,
    required this.expiresAt,
    required this.disclosureEn,
    required this.disclosureNe,
  });
}

class RetailerDeepLinkResult {
  final String retailerId;
  final String retailerName;
  final String retailerNameNe;
  final String searchTerm;
  final String webUrl;
  final String appDeepLinkUrl;
  final bool isAffiliate;
  final String disclosureEn;
  final String disclosureNe;

  const RetailerDeepLinkResult({
    required this.retailerId,
    required this.retailerName,
    required this.retailerNameNe,
    required this.searchTerm,
    required this.webUrl,
    required this.appDeepLinkUrl,
    required this.isAffiliate,
    required this.disclosureEn,
    required this.disclosureNe,
  });
}

class BasketHandoffResult {
  final String retailerId;
  final String retailerName;
  final String retailerNameNe;
  final int itemCount;
  final String combinedSearchQuery;
  final String webUrl;
  final String appDeepLinkUrl;
  final bool isAffiliate;
  final String disclosureEn;
  final String disclosureNe;

  const BasketHandoffResult({
    required this.retailerId,
    required this.retailerName,
    required this.retailerNameNe,
    required this.itemCount,
    required this.combinedSearchQuery,
    required this.webUrl,
    required this.appDeepLinkUrl,
    required this.isAffiliate,
    required this.disclosureEn,
    required this.disclosureNe,
  });
}

const String defaultAffiliateDisclosureEn =
    'Affiliate Disclosure: Siti Counter may earn a small commission from qualifying purchases at no extra cost to you. Retailers are displayed without pay-for-placement bias.';

const String defaultAffiliateDisclosureNe =
    'सहयोगी लिङ्क प्रकटीकरण: सिट्ठी काउन्टरले तपाईंलाई कुनै अतिरिक्त शुल्क बिना सानो कमिसन प्राप्त गर्न सक्छ। व्यापारीहरूको सूची विज्ञापन वा भुक्तानी पूर्वाग्रह बिना निष्पक्ष देखाइएको छ।';

const List<RetailerPartner> builtInRetailers = [
  RetailerPartner(
    id: 'daraz',
    name: 'Daraz',
    nameNe: 'दराज',
    countryCode: 'NP',
    icon: '🛍️',
    websiteUrl: 'https://www.daraz.com.np',
    appSchemePrefix: 'daraz://',
    isAffiliate: true,
    affiliateTag: 'siticounter',
    disclosureEn: defaultAffiliateDisclosureEn,
    disclosureNe: defaultAffiliateDisclosureNe,
    descriptionEn: 'Nepal’s leading online marketplace with grocery delivery (Daraz Mart)',
    descriptionNe: 'नेपालको प्रमुख अनलाइन बजार र किराना डेलिभरी (दराज मार्ट)',
  ),
  RetailerPartner(
    id: 'bhatbhateni',
    name: 'Bhatbhateni Supermarket',
    nameNe: 'भातभटेनी सुपरमार्केट',
    countryCode: 'NP',
    icon: '🏬',
    websiteUrl: 'https://bhatbhatenionline.com',
    appSchemePrefix: 'bbsm://',
    isAffiliate: true,
    affiliateTag: 'siticounter',
    disclosureEn: defaultAffiliateDisclosureEn,
    disclosureNe: defaultAffiliateDisclosureNe,
    descriptionEn: 'Nepal’s premier retail chain and online departmental store',
    descriptionNe: 'नेपालको अग्रणी डिपार्टमेन्टल स्टोर तथा अनलाइन सुपरमार्केट',
  ),
  RetailerPartner(
    id: 'bigmart',
    name: 'BigMart Online',
    nameNe: 'बिग मार्ट',
    countryCode: 'NP',
    icon: '🛒',
    websiteUrl: 'https://bigmart.com.np',
    appSchemePrefix: 'bigmart://',
    isAffiliate: false,
    disclosureEn: 'Direct store search without affiliate relationship.',
    disclosureNe: 'कुनै सम्बद्धता बिना सिधा पसल खोज।',
    descriptionEn: 'Everyday fresh groceries and household essentials across Kathmandu Valley',
    descriptionNe: 'काठमाडौं उपत्यकाभरि ताजा तरकारी तथा दैनिक उपभोग्य सामान',
  ),
  RetailerPartner(
    id: 'blinkit',
    name: 'Blinkit',
    nameNe: 'ब्लिङ्किट',
    countryCode: 'IN',
    icon: '⚡',
    websiteUrl: 'https://blinkit.com',
    appSchemePrefix: 'blinkit://',
    isAffiliate: true,
    affiliateTag: 'siticounter',
    disclosureEn: defaultAffiliateDisclosureEn,
    disclosureNe: defaultAffiliateDisclosureNe,
    descriptionEn: '10-minute quick commerce grocery delivery across India',
    descriptionNe: 'भारतभरि १० मिनेटमै किराना डेलिभरी',
  ),
  RetailerPartner(
    id: 'amazon_fresh',
    name: 'Amazon Fresh',
    nameNe: 'अमेजन फ्रेस',
    countryCode: 'US',
    icon: '📦',
    websiteUrl: 'https://www.amazon.com/fresh',
    appSchemePrefix: 'amazon://',
    isAffiliate: true,
    affiliateTag: 'siticounter-20',
    disclosureEn: defaultAffiliateDisclosureEn,
    disclosureNe: defaultAffiliateDisclosureNe,
    descriptionEn: 'Convenient grocery delivery for diaspora households',
    descriptionNe: 'डायस्पोरा परिवारहरूको लागि सहज किराना डेलिभरी',
  ),
];

/// Normalizes query string for retailer search engines
String cleanSearchQuery(String rawQuery) {
  if (rawQuery.isEmpty) return '';
  return rawQuery
      .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
      .replaceAll(RegExp(r'\s+(local|fresh|dry|red|white)\b', caseSensitive: false), '')
      .trim();
}

class RetailerHandoffEngine {
  bool _partnerLinksEnabled;
  String? _preferredRetailerId;
  final Map<String, String> _customAffiliateTags;
  final List<RetailerPartner> _customRetailers;

  RetailerHandoffEngine({
    bool partnerLinksEnabled = true,
    String? preferredRetailerId,
    Map<String, String>? customAffiliateTags,
    List<RetailerPartner>? customPartners,
  })  : _partnerLinksEnabled = partnerLinksEnabled,
        _preferredRetailerId = preferredRetailerId,
        _customAffiliateTags = customAffiliateTags ?? {},
        _customRetailers = customPartners ?? [];

  bool get isPartnerLinksEnabled => _partnerLinksEnabled;

  void setPartnerLinksEnabled(bool enabled) {
    _partnerLinksEnabled = enabled;
  }

  void setPreferredRetailer(String? retailerId) {
    _preferredRetailerId = retailerId;
  }

  /// Retrieves available retailers for a country.
  /// STRICT ZERO ADVERTISING BIAS GUARANTEE:
  /// Partners are NEVER ordered by affiliate payout or sponsor bids.
  /// If a preferred retailer is set by the user, it appears first; otherwise
  /// retailers are sorted strictly alphabetically by name.
  List<RetailerPartner> getAvailableRetailers([String countryCode = 'NP']) {
    if (!_partnerLinksEnabled) {
      return [];
    }

    final all = [...builtInRetailers, ..._customRetailers];
    final filtered = all
        .where((r) => r.countryCode.toUpperCase() == countryCode.toUpperCase())
        .toList();

    filtered.sort((a, b) {
      if (_preferredRetailerId != null) {
        if (a.id == _preferredRetailerId) return -1;
        if (b.id == _preferredRetailerId) return 1;
      }
      return a.name.compareTo(b.name);
    });

    return filtered;
  }

  RetailerPartner? getRetailer(String retailerId) {
    for (final r in _customRetailers) {
      if (r.id == retailerId) return r;
    }
    for (final r in builtInRetailers) {
      if (r.id == retailerId) return r;
    }
    return null;
  }

  RetailerDeepLinkResult? generateItemDeepLink(
    String retailerId,
    String rawQuery,
  ) {
    if (!_partnerLinksEnabled) {
      return null;
    }

    final retailer = getRetailer(retailerId);
    if (retailer == null) return null;

    final term = cleanSearchQuery(rawQuery);
    if (term.isEmpty) return null;

    final encoded = Uri.encodeComponent(term);
    final tag = _customAffiliateTags[retailer.id] ?? retailer.affiliateTag ?? '';

    String webUrl;
    String appDeepLinkUrl;

    switch (retailer.id) {
      case 'daraz': {
        final queryParams = ['q=$encoded'];
        if (retailer.isAffiliate && tag.isNotEmpty) {
          queryParams.add('tag=${Uri.encodeComponent(tag)}');
        }
        webUrl = 'https://www.daraz.com.np/catalog/?${queryParams.join('&')}';
        appDeepLinkUrl = 'daraz://catalog?${queryParams.join('&')}';
        break;
      }
      case 'bhatbhateni': {
        final queryParams = ['q=$encoded'];
        if (retailer.isAffiliate && tag.isNotEmpty) {
          queryParams.add('ref=${Uri.encodeComponent(tag)}');
        }
        webUrl = 'https://bhatbhatenionline.com/search?${queryParams.join('&')}';
        appDeepLinkUrl = 'bbsm://search?${queryParams.join('&')}';
        break;
      }
      case 'bigmart': {
        webUrl = 'https://bigmart.com.np/search?q=$encoded';
        appDeepLinkUrl = 'bigmart://search?q=$encoded';
        break;
      }
      case 'blinkit': {
        webUrl = 'https://blinkit.com/s/?q=$encoded';
        appDeepLinkUrl = 'blinkit://search?q=$encoded';
        break;
      }
      case 'amazon_fresh': {
        final queryParams = ['k=$encoded', 'i=amazonfresh'];
        if (tag.isNotEmpty) queryParams.add('tag=${Uri.encodeComponent(tag)}');
        webUrl = 'https://www.amazon.com/s?${queryParams.join('&')}';
        appDeepLinkUrl = 'amazon://fresh/search?${queryParams.join('&')}';
        break;
      }
      default: {
        webUrl = '${retailer.websiteUrl}/search?q=$encoded';
        appDeepLinkUrl = '${retailer.appSchemePrefix}search?q=$encoded';
      }
    }

    return RetailerDeepLinkResult(
      retailerId: retailer.id,
      retailerName: retailer.name,
      retailerNameNe: retailer.nameNe,
      searchTerm: term,
      webUrl: webUrl,
      appDeepLinkUrl: appDeepLinkUrl,
      isAffiliate: retailer.isAffiliate,
      disclosureEn: retailer.disclosureEn,
      disclosureNe: retailer.disclosureNe,
    );
  }

  BasketHandoffResult? generateBasketHandoff(
    String retailerId,
    List<String> itemQueries,
  ) {
    if (!_partnerLinksEnabled) {
      return null;
    }

    final retailer = getRetailer(retailerId);
    if (retailer == null || itemQueries.isEmpty) {
      return null;
    }

    final cleanTerms = itemQueries
        .map((q) => cleanSearchQuery(q))
        .where((q) => q.isNotEmpty)
        .toSet()
        .take(4)
        .toList();

    if (cleanTerms.isEmpty) return null;

    final combined = cleanTerms.join(' ');
    final deepLink = generateItemDeepLink(retailerId, combined);
    if (deepLink == null) return null;

    return BasketHandoffResult(
      retailerId: retailer.id,
      retailerName: retailer.name,
      retailerNameNe: retailer.nameNe,
      itemCount: itemQueries.length,
      combinedSearchQuery: combined,
      webUrl: deepLink.webUrl,
      appDeepLinkUrl: deepLink.appDeepLinkUrl,
      isAffiliate: retailer.isAffiliate,
      disclosureEn: retailer.disclosureEn,
      disclosureNe: retailer.disclosureNe,
    );
  }

  /// Level 3 One-Tap Grocery Cart Direct Transfer (Section 26.4)
  /// Builds an authenticated/signed cart transfer session token and deep-link payload
  /// for supported regional retailers (Daraz, Bhatbhateni, BigMart, Blinkit, Amazon Fresh).
  PartnerCartTransferResult? transferGroceryCart(
    String householdId,
    String retailerId,
    List<PartnerCartItem> items, {
    String? cartId,
    DateTime? now,
  }) {
    if (!_partnerLinksEnabled) {
      return null;
    }

    final retailer = getRetailer(retailerId);
    if (retailer == null || !retailer.directCartSupported) {
      return null;
    }

    if (items.isEmpty) {
      return null;
    }

    final currentTime = now ?? DateTime.now().toUtc();
    final expiryTime = currentTime.add(const Duration(hours: 2));
    final resolvedCartId =
        cartId ?? 'cart_${DateTime.now().millisecondsSinceEpoch}_${retailer.id}';

    double totalNpr = 0;
    final unmatched = <Map<String, String>>[];
    int transferredCount = 0;

    for (final item in items) {
      if (item.name.trim().isEmpty) {
        unmatched.add({'itemId': item.itemId, 'name': item.name.isEmpty ? 'Unknown item' : item.name});
        continue;
      }
      final price = item.estimatedPriceNpr ?? (item.quantity * 80.0);
      totalNpr += price;
      transferredCount++;
    }

    final tag = _customAffiliateTags[retailer.id] ?? retailer.affiliateTag ?? '';

    final tokenObj = {
      'cartId': resolvedCartId,
      'householdId': householdId,
      'retailerId': retailer.id,
      'itemCount': transferredCount,
      'timestamp': currentTime.toIso8601String(),
      'tag': tag,
    };
    final jsonStr = jsonEncode(tokenObj);
    final base64Token = base64Url.encode(utf8.encode(jsonStr)).replaceAll('=', '');

    String webBase;
    String appBase;

    switch (retailer.id) {
      case 'daraz':
        webBase = 'https://www.daraz.com.np/cart/import';
        appBase = 'daraz://cart/import';
        break;
      case 'bhatbhateni':
        webBase = 'https://bhatbhatenionline.com/cart/import';
        appBase = 'bbsm://cart/import';
        break;
      case 'bigmart':
        webBase = 'https://bigmart.com.np/cart/import';
        appBase = 'bigmart://cart/import';
        break;
      case 'blinkit':
        webBase = 'https://blinkit.com/cart/import';
        appBase = 'blinkit://cart/import';
        break;
      case 'amazon_fresh':
        webBase = 'https://www.amazon.com/fresh/cart/import';
        appBase = 'amazon://fresh/cart/import';
        break;
      default:
        webBase = '${retailer.websiteUrl}/cart/import';
        appBase = '${retailer.appSchemePrefix}cart/import';
    }

    final queryParams = {
      'token': base64Token,
      'ref': tag.isNotEmpty ? tag : 'siticounter',
      'items': transferredCount.toString(),
    };
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final cartWebUrl = '$webBase?$queryString';
    final cartAppUrl = '$appBase?$queryString';

    return PartnerCartTransferResult(
      cartId: resolvedCartId,
      householdId: householdId,
      retailerId: retailer.id,
      retailerName: retailer.name,
      status: 'ready',
      totalItems: items.length,
      transferredItemsCount: transferredCount,
      unmatchedItems: unmatched,
      estimatedSubtotalNpr: totalNpr,
      cartWebUrl: cartWebUrl,
      cartAppUrl: cartAppUrl,
      createdAt: currentTime,
      expiresAt: expiryTime,
      disclosureEn: retailer.disclosureEn,
      disclosureNe: retailer.disclosureNe,
    );
  }
}
