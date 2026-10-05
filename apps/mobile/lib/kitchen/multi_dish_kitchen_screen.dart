import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Screen managing simultaneous multi-dish cooking lanes (Section 10.6):
/// - Parallel lanes (e.g. Dal 2/3 siti · Rice 08:30 · Sabzi 04:10 · Chapati waiting).
/// - Burner and vessel conflict detection and actionable warnings.
/// - Acoustic whistle disambiguation when multiple pressure cookers are active.
class MultiDishKitchenScreen extends StatefulWidget {
  final MultiDishKitchenEngine? engine;
  final String currentLanguage;

  const MultiDishKitchenScreen({
    super.key,
    this.engine,
    this.currentLanguage = 'ne',
  });

  @override
  State<MultiDishKitchenScreen> createState() => _MultiDishKitchenScreenState();
}

class _MultiDishKitchenScreenState extends State<MultiDishKitchenScreen> {
  late final MultiDishKitchenEngine _engine;
  Timer? _tickerTimer;
  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? _createSampleEngine();
    _startTicker();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _engine.tickTimers(1);
        });
      }
    });
  }

  MultiDishKitchenEngine _createSampleEngine() {
    final eng = MultiDishKitchenEngine(maxBurners: 2);
    eng.addLane(CookingLane(
      id: 'lane_dal',
      dishName: 'Kalo Dal',
      dishNameNe: 'कालो दाल',
      vesselType: CookerVesselType.pressureCooker3L,
      vesselId: 'pc_3l',
      requiresBurner: true,
      burnerIndex: 1,
      status: LaneStatus.cooking,
      isAcousticCooker: true,
      currentWhistles: 2,
      targetWhistles: 3,
      heatLevel: 'medium',
    ));
    eng.addLane(CookingLane(
      id: 'lane_rice',
      dishName: 'Basmati Bhat',
      dishNameNe: 'बासमती भात',
      vesselType: CookerVesselType.saucepan,
      vesselId: 'pot_rice',
      requiresBurner: true,
      burnerIndex: 2,
      status: LaneStatus.cooking,
      remainingSeconds: 510, // 08:30
      totalSeconds: 600,
      heatLevel: 'low',
    ));
    eng.addLane(CookingLane(
      id: 'lane_sabzi',
      dishName: 'Aloo Cauli',
      dishNameNe: 'आलु काउली',
      vesselType: CookerVesselType.kadaiPan,
      vesselId: 'kadai_iron',
      requiresBurner: true,
      status: LaneStatus.waiting,
      remainingSeconds: 250, // 04:10
      totalSeconds: 400,
      heatLevel: 'off',
    ));
    eng.addLane(CookingLane(
      id: 'lane_chapati',
      dishName: 'Gahu Chapati',
      dishNameNe: 'गहुँको रोटी',
      vesselType: CookerVesselType.tawa,
      vesselId: 'tawa_iron',
      requiresBurner: true,
      status: LaneStatus.waiting,
      heatLevel: 'off',
    ));
    return eng;
  }

  void _onAcousticWhistleTriggered() {
    final result = _engine.handleAcousticWhistle();
    if (result['needsDisambiguation'] == true) {
      final req = result['disambiguationRequest'] as WhistleDisambiguationRequest;
      _showDisambiguationDialog(req);
    } else {
      final laneId = result['attributedLaneId'] as String?;
      if (laneId != null && mounted) {
        final lane = _engine.getLane(laneId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNepali
                ? '${lane?.dishNameNe ?? laneId} मा सिट्ठी थपियो (${lane?.currentWhistles}/${lane?.targetWhistles})'
                : 'Whistle attributed to ${lane?.dishName ?? laneId} (${lane?.currentWhistles}/${lane?.targetWhistles})',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: SitiColors.terracotta,
          ),
        );
      }
    }
    setState(() {});
  }

  void _showDisambiguationDialog(WhistleDisambiguationRequest req) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const Key('whistle_disambiguation_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.hearing, color: SitiColors.terracotta, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isNepali ? 'सिट्ठी बज्यो! (कुन कुकर?)' : 'Whistle Detected! Which Cooker?',
                style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isNepali
                  ? 'एकैपटक धेरै कुकर सक्रिय भएकाले सिट्ठी कुन परिकारको हो छान्नुहोस्:'
                  : 'Multiple acoustic pressure cookers are cooking. Attribute this whistle to:',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            ...req.candidateLaneIds.map((laneId) {
              final lane = _engine.getLane(laneId);
              final name = _isNepali ? (lane?.dishNameNe ?? laneId) : (lane?.dishName ?? laneId);
              final count = '${lane?.currentWhistles ?? 0}/${lane?.targetWhistles ?? 0}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: Key('btn_disambiguate_$laneId'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SitiColors.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.soup_kitchen, size: 20),
                    label: Text(
                      '$name ($count siti)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () {
                      _engine.resolveDisambiguation(laneId);
                      Navigator.of(ctx).pop();
                      setState(() {});
                    },
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('btn_dismiss_disambiguation'),
            child: Text(_isNepali ? 'रद्द गर्नुहोस्' : 'Dismiss'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lanes = _engine.lanes;
    final conflicts = _engine.detectConflicts();
    final activeBurnerCount = lanes.where((l) => l.status == LaneStatus.cooking && l.requiresBurner).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNepali ? 'बहु-परिकार भान्सा' : 'Multi-Dish Kitchen',
          style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Simulate Acoustic Whistle Button for testing/manual triggering
          IconButton(
            key: const Key('btn_trigger_whistle'),
            tooltip: _isNepali ? 'सिट्ठी बजाउनुहोस्' : 'Trigger Whistle',
            icon: const Icon(Icons.volume_up, color: SitiColors.terracotta),
            onPressed: _onAcousticWhistleTriggered,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cooktop Status Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isNepali
                              ? 'चुल्हो क्षमता: $activeBurnerCount / ${_engine.maxBurners} बर्नर'
                              : 'Cooktop Burners: $activeBurnerCount / ${_engine.maxBurners} in use',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          _isNepali
                              ? 'समानान्तर परिकारहरू र भाँडा व्यवस्थापन'
                              : 'Parallel cooking lanes & equipment capacity',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Conflict Warning Banners (Section 10.6)
            if (conflicts.isNotEmpty) ...[
              ...conflicts.map((conflict) => _buildConflictBanner(conflict)),
              const SizedBox(height: 12),
            ],

            // Section Title: Active Cooking Lanes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isNepali ? 'पकाउने लेनहरू (Active Lanes)' : 'Cooking Lanes',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${lanes.length} ${_isNepali ? "परिकार" : "dishes"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Lanes Cards
            ...lanes.map((lane) => _buildLaneCard(lane)),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictBanner(MultiDishConflict conflict) {
    final isBurner = conflict.type == MultiDishConflictType.burnerCapacity;
    final bgColor = isBurner ? Colors.red.shade50 : Colors.amber.shade50;
    final borderColor = isBurner ? Colors.red.shade300 : Colors.amber.shade400;
    final textColor = isBurner ? Colors.red.shade900 : Colors.amber.shade900;

    return Container(
      key: Key('conflict_banner_${conflict.type.name}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: textColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? conflict.messageNe : conflict.messageEn,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                ),
                const SizedBox(height: 3),
                Text(
                  _isNepali ? conflict.suggestionNe : conflict.suggestionEn,
                  style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaneCard(CookingLane lane) {
    final isCooking = lane.status == LaneStatus.cooking;
    final isCompleted = lane.status == LaneStatus.completed;

    Color statusColor;
    String statusLabel;
    switch (lane.status) {
      case LaneStatus.cooking:
        statusColor = SitiColors.freshGreen;
        statusLabel = _isNepali ? 'पाक्दैछ' : 'Cooking';
        break;
      case LaneStatus.waiting:
        statusColor = Colors.orange.shade700;
        statusLabel = _isNepali ? 'पर्खँदै' : 'Waiting';
        break;
      case LaneStatus.paused:
        statusColor = Colors.grey.shade600;
        statusLabel = _isNepali ? 'रोकिएको' : 'Paused';
        break;
      case LaneStatus.completed:
        statusColor = Colors.blue.shade700;
        statusLabel = _isNepali ? 'तयार भयो' : 'Done';
        break;
    }

    return Card(
      key: Key('lane_card_${lane.id}'),
      elevation: isCooking ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCooking ? SitiColors.terracotta.withValues(alpha: 0.5) : Colors.grey.shade300,
          width: isCooking ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Dish Name & Status Badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? lane.dishNameNe : lane.dishName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${lane.vesselType.name} (${lane.vesselId})',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle Row: Burner indicator & Current Metric
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Burner assignment
                Row(
                  children: [
                    const Icon(Icons.circle, size: 10, color: Colors.deepOrange),
                    const SizedBox(width: 6),
                    Text(
                      lane.burnerIndex != null
                          ? (_isNepali ? 'बर्नर ${lane.burnerIndex}' : 'Burner ${lane.burnerIndex}')
                          : (_isNepali ? 'बर्नर आवश्यक छैन' : 'No Burner Slot'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                // Metric display
                if (lane.isAcousticCooker) ...[
                  Container(
                    key: Key('siti_count_badge_${lane.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SitiColors.terracotta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${lane.currentWhistles} / ${lane.targetWhistles} siti',
                      style: const TextStyle(
                        color: SitiColors.terracotta,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ] else if (lane.remainingSeconds > 0) ...[
                  Container(
                    key: Key('timer_badge_${lane.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(lane.remainingSeconds),
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                if (!isCompleted) ...[
                  if (lane.status == LaneStatus.cooking) ...[
                    OutlinedButton.icon(
                      key: Key('btn_pause_${lane.id}'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.pause, size: 14),
                      label: Text(_isNepali ? 'रोक्नुहोस्' : 'Pause', style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _engine.updateLaneStatus(lane.id, LaneStatus.paused);
                        });
                      },
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      key: Key('btn_start_${lane.id}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SitiColors.terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 14),
                      label: Text(_isNepali ? 'पकाउनुहोस्' : 'Start', style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _engine.updateLaneStatus(lane.id, LaneStatus.cooking);
                        });
                      },
                    ),
                  ],
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  key: Key('btn_complete_${lane.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted ? Colors.grey.shade400 : SitiColors.freshGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.check, size: 14),
                  label: Text(_isNepali ? 'सम्पन्न' : 'Done', style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _engine.updateLaneStatus(lane.id, LaneStatus.completed);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
