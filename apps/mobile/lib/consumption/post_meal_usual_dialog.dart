import 'package:flutter/material.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'consumption_repository.dart';
import 'vessel_portion_adjuster_dialog.dart';

/// Post-meal confirmation dialog: "Did everyone eat their usual?" (Section 11.2)
class PostMealUsualDialog extends StatelessWidget {
  final String recipeId;
  final String recipeTitle;
  final String mealSlot;
  final String? mealPlanId;
  final String currentLanguage;
  final ConsumptionRepository repository;
  final List<MemberDietaryProfile> members;
  final HouseholdVesselProfile vesselProfile;
  final double? batchYieldGrams;
  final double? leftoverGrams;
  final ValueChanged<MealConsumptionLog>? onLogged;

  const PostMealUsualDialog({
    super.key,
    required this.recipeId,
    required this.recipeTitle,
    required this.mealSlot,
    this.mealPlanId,
    required this.currentLanguage,
    required this.repository,
    required this.members,
    this.vesselProfile = const HouseholdVesselProfile(),
    this.batchYieldGrams,
    this.leftoverGrams,
    this.onLogged,
  });

  bool get _isNepali => currentLanguage == 'ne';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SitiColors.freshGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: SitiColors.freshGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? 'खाना सम्पन्न भयो' : 'Meal Completed',
                        style: NepaliTypography.labelMedium.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        recipeTitle,
                        style: NepaliTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: SitiColors.dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Prompt Question
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SitiColors.warmWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isNepali
                        ? 'सबैले आफ्नो सामान्य मात्रा खानुभयो?'
                        : 'Did everyone eat their usual meal?',
                    style: NepaliTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: SitiColors.dark,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Household members & usual portion vessel pills
                  ...members.map((m) {
                    final vessel = vesselProfile.getEffectiveVessel(m.preferredVesselId);
                    final vesselName = _isNepali ? vessel.nameNe : vessel.nameEn;
                    final count = m.defaultVesselCount % 1 == 0
                        ? m.defaultVesselCount.toInt().toString()
                        : m.defaultVesselCount.toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            m.isChildOrBaby
                                ? Icons.child_care_rounded
                                : Icons.person_outline_rounded,
                            size: 16,
                            color: SitiColors.terracotta,
                          ),
                          Expanded(
                            child: Text(
                              m.name,
                              style: NepaliTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: SitiColors.dark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '$count $vesselName',
                              style: NepaliTypography.labelSmall.copyWith(
                                color: Colors.brown.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Primary One-Tap Confirmation Button
            ElevatedButton.icon(
              key: const Key('confirm_usual_button'),
              onPressed: () async {
                final log = ConsumptionEngine.logUsualMeal(
                  mealPlanId: mealPlanId,
                  recipeId: recipeId,
                  recipeTitle: recipeTitle,
                  mealSlot: mealSlot,
                  members: members,
                  vesselProfile: vesselProfile,
                  batchYieldGrams: batchYieldGrams,
                  leftoverGrams: leftoverGrams,
                );
                onLogged?.call(log);
                await repository.logMeal(log);
                if (context.mounted) {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  Navigator.of(context).pop();
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(
                        _isNepali
                            ? 'खाना रेकर्ड भयो: सबैले सामान्य मात्रा खाए ✓'
                            : 'Logged: Everyone ate their usual portions ✓',
                      ),
                      backgroundColor: SitiColors.freshGreen,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.thumb_up_alt_rounded, size: 18),
              label: Text(
                _isNepali ? 'हो, सबैले सामान्य मात्रा खाए' : 'Yes, everyone ate their usual',
                style: NepaliTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SitiColors.freshGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary "Adjust Portions" Button
            OutlinedButton.icon(
              key: const Key('adjust_portions_button'),
              onPressed: () {
                Navigator.of(context).pop();
                showDialog<void>(
                  context: context,
                  builder: (ctx) => VesselPortionAdjusterDialog(
                    recipeId: recipeId,
                    recipeTitle: recipeTitle,
                    mealSlot: mealSlot,
                    mealPlanId: mealPlanId,
                    currentLanguage: currentLanguage,
                    repository: repository,
                    members: members,
                    vesselProfile: vesselProfile,
                    batchYieldGrams: batchYieldGrams,
                    leftoverGrams: leftoverGrams,
                    onLogged: onLogged,
                  ),
                );
              },
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                _isNepali ? 'मात्रा थपघट गर्नुहोस्' : 'Adjust Portions',
                style: NepaliTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SitiColors.terracotta,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: SitiColors.terracotta, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
