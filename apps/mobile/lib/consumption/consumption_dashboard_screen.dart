import 'package:flutter/material.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'consumption_repository.dart';
import 'family_nutrition_screen.dart';
import 'household_vessel_calibration_dialog.dart';
import 'quick_add_outside_food_dialog.dart';
import 'post_meal_usual_dialog.dart';

/// Full consumption & non-shaming household nutrition dashboard (Section 11).
class ConsumptionDashboardScreen extends StatefulWidget {
  final String currentLanguage;
  final ConsumptionRepository repository;
  final WeeklyHouseholdSummary? initialSummary;
  final List<MemberDietaryProfile>? initialMembers;

  const ConsumptionDashboardScreen({
    super.key,
    required this.currentLanguage,
    required this.repository,
    this.initialSummary,
    this.initialMembers,
  });

  @override
  State<ConsumptionDashboardScreen> createState() => _ConsumptionDashboardScreenState();
}

class _ConsumptionDashboardScreenState extends State<ConsumptionDashboardScreen> {
  WeeklyHouseholdSummary? _summary;
  List<MemberDietaryProfile> _members = [];
  HouseholdVesselProfile _vesselProfile = const HouseholdVesselProfile();
  bool _loading = true;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary;
      _members = widget.initialMembers ?? [];
      _loading = false;
    }
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

    final members = await widget.repository.getMembers();
    final vesselProf = await widget.repository.getVesselProfile();
    final summary = await widget.repository.getWeeklySummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
    );

    if (mounted) {
      setState(() {
        _members = members;
        _vesselProfile = vesselProf;
        _summary = summary;
        _loading = false;
      });
    }
  }

  void _openCalibrationDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => HouseholdVesselCalibrationDialog(
        currentLanguage: widget.currentLanguage,
        repository: widget.repository,
        onUpdated: (prof) {
          setState(() {
            _vesselProfile = prof;
          });
          _loadDashboardData();
        },
      ),
    );
  }

  void _openQuickAddDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => QuickAddOutsideFoodDialog(
        currentLanguage: widget.currentLanguage,
        repository: widget.repository,
        members: _members,
        onAdded: (_) => _loadDashboardData(),
      ),
    );
  }

  void _simulatePostMealPrompt() {
    showDialog<void>(
      context: context,
      builder: (ctx) => PostMealUsualDialog(
        recipeId: 'dal-bhat-tarkari',
        recipeTitle: _isNepali ? 'दाल-भात र तरकारी' : 'Dal Bhat Tarkari',
        mealSlot: 'evening-dal-bhat',
        currentLanguage: widget.currentLanguage,
        repository: widget.repository,
        members: _members,
        vesselProfile: _vesselProfile,
        batchYieldGrams: 1600.0,
        leftoverGrams: 200.0,
        onLogged: (_) => _loadDashboardData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNepali ? 'खाना खपत' : 'Consumption')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _summary;

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isNepali ? 'पारिवारिक खाना र पोषण' : 'Household Consumption',
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('family_nutrition_action'),
            icon: const Icon(Icons.eco_rounded, color: SitiColors.freshGreen),
            tooltip: _isNepali ? 'परिवारको पोषण' : 'Family Nutrition',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FamilyNutritionScreen(
                  currentLanguage: widget.currentLanguage,
                  repository: widget.repository,
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('calibrate_vessels_action'),
            icon: const Icon(Icons.straighten_rounded, color: SitiColors.terracotta),
            tooltip: 'Calibrate Vessels',
            onPressed: _openCalibrationDialog,
          ),
          IconButton(
            key: const Key('quick_add_snack_action'),
            icon: const Icon(Icons.fastfood_rounded, color: SitiColors.terracotta),
            tooltip: 'Quick-Add Snack',
            onPressed: _openQuickAddDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gentle Non-Shaming Household Rhythm Card
              _buildHouseholdRhythmCard(summary),
              const SizedBox(height: 16),

              // Quick Log Action Banner
              _buildQuickLogBanner(),
              const SizedBox(height: 20),

              // Family Members Breakdown
              Text(
                _isNepali ? 'सदस्यहरूको खाना लय' : 'Member Consumption Rhythm',
                style: NepaliTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.dark,
                ),
              ),
              const SizedBox(height: 10),

              if (summary != null)
                ...summary.memberSummaries.map((m) => _buildMemberCard(m)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHouseholdRhythmCard(WeeklyHouseholdSummary? summary) {
    final compliance = summary?.usualComplianceRate.round() ?? 100;
    final mealsCount = summary?.totalMealsLogged ?? 0;
    final snacksCount = summary?.totalOutsideSnacksLogged ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SitiColors.freshGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded, color: SitiColors.freshGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isNepali ? 'हप्ताको शान्त लय (Calm Rhythm)' : 'Weekly Calm Rhythm',
                  style: NepaliTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$compliance% सामान्य',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Gentle feedback string
          Text(
            summary?.gentleFamilyFeedback ??
                (_isNepali
                    ? 'तपाईंको परिवारले यस हप्ता ताजा दाल-भात उपभोग गरेको छ।'
                    : 'Your household enjoyed wholesome home-cooked meals this week.'),
            style: NepaliTypography.bodyMedium.copyWith(
              color: SitiColors.dark,
              height: 1.4,
            ),
          ),
          const Divider(height: 24),

          // Metric Counters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn(
                label: _isNepali ? 'घरको खाना' : 'Home Meals',
                value: '$mealsCount',
                color: SitiColors.freshGreen,
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade200),
              _buildMetricColumn(
                label: _isNepali ? 'बाहिरको खाजा' : 'Outside Snacks',
                value: '$snacksCount',
                color: Colors.orange.shade800,
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade200),
              _buildMetricColumn(
                label: _isNepali ? 'सामान्य दर' : 'Usual Rate',
                value: '$compliance%',
                color: SitiColors.terracotta,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: NepaliTypography.bodySmall.copyWith(
            color: Colors.grey.shade600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLogBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SitiColors.terracotta.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SitiColors.terracotta.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dinner_dining_rounded, color: SitiColors.terracotta, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? 'अहिलेको खाना रेकर्ड गर्नुहोस्' : 'Log Recent Meal',
                  style: NepaliTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
                Text(
                  _isNepali ? 'एक ट्यापमा "सबैले सामान्य खाए" पुष्टि गर्नुहोस्' : 'One-tap "Did everyone eat their usual?"',
                  style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            key: const Key('trigger_post_meal_button'),
            onPressed: _simulatePostMealPrompt,
            style: ElevatedButton.styleFrom(
              backgroundColor: SitiColors.terracotta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_isNepali ? 'पुष्टि' : 'Log'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(MemberConsumptionSummary member) {
    final isChild = member.nutritionProfile == 'child' || member.nutritionProfile == 'baby';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isChild
                    ? Colors.green.shade100
                    : SitiColors.terracotta.withValues(alpha: 0.15),
                child: Icon(
                  isChild ? Icons.child_care_rounded : Icons.person_outline_rounded,
                  size: 16,
                  color: isChild ? Colors.green.shade800 : SitiColors.terracotta,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                member.memberName,
                style: NepaliTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.dark,
                ),
              ),
              const Spacer(),
              Text(
                '${member.mealsLogged} ${_isNepali ? 'छाक' : 'meals'}',
                style: NepaliTypography.labelSmall.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Gentle Feedback
          Text(
            member.gentleFeedback,
            style: NepaliTypography.bodySmall.copyWith(
              color: Colors.grey.shade800,
              height: 1.3,
            ),
          ),

          // Strict privacy protection: NO calories for children!
          if (!isChild && member.estimatedCalories != null) ...[
            const SizedBox(height: 6),
            Text(
              '~${member.estimatedCalories} kcal (${_isNepali ? 'कुल अनुमानित' : 'estimated'})',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}
