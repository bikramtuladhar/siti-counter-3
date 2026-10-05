import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/tokens.dart';
import 'companion_widget_service.dart';

/// Interactive preview and simulator of the Siti Counter Apple Watch (watchOS)
/// and Wear OS companion app.
class WatchCompanionPreviewSheet extends StatelessWidget {
  final CompanionWidgetService service;

  const WatchCompanionPreviewSheet({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final state = service.watchCompanionState;
        if (state == null) {
          return const Center(
            child: Text(
              'No active cooking session linked to Watch.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: SitiSpacing.lg, vertical: SitiSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Watch Device Bezel Simulation
              Center(
                child: Container(
                  key: const Key('watch_companion_surface'),
                  width: 280,
                  height: 340,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(44),
                    border: Border.all(color: const Color(0xFF333333), width: 8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Padding(
                      padding: const EdgeInsets.all(SitiSpacing.md),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top bar: Status & Haptic
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: state.isAlarmActive ? SitiColors.alert : SitiColors.freshGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  state.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                key: const Key('watch_haptic_indicator'),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.vibration,
                                      size: 11,
                                      color: state.lastHapticPattern == WatchHapticPattern.targetReached
                                          ? SitiColors.alert
                                          : (state.lastHapticPattern != WatchHapticPattern.none
                                              ? Colors.amber
                                              : Colors.grey),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      state.lastHapticPattern.name,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: state.lastHapticPattern == WatchHapticPattern.targetReached
                                            ? SitiColors.alert
                                            : Colors.grey[300],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Dish Title
                          Text(
                            '${state.dishTitleEn} (${state.dishTitleNe})',
                            key: const Key('watch_dish_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Large Siti Whistle Counter Dial
                          Column(
                            children: [
                              Text(
                                '${state.currentWhistles}/${state.targetWhistles}',
                                key: const Key('watch_whistle_counter'),
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: state.isAlarmActive ? SitiColors.alert : SitiColors.terracotta,
                                  letterSpacing: 1.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const Text(
                                'SITI / WHISTLES',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          // Alarm Banner
                          if (state.isAlarmActive)
                            Container(
                              key: const Key('watch_alarm_alert'),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: SitiColors.alert,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'TARGET REACHED!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Step Guidance
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Step ${state.currentStepIndex + 1}/${state.totalSteps}',
                                  key: const Key('watch_step_indicator'),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  state.currentStepInstructionEn,
                                  key: const Key('watch_step_instruction'),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Watch Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                key: const Key('btn_watch_add_whistle'),
                                onPressed: () => service.incrementWatchWhistle(),
                                icon: const Icon(Icons.add_circle, color: SitiColors.terracotta, size: 28),
                                tooltip: 'Increment Siti',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                key: const Key('btn_watch_toggle_step'),
                                onPressed: () => service.advanceWatchStep(),
                                icon: const Icon(Icons.check_circle_outline, color: SitiColors.freshGreen, size: 28),
                                tooltip: 'Complete Step',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              if (state.isAlarmActive)
                                IconButton(
                                  key: const Key('btn_watch_dismiss_alarm'),
                                  onPressed: () => service.dismissAlarm(),
                                  icon: const Icon(Icons.stop_circle, color: SitiColors.alert, size: 28),
                                  tooltip: 'Dismiss Alarm',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
