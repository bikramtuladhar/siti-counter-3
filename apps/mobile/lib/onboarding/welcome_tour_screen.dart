import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'language_toggle.dart';

class TourPageData {
  final String titleNe;
  final String titleEn;
  final String descNe;
  final String descEn;
  final IconData icon;
  final Color accentColor;
  final String badgeText;

  const TourPageData({
    required this.titleNe,
    required this.titleEn,
    required this.descNe,
    required this.descEn,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
  });
}

class WelcomeTourScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final bool preferNepali;

  /// Raised when the user switches language from the tour header, so the coordinator can
  /// keep its preferences in step (the wizard and every later screen read it).
  final ValueChanged<bool>? onLanguageChanged;

  const WelcomeTourScreen({
    super.key,
    required this.onFinish,
    this.preferNepali = true,
    this.onLanguageChanged,
  });

  @override
  State<WelcomeTourScreen> createState() => _WelcomeTourScreenState();
}

class _WelcomeTourScreenState extends State<WelcomeTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// Held locally so the tour re-renders in the chosen language immediately, without a
  /// round trip through the coordinator.
  late bool _preferNepali = widget.preferNepali;

  @override
  void didUpdateWidget(WelcomeTourScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferNepali != widget.preferNepali) {
      _preferNepali = widget.preferNepali;
    }
  }

  void _setLanguage(bool preferNepali) {
    setState(() {
      _preferNepali = preferNepali;
    });
    widget.onLanguageChanged?.call(preferNepali);
  }

  static const List<TourPageData> _pages = [
    TourPageData(
      titleNe: 'सिट्ठी गन्ने झन्झट सधैँका लागि अन्त्य',
      titleEn: 'Never Miss or Miscount a Whistle',
      descNe: 'ध्वनि पहिचान प्रविधि (Acoustic AI) ले प्रेसर कुकरको सिट्ठी आवाज सुनेर आफैँ गन्छ, कोलाहलमा पनि ९७%+ शुद्ध।',
      descEn: 'On-device acoustic classifier counts pressure cooker whistles accurately even amidst exhaust fans and kitchen noise.',
      icon: Icons.hearing_rounded,
      accentColor: SitiColors.terracotta,
      badgeText: 'Acoustic AI',
    ),
    TourPageData(
      titleNe: 'काठमाडौँको उचाइअनुसार ठिक्क पाक्ने',
      titleEn: 'Altitude & Market Unit Ready',
      descNe: '१,४०० मिटर उचाइको पानी उम्लने तापक्रम र पाउ, धार्नी, माना नापमा स्वतः हिसाब मिलाउँछ।',
      descEn: 'Automatic altitude compensation for 1,400m Kathmandu boiling points, paired with pau & dharni unit conversions.',
      icon: Icons.terrain_rounded,
      accentColor: SitiColors.freshGreen,
      badgeText: 'Elevation 1,400m',
    ),
    TourPageData(
      titleNe: '६ ऋतुअनुसार ताजा तरकारी र परिकार',
      titleEn: 'Six Ritus Seasonal Kitchen Planner',
      descNe: 'कालीमाटी बजारमा अहिले जे ताजा र सस्तो पाइन्छ, त्यहीअनुसार हप्ताको खाना योजना बनाउनुहोस्।',
      descEn: 'Plan balanced weekly meals based on what is peaking right now in your local season with zero ingredient waste.',
      icon: Icons.eco_rounded,
      accentColor: Color(0xFFF57F17),
      badgeText: '६ ऋतु (Six Ritus)',
    ),
    TourPageData(
      titleNe: 'परिवारभरिका फोन र ट्याब्लेटमा एकैसाथ',
      titleEn: 'Live Household Sync & Smart Display',
      descNe: 'किचनको ट्याब्लेट, मोबाइल र वेबमा एकै समय प्रत्यक्ष पकाउने स्थिति र सिट्ठी संख्या हेर्नुहोस्।',
      descEn: 'Real-time offline-first sync across household phones, tablets, and web displays with zero setup hassle.',
      icon: Icons.sync_rounded,
      accentColor: Color(0xFF0288D1),
      badgeText: 'Realtime Sync',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: SitiColors.terracotta,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.soup_kitchen_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Siti Counter 3.0',
                            overflow: TextOverflow.ellipsis,
                            style: NepaliTypography.titleMedium.copyWith(
                              color: SitiColors.dark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onFinish,
                    child: Text(
                      _preferNepali ? 'सिधै सुरु गर्नुहोस्' : 'Skip',
                      style: NepaliTypography.labelLarge.copyWith(
                        color: SitiColors.terracotta,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Language switcher: the tour text is bilingual, so let the reader pick before
            // reading rather than after finishing it.
            Center(
              child: LanguageToggle(
                language: _preferNepali
                    ? LanguageToggle.nepali
                    : LanguageToggle.english,
                compact: true,
                onChanged: (code) =>
                    _setLanguage(code == LanguageToggle.nepali),
              ),
            ),
            const SizedBox(height: 8),

            // PageView Tour Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) {
                  setState(() {
                    _currentPage = idx;
                  });
                },
                itemBuilder: (context, idx) {
                  final page = _pages[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Card Visual Graphic
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: page.accentColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              page.icon,
                              size: 72,
                              color: page.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: page.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: page.accentColor,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            page.badgeText,
                            style: NepaliTypography.labelLarge.copyWith(
                              color: page.accentColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          _preferNepali ? page.titleNe : page.titleEn,
                          textAlign: TextAlign.center,
                          style: NepaliTypography.headlineMedium.copyWith(
                            color: SitiColors.dark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Description
                        Text(
                          _preferNepali ? page.descNe : page.descEn,
                          textAlign: TextAlign.center,
                          style: NepaliTypography.bodyLarge.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation & Indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots Indicator
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? SitiColors.terracotta
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Next / Get Started Button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SitiColors.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _pages.length - 1
                              ? (_preferNepali ? 'सुरु गरौँ' : 'Get Started')
                              : (_preferNepali ? 'अर्को' : 'Next'),
                          style: NepaliTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
