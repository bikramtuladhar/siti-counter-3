import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'subscription_service.dart';

/// Paywall screen presenting the Annual Household Subscription with PPP pricing
class PaywallScreen extends StatefulWidget {
  final SubscriptionService subscriptionService;
  final String currentLanguage;
  final VoidCallback? onSubscriptionSuccess;

  const PaywallScreen({
    super.key,
    required this.subscriptionService,
    this.currentLanguage = 'ne',
    this.onSubscriptionSuccess,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool get _isNepali => widget.currentLanguage == 'ne';
  SubscriptionService get _subService => widget.subscriptionService;

  @override
  void initState() {
    super.initState();
    _subService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _subService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSubscribe() async {
    final success = await _subService.purchaseAnnualSubscription();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNepali
                ? 'बधाई छ! वार्षिक पारिवारिक सदस्यता सफलतापूर्वक सक्रिय भयो।'
                : 'Congratulations! Annual Household Plan is now active.',
          ),
          backgroundColor: SitiColors.freshGreen,
        ),
      );
      widget.onSubscriptionSuccess?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNepali ? 'खरिद प्रक्रिया पूरा हुन सकेन।' : 'Purchase could not be completed.',
          ),
          backgroundColor: SitiColors.alert,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    final success = await _subService.restorePurchases();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNepali ? 'पहिलेको खरिद पुनर्स्थापना गरियो।' : 'Purchases successfully restored.',
          ),
          backgroundColor: SitiColors.freshGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNepali ? 'कुनै सक्रिय सदस्यता भेटिएन।' : 'No active subscription found.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _subService.planPrice;
    final isPremium = _subService.isPremium;

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        title: Text(
          _isNepali ? 'सिट्ठी काउन्टर प्रिमियम' : 'Siti Counter Premium',
          style: NepaliTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _subService.isLoading ? null : _handleRestore,
            child: Text(
              _isNepali ? 'पुनर्स्थापना' : 'Restore',
              style: const TextStyle(fontWeight: FontWeight.w700, color: SitiColors.terracotta),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Crown Badge
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFF57C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Text(
              _isNepali
                  ? 'सम्पूर्ण परिवारको लागि एक सदस्यता'
                  : 'One Plan for Your Entire Household',
              textAlign: TextAlign.center,
              style: NepaliTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w900,
                color: SitiColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isNepali
                  ? 'असीमित एआई, कालिमाटी बजार भाउ र पारिवारिक कुकबुक'
                  : 'Unlimited AI, live Kalimati market prices & family cookbook',
              textAlign: TextAlign.center,
              style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),

            // PPP Pricing Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFFFB300), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Text(
                        _isNepali ? 'वार्षिक पारिवारिक योजना (PPP Pricing)' : 'Annual Household Plan',
                        style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isNepali ? price.formattedPriceNe : price.formattedPriceEn,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: SitiColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isNepali
                          ? '७ दिन निःशुल्क परीक्षण, त्यसपछि प्रतिवर्ष मात्र'
                          : '7-day free trial, then billed annually. Cancel anytime.',
                      textAlign: TextAlign.center,
                      style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Features Checklist Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isNepali ? 'प्रिमियममा के समावेश छ?' : 'What is included in Premium?',
                      style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    _buildFeatureRow(
                      icon: Icons.psychology_rounded,
                      title: _isNepali ? 'असीमित एआई भान्सा सहायक' : 'Unlimited AI Kitchen Assistant',
                      subtitle: _isNepali
                          ? 'पकाउने तरिका, परिकार विकल्प र पोषण सल्लाह'
                          : 'Contextual recipe guidance & nutritional advice',
                    ),
                    _buildFeatureRow(
                      icon: Icons.storefront_rounded,
                      title: _isNepali ? 'कालिमाटी दैनिक बजार भाउ' : 'Live Kalimati Market Prices',
                      subtitle: _isNepali
                          ? 'दैनिक तरकारी र फलफूलको थोक/खुद्रा मूल्य सूची'
                          : 'Daily vegetable & fruit wholesale price boards',
                    ),
                    _buildFeatureRow(
                      icon: Icons.celebration_rounded,
                      title: _isNepali ? 'पार्टी मोड भोज प्लानर (१५-५० जना)' : 'Party Mode Bhoj Planner (15–50 guests)',
                      subtitle: _isNepali
                          ? 'चाडपर्व र भोजका लागि ठूलो परिमाण र चुल्हो व्यवस्थापन'
                          : 'Scales quantities, vessels & burners for large gatherings',
                    ),
                    _buildFeatureRow(
                      icon: Icons.menu_book_rounded,
                      title: _isNepali ? 'पारिवारिक डिजिटल कुकबुक' : 'Family Shared Cookbook',
                      subtitle: _isNepali
                          ? 'हजुरआमाका परिकार र पुस्तैनी स्वाद सुरक्षित राख्नुहोस्'
                          : 'Archive grandma’s secret heirloom recipes securely',
                    ),
                    _buildFeatureRow(
                      icon: Icons.devices_rounded,
                      title: _isNepali ? 'सम्पूर्ण परिवारका फोनहरूमा सक्रिय' : 'Covers Entire Household',
                      subtitle: _isNepali
                          ? 'एक सदस्यताले परिवारका सबै सदस्यका फोनमा चल्छ'
                          : 'Single subscription covers all family devices',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Free Tier Guarantee Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.volunteer_activism_rounded, color: Colors.blue.shade800, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isNepali
                          ? 'प्रतिबद्धता: सिट्ठी काउन्टर, आधारभूत रेसिपी र साप्ताहिक प्लान सधैं १००% निःशुल्क रहनेछ।'
                          : 'Our Guarantee: Whistle counting, local recipes, and weekly meal planning remain 100% free forever.',
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Offline Entitlement Active Indicator (if already subscribed)
            if (isPremium) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isNepali
                            ? 'तपाईंको प्रिमियम सदस्यता सक्रिय छ (अफलाइन मान्य टोकन)।'
                            : 'Premium active (Cryptographically signed offline token).',
                        style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Subscribe Button
            ElevatedButton(
              onPressed: _subService.isLoading ? null : _handleSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium ? SitiColors.freshGreen : SitiColors.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: _subService.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      isPremium
                          ? (_isNepali ? 'सदस्यता सक्रिय छ' : 'Subscription Active')
                          : (_isNepali ? '७ दिन निःशुल्क सुरु गर्नुहोस्' : 'Start 7-Day Free Trial'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(height: 12),

            // Small Disclaimers
            Text(
              _isNepali
                  ? 'सदस्यता अवधि सकिनु २४ घण्टा अगाडि रद्द गर्न सकिन्छ। सर्तहरू र गोपनीयता नीति।'
                  : 'Renews automatically each year. Cancel anytime in store settings. Terms & Privacy.',
              textAlign: TextAlign.center,
              style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: SitiColors.terracotta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: SitiColors.terracotta, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  subtitle,
                  style: NepaliTypography.labelSmall.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
