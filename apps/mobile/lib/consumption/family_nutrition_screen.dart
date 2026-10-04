import 'package:flutter/material.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import 'package:kitchen_engine/nutrition_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'consumption_repository.dart';

/// Reference dal-bhat batch used until per-recipe batch composition is logged
/// with each meal. Spinach stands in for the in-season produce share.
final BatchNutrition referenceDalBhatBatch = NutritionEngine.computeBatch(const [
  BatchIngredient('rice', 300),
  BatchIngredient('lentil', 150),
  BatchIngredient('spinach', 300),
  BatchIngredient('mustard-oil', 30),
]);

/// Fraction of the reference batch's cooked weight that is in-season produce.
double get referenceSeasonalFraction {
  final seasonal = 300 * NutritionEngine.yieldFor('spinach');
  return referenceDalBhatBatch.totals.grams <= 0
      ? 0
      : seasonal / referenceDalBhatBatch.totals.grams;
}

/// Converts logged meals into per-portion intakes for one member.
List<PortionIntake> intakesFromLogs(List<MealConsumptionLog> logs, String memberId) {
  final out = <PortionIntake>[];
  for (final log in logs) {
    for (final p in log.memberPortions) {
      if (p.memberId != memberId || p.skipped || p.calculatedGrams <= 0) continue;
      out.add(PortionIntake(
        nutrients: referenceDalBhatBatch.portion(p.calculatedGrams),
        foodGroups: referenceDalBhatBatch.foodGroups,
        seasonalFraction: referenceSeasonalFraction,
      ));
    }
  }
  return out;
}

const _groupLabels = {
  'grains': ('Grains', 'अन्न'),
  'pulses': ('Pulses', 'दाल'),
  'vegetables': ('Vegetables', 'तरकारी'),
  'fruits': ('Fruits', 'फलफूल'),
  'dairy': ('Dairy', 'दूध/दही'),
  'protein': ('Protein', 'प्रोटिन'),
};

/// Calm family nutrition dashboard (Section 11.4): progress, never alarm.
class FamilyNutritionScreen extends StatefulWidget {
  final String currentLanguage;
  final ConsumptionRepository repository;
  final List<MemberDietaryProfile>? initialMembers;
  final List<MealConsumptionLog>? initialLogs;

  const FamilyNutritionScreen({
    super.key,
    required this.currentLanguage,
    required this.repository,
    this.initialMembers,
    this.initialLogs,
  });

  @override
  State<FamilyNutritionScreen> createState() => _FamilyNutritionScreenState();
}

class _FamilyNutritionScreenState extends State<FamilyNutritionScreen> {
  List<MemberDietaryProfile> _members = [];
  List<MealConsumptionLog> _logs = [];
  bool _loading = true;

  bool get _ne => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    if (widget.initialMembers != null && widget.initialLogs != null) {
      _members = widget.initialMembers!;
      _logs = widget.initialLogs!;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final members = await widget.repository.getMembers();
    final logs = await widget.repository.getMealLogs(
      from: now.subtract(const Duration(days: 7)),
      to: now,
    );
    if (!mounted) return;
    setState(() {
      _members = members;
      _logs = logs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: SitiColors.dark),
        title: Text(
          _ne ? 'परिवारको पोषण' : 'Family Nutrition',
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in _members) _memberCard(m),
              ],
            ),
    );
  }

  Widget _memberCard(MemberDietaryProfile m) {
    final view = NutritionEngine.buildMemberView(
      member: m,
      intakes: intakesFromLogs(_logs, m.memberId),
    );
    return Container(
      key: Key('nutrition_card_${m.memberId}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.name,
            style: NepaliTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: SitiColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _ne ? view.messageNe : view.messageEn,
            style: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          if (view.showsNumbers)
            for (final b in view.bars) _barRow(m.memberId, b)
          else
            _foodGroupChips(view),
        ],
      ),
    );
  }

  Widget _barRow(String memberId, NutritionProgressBar b) {
    final labels = {
      'protein': ('Protein', 'प्रोटिन'),
      'fiber': ('Fibre', 'फाइबर'),
      'seasonal': ('Seasonal share', 'ऋतु अनुसार'),
    };
    final label = labels[b.key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ne ? label.$2 : label.$1,
            style: NepaliTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: Key('bar_${memberId}_${b.key}'),
              value: b.fraction,
              minHeight: 10,
              backgroundColor: SitiColors.freshGreen.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(SitiColors.freshGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodGroupChips(MemberNutritionView view) {
    return Wrap(
      key: Key('food_groups_${view.memberId}'),
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final g in NutritionEngine.allFoodGroups)
          Chip(
            label: Text(_ne ? _groupLabels[g]!.$2 : _groupLabels[g]!.$1),
            backgroundColor: view.foodGroupsCovered.contains(g)
                ? SitiColors.freshGreen.withValues(alpha: 0.2)
                : Colors.grey.shade100,
          ),
      ],
    );
  }
}
