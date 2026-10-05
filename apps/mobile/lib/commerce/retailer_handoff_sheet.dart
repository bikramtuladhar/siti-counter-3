import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import 'retailer_handoff_service.dart';

/// Modal bottom sheet presenting retailer deep-linking options (Daraz, Bhatbhateni, BigMart)
/// with full affiliate disclosure, zero rank bias, and opt-out controls.
class RetailerHandoffSheet extends StatefulWidget {
  final RetailerHandoffService retailerService;
  final String? singleItemName;
  final List<String>? basketItemNames;
  final List<PartnerCartItem>? cartItems;
  final String householdId;
  final String currentLanguage;
  final void Function(String url, bool isAppDeepLink)? onLaunchUrl;
  final void Function(PartnerCartTransferResult result)? onDirectCartTransfer;

  const RetailerHandoffSheet({
    super.key,
    required this.retailerService,
    this.singleItemName,
    this.basketItemNames,
    this.cartItems,
    this.householdId = 'hh_local_default',
    this.currentLanguage = 'ne',
    this.onLaunchUrl,
    this.onDirectCartTransfer,
  });

  static Future<void> show({
    required BuildContext context,
    required RetailerHandoffService retailerService,
    String? singleItemName,
    List<String>? basketItemNames,
    List<PartnerCartItem>? cartItems,
    String householdId = 'hh_local_default',
    String currentLanguage = 'ne',
    void Function(String url, bool isAppDeepLink)? onLaunchUrl,
    void Function(PartnerCartTransferResult result)? onDirectCartTransfer,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RetailerHandoffSheet(
        retailerService: retailerService,
        singleItemName: singleItemName,
        basketItemNames: basketItemNames,
        cartItems: cartItems,
        householdId: householdId,
        currentLanguage: currentLanguage,
        onLaunchUrl: onLaunchUrl,
        onDirectCartTransfer: onDirectCartTransfer,
      ),
    );
  }

  @override
  State<RetailerHandoffSheet> createState() => _RetailerHandoffSheetState();
}

class _RetailerHandoffSheetState extends State<RetailerHandoffSheet> {
  bool get _isNepali => widget.currentLanguage == 'ne';
  RetailerHandoffService get _service => widget.retailerService;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _handleLaunch(String url, bool isAppScheme) {
    _service.launchLink(url);
    widget.onLaunchUrl?.call(url, isAppScheme);
    Navigator.of(context).pop();
  }

  List<PartnerCartItem> get _resolvedCartItems {
    if (widget.cartItems != null && widget.cartItems!.isNotEmpty) {
      return widget.cartItems!;
    }
    if (widget.basketItemNames != null && widget.basketItemNames!.isNotEmpty) {
      return widget.basketItemNames!
          .asMap()
          .entries
          .map((e) => PartnerCartItem(
                itemId: 'item_${e.key}',
                name: e.value,
                quantity: 1,
                unit: 'pkt',
              ))
          .toList();
    }
    if (widget.singleItemName != null && widget.singleItemName!.isNotEmpty) {
      return [
        PartnerCartItem(
          itemId: 'item_single',
          name: widget.singleItemName!,
          quantity: 1,
          unit: 'pkt',
        )
      ];
    }
    return [];
  }

