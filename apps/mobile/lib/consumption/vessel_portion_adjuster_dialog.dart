import 'package:flutter/material.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'consumption_repository.dart';

/// Interactive modal to adjust member portions using familiar calibrated vessels.
class VesselPortionAdjusterDialog extends StatefulWidget {
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

  const VesselPortionAdjusterDialog({
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

  @override
  State<VesselPortionAdjusterDialog> createState() => _VesselPortionAdjusterDialogState();
}

class _MemberAdjustState {
  String vesselId;
  double count;
  bool skipped;
  String? notes;

  _MemberAdjustState({
    required this.vesselId,
    required this.count,
    this.skipped = false,
    this.notes,
  });
}

class _VesselPortionAdjusterDialogState extends State<VesselPortionAdjusterDialog> {
  late Map<String, _MemberAdjustState> _adjustments;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _adjustments = {
      for (final m in widget.members)
        m.memberId: _MemberAdjustState(
          vesselId: m.preferredVesselId,
          count: m.defaultVesselCount,
          skipped: false,
        ),
    };
  }

  void _increment(String memberId, double step) {
    setState(() {
      final state = _adjustments[memberId]!;
      state.count = (state.count + step).clamp(0.0, 10.0);
      if (state.count > 0) state.skipped = false;
    });
  }

  void _decrement(String memberId, double step) {
    setState(() {
      final state = _adjustments[memberId]!;
      state.count = (state.count - step).clamp(0.0, 10.0);
      if (state.count == 0) state.skipped = true;
    });
  }

  void _toggleSkipped(String memberId, bool? val) {
    setState(() {
      final state = _adjustments[memberId]!;
      state.skipped = val ?? false;
      if (state.skipped) {
        state.count = 0.0;
      } else if (state.count == 0) {
        state.count = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableVessels = CalibratedVessel.standardVessels;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isNepali ? 'खानाको मात्रा समायोजन' : 'Adjust Meal Portions',
                          style: NepaliTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SitiColors.dark,
                          ),
                        ),
                        Text(
                          widget.recipeTitle,
                          style: NepaliTypography.bodySmall.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Members List
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.members.length,
                  itemBuilder: (context, index) {
                    final member = widget.members[index];
                    final adj = _adjustments[member.memberId]!;
                    final vessel = widget.vesselProfile.getEffectiveVessel(adj.vesselId);
                    final grams = adj.skipped ? 0.0 : vessel.standardGrams * adj.count;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: adj.skipped ? Colors.grey.shade50 : SitiColors.warmWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: adj.skipped ? Colors.grey.shade300 : Colors.brown.shade100,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Member Name & Skip Checkbox
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: SitiColors.terracotta.withValues(alpha: 0.15),
                                child: Icon(
                                  member.isChildOrBaby
                                      ? Icons.child_care_rounded
                                      : Icons.person_rounded,
                                  size: 16,
                                  color: SitiColors.terracotta,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  member.name,
                                  style: NepaliTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: SitiColors.dark,
                                    decoration: adj.skipped ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isNepali ? 'खाएनन्' : 'Skipped',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: adj.skipped ? Colors.red.shade700 : Colors.grey.shade600,
                                      fontWeight: adj.skipped ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  Checkbox(
                                    key: Key('skip_checkbox_${member.memberId}'),
                                    value: adj.skipped,
                                    onChanged: (v) => _toggleSkipped(member.memberId, v),
                                    activeColor: Colors.red.shade700,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          if (!adj.skipped) ...[
                            const SizedBox(height: 8),
                            // Vessel Picker & Stepper
                            Row(
                              children: [
                                // Vessel Dropdown
                                Expanded(
                                  flex: 5,
                                  child: DropdownButtonFormField<String>(
                                    key: Key('vessel_dropdown_${member.memberId}'),
                                    value: adj.vesselId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      isDense: true,
                                    ),
                                    items: availableVessels.map((v) {
                                      final label = _isNepali ? v.nameNe : v.nameEn;
                                      return DropdownMenuItem(
                                        value: v.id,
                                        child: Text(
                                          label,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newVessel) {
                                      if (newVessel != null) {
                                        setState(() {
                                          adj.vesselId = newVessel;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Stepper Controls
                                Row(
                                  children: [
                                    IconButton.filledTonal(
                                      key: Key('dec_${member.memberId}'),
                                      onPressed: () => _decrement(member.memberId, 0.5),
                                      icon: const Icon(Icons.remove_rounded, size: 16),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(
                                        adj.count % 1 == 0
                                            ? adj.count.toInt().toString()
                                            : adj.count.toStringAsFixed(1),
                                        key: Key('count_text_${member.memberId}'),
                                        style: NepaliTypography.titleSmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      key: Key('inc_${member.memberId}'),
                                      onPressed: () => _increment(member.memberId, 0.5),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Live Grams & Gentle Guidance
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '≈ ${grams.round()} g',
                                  key: Key('grams_text_${member.memberId}'),
                                  style: NepaliTypography.labelMedium.copyWith(
                                    color: SitiColors.terracotta,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (member.isChildOrBaby)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _isNepali ? 'बालबालिका पोषण' : 'Child Growth Portion',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_isNepali ? 'रद्द गर्नुहोस्' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('save_adjusted_portions_button'),
                      onPressed: () async {
                        final adjustmentsMap = <String, ({String vesselId, double vesselCount, bool skipped, String? notes})>{
                          for (final entry in _adjustments.entries)
                            entry.key: (
                              vesselId: entry.value.vesselId,
                              vesselCount: entry.value.count,
                              skipped: entry.value.skipped,
                              notes: entry.value.notes,
                            ),
                        };

                        final log = ConsumptionEngine.logAdjustedMeal(
                          mealPlanId: widget.mealPlanId,
                          recipeId: widget.recipeId,
                          recipeTitle: widget.recipeTitle,
                          mealSlot: widget.mealSlot,
                          members: widget.members,
                          adjustments: adjustmentsMap,
                          vesselProfile: widget.vesselProfile,
                          batchYieldGrams: widget.batchYieldGrams,
                          leftoverGrams: widget.leftoverGrams,
                        );

                        widget.onLogged?.call(log);
                        await widget.repository.logMeal(log);

                        if (context.mounted) {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          Navigator.of(context).pop();
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(
                                _isNepali
                                    ? 'मात्रा समायोजन सुरक्षित गरियो ✓'
                                    : 'Portions logged with adjustments ✓',
                              ),
                              backgroundColor: SitiColors.terracotta,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isNepali ? 'सुरक्षित गर्नुहोस्' : 'Save Portions',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SitiColors.terracotta,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
