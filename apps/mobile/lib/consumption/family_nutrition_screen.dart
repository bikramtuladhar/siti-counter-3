import 'package:flutter/material.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import 'package:kitchen_engine/nutrition_engine.dart';
import 'package:kitchen_engine/region_pack.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import '../data/region_pack_repository.dart';
import 'consumption_repository.dart';

/// Scores a logged meal from its own recipe ingredients.
///
/// Takes the recipe id the log already carries rather than a resolved [RegionRecipe], so a meal
/// logged outside the app resolves to null and callers must treat that as "unknown" rather than
/// substituting a default.
typedef RecipeBatchResolver =
    BatchNutrition? Function(String recipeId, double servings);

/// Builds a resolver over a region pack.
RecipeBatchResolver resolverForPack(RegionPack? pack) {
  final byId = <String, RegionRecipe>{
    for (final r in pack?.recipes ?? const <RegionRecipe>[]) r.id: r,
  };
  return (recipeId, servings) {
    final recipe = byId[recipeId];
    if (recipe == null) return null;
    return NutritionEngine.batchForRecipe(recipe, servings: servings);
  };
}

/// What the dashboard could and could not compute for one member.
///
/// [intakes] carries only meals that were actually resolvable. [skippedMeals] counts portions
/// that were not, which the screen reports rather than hiding: a household that logged four
/// meals and got one number has been given a misleading total if it is not told the rest is
/// missing.
class MemberNutritionInput {
  final List<PortionIntake> intakes;
  final int skippedMeals;
  final bool anyIncomplete;

  const MemberNutritionInput({
    required this.intakes,
    this.skippedMeals = 0,
    this.anyIncomplete = false,
  });

  bool get hasAnyData => intakes.isNotEmpty;
}

/// Converts logged meals into per-portion intakes for one member, using each recipe's own
/// ingredients.
///
/// Previously every meal was scored as a fixed dal-bhat batch, so logging thukpa or momo
/// produced dal bhat's kcal, protein, fibre, carbs and fat. A meal whose recipe cannot be
/// resolved, or whose ingredients have no composition data at all, is left out and counted in
/// [MemberNutritionInput.skippedMeals] rather than given a plausible substitute.
MemberNutritionInput nutritionInputFromLogs(
  List<MealConsumptionLog> logs,
  String memberId,
  RecipeBatchResolver resolve,
) {
  final intakes = <PortionIntake>[];
  var skipped = 0;
  var incomplete = false;

  for (final log in logs) {
    final batch = resolve(log.recipeId, log.totalServings);
    if (batch == null || batch.totals.grams <= 0) {
      // No usable composition: count the portions rather than inventing nutrients for them.
      skipped += log.memberPortions
          .where((p) => p.memberId == memberId && !p.skipped && p.calculatedGrams > 0)
          .length;
      continue;
    }
    if (!batch.isComplete) incomplete = true;

    for (final p in log.memberPortions) {
      if (p.memberId != memberId || p.skipped || p.calculatedGrams <= 0) continue;
      intakes.add(PortionIntake(
        nutrients: batch.portion(p.calculatedGrams),
        foodGroups: batch.foodGroups,
        // The seasonal share is only claimed when the whole batch resolved. Attributing part
        // of an incomplete batch to in-season produce would be a second guess on top of the
        // first, so it is reported as unknown instead.
        seasonalFraction: batch.isComplete ? _seasonalShare(batch) : 0,
      ));
    }
  }

  return MemberNutritionInput(
    intakes: intakes,
    skippedMeals: skipped,
    anyIncomplete: incomplete,
  );
}

/// Share of a batch's cooked weight that came from vegetables, used as an in-season proxy.
///
/// A real answer needs the pack's ritu availability per ingredient, which is not threaded into
/// this screen. This is deliberately a conservative fixed estimate rather than a second guess
/// at ingredient seasonality, and it stays at zero unless the batch contains vegetables.
double _seasonalShare(BatchNutrition batch) {
  if (batch.totals.grams <= 0) return 0;
  return batch.foodGroups.contains('vegetables') ? 0.3 : 0;
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

  /// Scores meals from their own recipes. Null pack means every meal is unresolvable, which is
  /// reported rather than papered over with a default batch.
  RecipeBatchResolver _resolve = resolverForPack(null);

  bool get _ne => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    if (widget.initialMembers != null && widget.initialLogs != null) {
      _members = widget.initialMembers!;
      _logs = widget.initialLogs!;
      _loading = false;
      _resolvePack();
    } else {
      _load();
    }
  }

  /// Loads the pack so meals can be scored from their real ingredients.
  ///
  /// Failure is not fatal: without a pack the screen shows that it cannot compute anything,
  /// which is honest, rather than falling back to a fixed batch that would be wrong for every
  /// meal except one.
  Future<void> _resolvePack() async {
    try {
      final pack = await RegionPackRepository().loadRegionPack();
      if (mounted) setState(() => _resolve = resolverForPack(pack));
    } catch (_) {
      // Left as the null resolver: the screen will say it has no data rather than invent it.
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
    final input = nutritionInputFromLogs(_logs, m.memberId, _resolve);
    final view = NutritionEngine.buildMemberView(
      member: m,
      intakes: input.intakes,
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
          if (input.skippedMeals > 0) _coverageNote(input),
          if (view.showsNumbers)
            for (final b in view.bars) _barRow(m.memberId, b)
          else
            _foodGroupChips(view),
        ],
      ),
    );
  }

  /// Says plainly which meals the figures above do not cover.
  ///
  /// Without this the bars read as the household's whole week even when most of the week was
  /// unresolvable, which is how a fabricated total looks like data.
  Widget _coverageNote(MemberNutritionInput input) {
    final parts = <String>[
      if (input.skippedMeals > 0)
        _ne
            ? '${input.skippedMeals} भोजनको पोषण जानकारी छैन'
            : '${input.skippedMeals} meal${input.skippedMeals == 1 ? '' : 's'} could not be scored',
      if (input.anyIncomplete)
        _ne
            ? 'केही सामग्रीको पोषण तथ्यांक छैन, त्यसैले यो अनुमान हो'
            : 'some ingredients have no nutrition data, so these figures are a partial estimate',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: const Key('nutrition_coverage_note'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: SitiColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SitiColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: SitiColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                parts.join(_ne ? '। ' : '. '),
                style: const TextStyle(fontSize: 11.5, height: 1.35, color: SitiColors.dark),
              ),
            ),
          ],
        ),
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
