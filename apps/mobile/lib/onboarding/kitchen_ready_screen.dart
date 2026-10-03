import 'package:flutter/material.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'onboarding_state.dart';

class KitchenReadyScreen extends StatefulWidget {
  final OnboardingPreferences prefs;
  final VoidCallback onStartCooking;

  const KitchenReadyScreen({
    super.key,
    required this.prefs,
    required this.onStartCooking,
  });

  @override
  State<KitchenReadyScreen> createState() => _KitchenReadyScreenState();
}

class _KitchenReadyScreenState extends State<KitchenReadyScreen> {
  int _demoWhistleCount = 0;
  bool _isSimulatingWhistle = false;

  bool get _isNepali => widget.prefs.language == 'ne';

  void _simulateWhistle() {
    if (_isSimulatingWhistle) return;
    setState(() {
      _isSimulatingWhistle = true;
      _demoWhistleCount++;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isSimulatingWhistle = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 3 Seasonal produce for Bagmati
    final seasonalItems = [
      {'nameNe': 'काउली (फूल गोभी)', 'nameEn': 'Cauliflower', 'badgeNe': 'अहिले सस्तो र ताजा', 'badgeEn': 'Peak Freshness'},
      {'nameNe': 'रायोको साग', 'nameEn': 'Mustard Greens', 'badgeNe': 'स्थानीय उत्पादन', 'badgeEn': 'Local Produce'},
      {'nameNe': 'सेतो मूला', 'nameEn': 'White Radish', 'badgeNe': 'अचारको लागि उत्तम', 'badgeEn': 'Best for Achar'},
    ];

    // 5 Dinner Plan
    final fiveDinners = [
      {'dayNe': 'आइतबार (Day 1)', 'dayEn': 'Sunday (Day 1)', 'mealNe': 'सादा भात, मुसुरो दाल, आलु काउली', 'mealEn': 'Sada Bhat, Musuro Dal, Aloo Gobi'},
      {'dayNe': 'सोमबार (Day 2)', 'dayEn': 'Monday (Day 2)', 'mealNe': 'जिम्बु झानेको कालो दाल, रायोको साग', 'mealEn': 'Kalo Dal with Jimbu, Rayo Saag'},
      {'dayNe': 'मङ्गलबार (Day 3)', 'dayEn': 'Tuesday (Day 3)', 'mealNe': 'आलु तामा बोडी र गोलभेडाको अचार', 'mealEn': 'Aloo Tama Bodi, Tomato Timur Achar'},
      {'dayNe': 'बुधबार (Day 4)', 'dayEn': 'Wednesday (Day 4)', 'mealNe': 'चना आलुको रसिलो, फुल्का रोटी', 'mealEn': 'Chana Aloo Curry, Soft Phulka Roti'},
      {'dayNe': 'बिहीबार (Day 5)', 'dayEn': 'Thursday (Day 5)', 'mealNe': 'प्रेसर कुकर खिचडी र घिउ-पाउ', 'mealEn': 'Pressure Cooker Khichadi with Ghee'},
    ];

    final groceryEstimateFormatted = NepaliCalendar.formatLakhCrore(
      1250,
      preferDevanagari: _isNepali,
      includeCurrency: true,
    );

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: SitiColors.freshGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: SitiColors.freshGreen,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _isNepali ? 'तपाईंको किचन तयार भयो!' : 'Your Kitchen is Ready!',
                  textAlign: TextAlign.center,
                  style: NepaliTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _isNepali
                      ? 'बागमती प्रदेश (१,४०० मिटर) • ${widget.prefs.totalHouseholdSize} जनाको परिवार'
                      : 'Bagmati Province (1,400m) • ${widget.prefs.totalHouseholdSize} family members',
                  style: NepaliTypography.bodyMedium.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 1. Fresh Near You
              Text(
                _isNepali ? '१. अहिलेको ऋतुमा ताजा पाइने तरकारी' : '1. Fresh in Season Near You',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.terracotta,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: seasonalItems.map((item) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isNepali ? item['nameNe']! : item['nameEn']!,
                            style: NepaliTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isNepali ? item['badgeNe']! : item['badgeEn']!,
                            style: NepaliTypography.bodyMedium.copyWith(
                              fontSize: 11,
                              color: SitiColors.freshGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 2. Auto-Planned 5-Dinner Week
              Text(
                _isNepali ? '२. पहिलो ५ दिनको बेलुकीको खाना योजना' : '2. Auto-Planned First 5 Dinners',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.terracotta,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: fiveDinners.map((meal) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.restaurant_menu_rounded, size: 20, color: SitiColors.terracotta),
                      title: Text(
                        _isNepali ? meal['dayNe']! : meal['dayEn']!,
                        style: NepaliTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: SitiColors.dark,
                        ),
                      ),
                      subtitle: Text(
                        _isNepali ? meal['mealNe']! : meal['mealEn']!,
                        style: NepaliTypography.bodyLarge.copyWith(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Initial Grocery Market Estimate
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SitiColors.freshGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SitiColors.freshGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isNepali ? 'पहिलो हप्ताको बजार अनुमान' : 'First Week Grocery Estimate',
                            style: NepaliTypography.labelLarge.copyWith(
                              color: SitiColors.freshGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isNepali ? '१२ वटा ताजा सामग्री • शून्य खेर' : '12 local items • Zero waste',
                            style: NepaliTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      groceryEstimateFormatted,
                      style: NepaliTypography.headlineMedium.copyWith(
                        color: SitiColors.freshGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Interactive 10-Second Whistle Counter Demo
              Text(
                _isNepali ? '३. सिट्ठी काउन्टर प्रत्यक्ष परीक्षण' : '3. Test Whistle Counter Live',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.terracotta,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    // Dial Counter Display
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _isSimulatingWhistle
                            ? SitiColors.warning.withValues(alpha: 0.25)
                            : SitiColors.terracotta.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isSimulatingWhistle ? SitiColors.warning : SitiColors.terracotta,
                          width: _isSimulatingWhistle ? 3 : 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _isNepali
                              ? NepaliCalendar.toDevanagariDigits(_demoWhistleCount)
                              : '$_demoWhistleCount',
                          style: NepaliTypography.displayLarge.copyWith(
                            color: SitiColors.terracotta,
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSimulatingWhistle
                                ? (_isNepali ? 'सिट्ठी बज्यो! (Whistle!)' : 'Whistle Detected!')
                                : (_isNepali ? 'परीक्षण सिट्ठी बजाउनुहोस्' : 'Simulate Whistle Sound'),
                            style: NepaliTypography.titleMedium.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _isSimulatingWhistle ? SitiColors.warning : SitiColors.dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isNepali
                                ? 'बटन थिचेर सिट्ठी पहिचानको प्रतिक्रिया हेर्नुहोस्।'
                                : 'Tap the button to test instant acoustic visual reaction.',
                            style: NepaliTypography.bodyMedium.copyWith(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _simulateWhistle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SitiColors.terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _isNepali ? 'सिट्ठी' : 'Whistle',
                            style: NepaliTypography.labelLarge.copyWith(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Final CTA: Guest Mode Landing Without Mandatory Registration
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onStartCooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SitiColors.terracotta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.soup_kitchen_rounded, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _isNepali
                              ? 'किचन सुरु गर्नुहोस् (खाता बिना)'
                              : 'Start Cooking as Guest',
                          style: NepaliTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _isNepali
                      ? 'कुनै दर्ता वा फोन नम्बर आवश्यक छैन • १००% अफलाइन चल्ने'
                      : 'No registration or phone number required • 100% offline-first',
                  style: NepaliTypography.bodyMedium.copyWith(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
