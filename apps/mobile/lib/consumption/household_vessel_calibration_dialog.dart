import 'package:flutter/material.dart';
import 'package:kitchen_engine/consumption_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'consumption_repository.dart';

/// Modal tool to customize household vessels (e.g. "our katori ≈ 180 ml").
class HouseholdVesselCalibrationDialog extends StatefulWidget {
  final String currentLanguage;
  final ConsumptionRepository repository;
  final HouseholdVesselProfile? initialProfile;
  final ValueChanged<HouseholdVesselProfile>? onUpdated;

  const HouseholdVesselCalibrationDialog({
    super.key,
    required this.currentLanguage,
    required this.repository,
    this.initialProfile,
    this.onUpdated,
  });

  @override
  State<HouseholdVesselCalibrationDialog> createState() =>
      _HouseholdVesselCalibrationDialogState();
}

class _HouseholdVesselCalibrationDialogState
    extends State<HouseholdVesselCalibrationDialog> {
  HouseholdVesselProfile? _profile;
  bool _loading = true;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _loading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final prof = await widget.repository.getVesselProfile();
    if (mounted) {
      setState(() {
        _profile = prof;
        _loading = false;
      });
    }
  }

  Future<void> _updateVessel(String vesselId, double newVolume) async {
    setState(() {
      final updatedMap = Map<String, double>.from(_profile!.customVolumes);
      updatedMap[vesselId] = newVolume;
      _profile = _profile!.copyWith(customVolumes: updatedMap);
    });
    await widget.repository.saveVesselCalibration(vesselId, newVolume);
    widget.onUpdated?.call(_profile!);
  }

  Future<void> _resetVessel(String vesselId) async {
    setState(() {
      final updatedMap = Map<String, double>.from(_profile!.customVolumes);
      updatedMap.remove(vesselId);
      _profile = _profile!.copyWith(customVolumes: updatedMap);
    });
    await widget.repository.resetVesselCalibration(vesselId);
    widget.onUpdated?.call(_profile!);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profile == null) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final vessels = CalibratedVessel.standardVessels;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SitiColors.terracotta.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.straighten_rounded,
                              color: SitiColors.terracotta, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isNepali ? 'भाँडा क्यालिब्रेसन (Vessels)' : 'Household Vessels',
                            style: NepaliTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: SitiColors.dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
              const SizedBox(height: 8),

              Text(
                _isNepali
                    ? 'तपाईंको घरको कचौरा वा थालीको आकार अनुसार मिलान गर्नुहोस् (जस्तै: हाम्रो कचौरा ≈ १८० मिलि)।'
                    : 'Calibrate typical vessel volumes for your household (e.g. "our katori ≈ 180 ml").',
                style: NepaliTypography.bodySmall.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const Divider(height: 20),

              // Vessels List
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vessels.length,
                  itemBuilder: (context, index) {
                    final standard = vessels[index];
                    final effective = _profile!.getEffectiveVessel(standard.id);
                    final isCustom = effective.isCustom;
                    final unitLabel = standard.type == VesselType.roti || standard.type == VesselType.piece
                        ? 'g'
                        : 'ml';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCustom ? Colors.amber.shade50 : SitiColors.warmWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCustom ? Colors.amber.shade400 : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _isNepali ? standard.nameNe : standard.nameEn,
                                          style: NepaliTypography.bodyLarge.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: SitiColors.dark,
                                          ),
                                        ),
                                        if (isCustom) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _isNepali ? 'अनुकूलित' : 'Custom',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.brown.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isNepali ? standard.descriptionNe : standard.descriptionEn,
                                      style: NepaliTypography.bodySmall.copyWith(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCustom)
                                TextButton(
                                  key: Key('reset_vessel_${standard.id}'),
                                  onPressed: () => _resetVessel(standard.id),
                                  child: Text(
                                    _isNepali ? 'रिसेट' : 'Reset',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Volume adjustment steppers
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'मात्रा: ${effective.volumeMl.round()} $unitLabel',
                                key: Key('volume_label_${standard.id}'),
                                style: NepaliTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: SitiColors.terracotta,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    key: Key('sub_10_${standard.id}'),
                                    onPressed: () {
                                      final newVol = (effective.volumeMl - 10).clamp(10.0, 1000.0);
                                      _updateVessel(standard.id, newVol);
                                    },
                                    icon: const Icon(Icons.remove_rounded, size: 16),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    key: Key('add_10_${standard.id}'),
                                    onPressed: () {
                                      final newVol = (effective.volumeMl + 10).clamp(10.0, 1000.0);
                                      _updateVessel(standard.id, newVol);
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Done Button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_isNepali ? 'सकियो' : 'Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