  void _handleDirectCartTransfer(RetailerPartner retailer) {
    final transferResult = _service.transferGroceryCart(
      householdId: widget.householdId,
      retailerId: retailer.id,
      items: _resolvedCartItems,
    );
    if (transferResult != null) {
      widget.onDirectCartTransfer?.call(transferResult);
      _handleLaunch(transferResult.cartAppUrl, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBasket = widget.basketItemNames != null && widget.basketItemNames!.isNotEmpty;
    final title = isBasket
        ? (_isNepali
            ? '${widget.basketItemNames!.length} सामग्रीहरू अनलाइन अर्डर'
            : 'Order ${widget.basketItemNames!.length} Items Online')
        : (_isNepali
            ? '${widget.singleItemName ?? "सामग्री"} अनलाइन खोज्नुहोस्'
            : 'Search ${widget.singleItemName ?? "Item"} Online');

    final retailers = _service.availableRetailers;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SitiColors.terracotta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: SitiColors.terracotta, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: NepaliTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _isNepali
                          ? 'नेपालका प्रमुख अनलाइन डेलिभरी पार्टनरहरू'
                          : 'Regional Online Delivery Partners',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('close_retailer_sheet_btn'),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Affiliate Disclosure & Zero Bias Banner (Section 9.5)
          Container(
            key: const Key('affiliate_disclosure_banner'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade800, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali
                            ? 'पारदर्शी प्रकटीकरण (Affiliate Disclosure)'
                            : 'Affiliate Transparency Notice',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isNepali
                            ? 'सिट्ठी काउन्टरले केही पार्टनरहरूबाट सानो कमिसन प्राप्त गर्न सक्छ (तपाईंलाई कुनै अतिरिक्त शुल्क लाग्दैन)। व्यापारीहरू कुनै विज्ञापन वा भुक्तानी पूर्वाग्रह बिना निष्पक्ष देखाइएका छन्।'
                            : 'Siti Counter may earn a small commission from qualifying partner links at no extra cost to you. Retailers are presented without advertising rank bias.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // If partner links disabled by user
          if (!_service.partnerLinksEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _isNepali
                      ? 'तपाईंले अनलाइन किनमेल लिङ्कहरू बन्द गर्नुभएको छ (हाट बजार मोड)।'
                      : 'Shopping partner links are disabled in your preferences.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            ),
          ] else if (retailers.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _isNepali
                      ? 'यस क्षेत्रको लागि कुनै अनलाइन पार्टनर उपलब्ध छैन।'
                      : 'No online retailers available for this country.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            // Retailer Partner Cards
            ...retailers.map((r) => _buildRetailerCard(r, isBasket)),
          ],

          const SizedBox(height: 12),
          const Divider(),

          // Privacy Option to Disable Partner Links Entirely (Section 26.4)
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              key: const Key('partner_links_toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                _isNepali
                    ? 'अनलाइन किनमेल लिङ्कहरू देखाउनुहोस्'
                    : 'Show Online Shopping Partner Links',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _isNepali
                    ? 'बन्द गर्दा सिट्ठी काउन्टर पूर्ण रूपमा स्थानीय हाट बजार मोडमा चल्नेछ'
                    : 'Turn off for pure local Haat Bazaar / wet market mode',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              value: _service.partnerLinksEnabled,
              activeThumbColor: SitiColors.terracotta,
              onChanged: (val) {
                _service.setPartnerLinksEnabled(val);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRetailerCard(RetailerPartner retailer, bool isBasket) {
    String webUrl = '';
    String appUrl = '';

    if (isBasket && widget.basketItemNames != null) {
      final basketResult = _service.getBasketHandoff(retailer.id, widget.basketItemNames!);
      if (basketResult != null) {
        webUrl = basketResult.webUrl;
        appUrl = basketResult.appDeepLinkUrl;
      }
    } else {
      final itemResult = _service.getItemDeepLink(retailer.id, widget.singleItemName ?? '');
      if (itemResult != null) {
        webUrl = itemResult.webUrl;
        appUrl = itemResult.appDeepLinkUrl;
      }
    }

    return Container(
      key: Key('retailer_card_${retailer.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(retailer.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isNepali ? retailer.nameNe : retailer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (retailer.isAffiliate) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isNepali ? 'पार्टनर' : 'Partner',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _isNepali ? retailer.descriptionNe : retailer.descriptionEn,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (retailer.directCartSupported && _resolvedCartItems.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: Key('btn_direct_cart_transfer_${retailer.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E), // Deep teal
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.bolt, size: 16, color: Colors.amberAccent),
                label: Text(
                  _isNepali ? 'एक-ट्याप कार्ट अर्डर (One-Tap Cart)' : 'One-Tap Cart Checkout',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _handleDirectCartTransfer(retailer),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              // Open in App Button (Deep link)
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('open_app_btn_${retailer.id}'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SitiColors.terracotta),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14, color: SitiColors.terracotta),
                  label: Text(
                    _isNepali ? 'एपमा खोल्नुहोस्' : 'Open in App',
                    style: const TextStyle(fontSize: 12, color: SitiColors.terracotta, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _handleLaunch(appUrl, true),
                ),
              ),
              const SizedBox(width: 8),
              // Open in Web Button
              Expanded(
                child: ElevatedButton.icon(
                  key: Key('open_web_btn_${retailer.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SitiColors.terracotta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.language, size: 14, color: Colors.white),
                  label: Text(
                    _isNepali ? 'वेबमा जानुहोस्' : 'Open Web',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _handleLaunch(webUrl, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
