library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:kitchen_engine/region_pack.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../audio/background_cooking_controller.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';
import '../widgets/microphone_privacy_primer_dialog.dart';
import 'recipe_detail_screen.dart' show CooktopType;

/// Safe platform wrapper for Screen Wake Lock.
class KitchenWakeLock {
  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Graceful fallback in headless/test environments
    }
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Graceful fallback
    }
  }
}

/// Custom Canvas Painter that renders the signature Siti Counter ring,
/// target ticks, progress arc, and pulsing glow readable from 2+ meters away.
class SitiWhistlePainter extends CustomPainter {
  final int currentWhistles;
  final int targetWhistles;
  final double animationProgress; // for steam pulse or transition
  final bool isAlarmActive;

  SitiWhistlePainter({
    required this.currentWhistles,
    required this.targetWhistles,
    this.animationProgress = 1.0,
    this.isAlarmActive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    const strokeWidth = 18.0;

    // 1. Background Track
    final trackPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active Progress Arc
    final effectiveTarget = targetWhistles > 0 ? targetWhistles : 1;
    final progressFraction = (currentWhistles / effectiveTarget).clamp(0.0, 1.0);
    final sweepAngle = 2 * math.pi * progressFraction;

    if (progressFraction > 0) {
      final Color arcStartColor = isAlarmActive ? Colors.red.shade600 : SitiColors.terracotta;
      final Color arcEndColor = isAlarmActive ? Colors.amber.shade600 : const Color(0xFFFF7043);

      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [arcStartColor, arcEndColor],
          stops: const [0.0, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Draw shadow glow if alarm is active
      if (isAlarmActive) {
        final glowPaint = Paint()
          ..color = Colors.red.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          sweepAngle,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }

    // 3. Whistle Target Tick Marks
    if (targetWhistles > 1) {
      final tickPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final innerTickRadius = radius - strokeWidth / 2 + 2;
      final outerTickRadius = radius + strokeWidth / 2 - 2;

      for (int i = 1; i <= targetWhistles; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * (i / targetWhistles));
        final startX = center.dx + innerTickRadius * math.cos(angle);
        final startY = center.dy + innerTickRadius * math.sin(angle);
        final endX = center.dx + outerTickRadius * math.cos(angle);
        final endY = center.dy + outerTickRadius * math.sin(angle);

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SitiWhistlePainter oldDelegate) {
    return oldDelegate.currentWhistles != currentWhistles ||
        oldDelegate.targetWhistles != targetWhistles ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.isAlarmActive != isAlarmActive;
  }
}

/// The signature Siti Counter active cooking screen.
class ActiveCookingSessionScreen extends StatefulWidget {
  final RegionRecipe? recipe;
  final int targetWhistles;
  final CooktopType cooktop;
  final String currentLanguage;
  final int initialWhistles;
  final VoidCallback? onSessionComplete;

  const ActiveCookingSessionScreen({
    super.key,
    this.recipe,
    this.targetWhistles = 4,
    this.cooktop = CooktopType.lpgGas,
    this.currentLanguage = 'ne',
    this.initialWhistles = 0,
    this.onSessionComplete,
  });

  @override
  State<ActiveCookingSessionScreen> createState() => _ActiveCookingSessionScreenState();
}

class _ActiveCookingSessionScreenState extends State<ActiveCookingSessionScreen>
    with SingleTickerProviderStateMixin {
  late int _currentWhistles;
  late int _targetWhistles;
  late CooktopType _cooktop;
  int _currentStepIndex = 0;
  bool _isAlarmActive = false;
  bool _isMuted = false;
  bool _isAcousticMode = false;
  Timer? _alarmPulseTimer;
  late AnimationController _pulseController;
  late BackgroundCookingController _backgroundController;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _currentWhistles = widget.initialWhistles;
    _targetWhistles = widget.targetWhistles > 0 ? widget.targetWhistles : 4;
    _cooktop = widget.cooktop;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final dishName = widget.recipe != null
        ? (_isNepali ? widget.recipe!.titleNe : widget.recipe!.titleEn)
        : (_isNepali ? 'प्रेसर कुकर सिट्ठी काउन्टर' : 'Pressure Cooker Siti Counter');

    _backgroundController = BackgroundCookingController(
      dishName: dishName,
      cookerType: 'Pressure Cooker',
      onQuickAction: (action) {
        if (action == 'plus_1') {
          _incrementWhistle();
        } else if (action == 'minus_1') {
          _decrementWhistle();
        } else if (action == 'stop') {
          _stopAlarm();
        }
      },
      onInterruptionAlert: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      onSessionCompleted: () {
        _triggerAlarm();
      },
    );

    // Keep screen awake during active cooking session
    KitchenWakeLock.enable();
  }

  @override
  void dispose() {
    _alarmPulseTimer?.cancel();
    _pulseController.dispose();
    _backgroundController.dispose();
    KitchenWakeLock.disable();
    super.dispose();
  }

  Future<void> _toggleListeningMode() async {
    if (_isAcousticMode) {
      await _backgroundController.stopSession();
      setState(() {
        _isAcousticMode = false;
      });
    } else {
      final decision = await MicrophonePrivacyPrimerDialog.show(
        context,
        language: widget.currentLanguage,
      );
      if (decision == MicrophonePrimerDecision.allowAcoustic) {
        setState(() {
          _isAcousticMode = true;
        });
        await _backgroundController.startSession(
          currentWhistles: _currentWhistles,
          targetWhistles: _targetWhistles,
        );
      }
    }
  }

  void _triggerAlarm() {
    if (_isAlarmActive) return;
    setState(() {
      _isAlarmActive = true;
    });

    _pulseController.repeat(reverse: true);

    // Provide immediate auditory & haptic feedback
    if (!_isMuted) {
      SystemSound.play(SystemSoundType.alert);
    }
    HapticFeedback.heavyImpact();

    // Pulse haptics & alert tone every 1.5 seconds until silenced
    _alarmPulseTimer?.cancel();
    _alarmPulseTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!_isAlarmActive) {
        timer.cancel();
        return;
      }
      if (!_isMuted) {
        SystemSound.play(SystemSoundType.alert);
      }
      HapticFeedback.vibrate();
    });
  }

  void _stopAlarm() {
    _alarmPulseTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isAlarmActive = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _incrementWhistle() {
    setState(() {
      _currentWhistles++;
    });
    HapticFeedback.heavyImpact();
    _backgroundController.updateProgress(
      currentWhistles: _currentWhistles,
      targetWhistles: _targetWhistles,
    );

    if (_currentWhistles >= _targetWhistles) {
      _triggerAlarm();
    }
  }

  void _decrementWhistle() {
    if (_currentWhistles > 0) {
      setState(() {
        _currentWhistles--;
        if (_currentWhistles < _targetWhistles && _isAlarmActive) {
          _stopAlarm();
        }
      });
      HapticFeedback.lightImpact();
      _backgroundController.updateProgress(
        currentWhistles: _currentWhistles,
        targetWhistles: _targetWhistles,
      );
    }
  }

  void _resetCounter() {
    _stopAlarm();
    setState(() {
      _currentWhistles = 0;
    });
    HapticFeedback.mediumImpact();
    _backgroundController.updateProgress(
      currentWhistles: _currentWhistles,
      targetWhistles: _targetWhistles,
    );
  }

  void _nextStep() {
    final totalSteps = widget.recipe?.steps.length ?? 1;
    if (_currentStepIndex < totalSteps - 1) {
      setState(() {
        _currentStepIndex++;
      });
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final recipeTitle = recipe != null
        ? (_isNepali ? recipe.titleNe : recipe.titleEn)
        : (_isNepali ? 'प्रेसर कुकर सिट्ठी काउन्टर' : 'Pressure Cooker Siti Counter');

    return Scaffold(
      backgroundColor: _isAlarmActive ? const Color(0xFFFFF3F0) : SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          recipeTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
          ),
        ),
        actions: [
          // Wake Lock Active Badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: Colors.green.shade800),
                const SizedBox(width: 2),
                Text(
                  _isNepali ? 'स्क्रिन अन' : 'Awake',
                  style: NepaliTypography.labelSmall.copyWith(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Mute / Unmute Button
          IconButton(
            icon: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: SitiColors.dark,
            ),
            tooltip: _isMuted ? 'Unmute Alarm' : 'Mute Alarm',
            onPressed: () {
              setState(() {
                _isMuted = !_isMuted;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Alarm Banner (If active)
              if (_isAlarmActive) ...[
                _buildAlarmBanner(),
                const SizedBox(height: 16),
              ],

              // Acoustic vs Manual Mode Toggle Banner with Privacy Primer Link
              _buildListeningModePill(),
              const SizedBox(height: 12),

              // 2-Meter Glanceable Siti Counter Canvas
              _buildGlanceableSitiCanvas(),
              const SizedBox(height: 16),

              // Large Tactile Fallback Buttons (+1 / -1)
              _buildManualControls(),
              const SizedBox(height: 20),

              // Active Step Card with Cooktop Heat Guidance
              _buildActiveStepCard(),
              const SizedBox(height: 20),

              // Quick Reset or Complete Button
              _buildFooterActions(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListeningModePill() {
    return InkWell(
      key: const Key('listening_mode_toggle'),
      onTap: _toggleListeningMode,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isAcousticMode ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isAcousticMode ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _isAcousticMode ? Icons.mic_rounded : Icons.touch_app_rounded,
                  size: 20,
                  color: _isAcousticMode ? Colors.blue.shade800 : Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAcousticMode
                      ? (_isNepali ? 'माइक सक्रिय (पृष्ठभूमि निगरानी)' : 'Mic Active (Background)')
                      : (_isNepali ? 'म्यानुअल ट्याप मोड' : 'Manual Tap Mode'),
                  style: NepaliTypography.labelMedium.copyWith(
                    color: _isAcousticMode ? Colors.blue.shade900 : Colors.grey.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              _isAcousticMode
                  ? (_isNepali ? 'बन्द गर्नुहोस्' : 'Disable')
                  : (_isNepali ? 'माइक अन गर्नुहोस्' : 'Enable Mic'),
              style: NepaliTypography.labelSmall.copyWith(
                color: _isAcousticMode ? Colors.blue.shade700 : SitiColors.terracotta,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.red,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? '🔔 सिट्ठी पुग्यो! आगो बन्द गर्नुहोस्' : '🔔 Target Reached! Turn off heat',
                  style: NepaliTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isNepali
                      ? 'प्रेसर स्वतः सेलाउन दिनुहोस् (Natural Release)'
                      : 'Allow pressure to release naturally',
                  style: NepaliTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _stopAlarm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(
              _isNepali ? 'अलार्म बन्द' : 'Stop',
              style: NepaliTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlanceableSitiCanvas() {
    final currentStr = _isNepali
        ? NepaliCalendar.toDevanagariDigits(_currentWhistles)
        : '$_currentWhistles';
    final targetStr = _isNepali
        ? NepaliCalendar.toDevanagariDigits(_targetWhistles)
        : '$_targetWhistles';

    final remaining = math.max(0, _targetWhistles - _currentWhistles);
    final statusText = _currentWhistles >= _targetWhistles
        ? (_isNepali ? '✓ सिट्ठी पूरा भयो!' : '✓ Target Reached!')
        : (_isNepali
            ? '${NepaliCalendar.toDevanagariDigits(remaining)} सिट्ठी बाँकी'
            : '$remaining whistle${remaining == 1 ? '' : 's'} remaining');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _isAlarmActive ? Colors.red.shade300 : Colors.grey.shade200,
          width: _isAlarmActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Custom Canvas Ring & Ticks
                CustomPaint(
                  size: const Size(260, 260),
                  painter: SitiWhistlePainter(
                    currentWhistles: _currentWhistles,
                    targetWhistles: _targetWhistles,
                    isAlarmActive: _isAlarmActive,
                  ),
                ),

                // Center Typography: 2-Meter Glanceable
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currentStr,
                          style: TextStyle(
                            fontSize: 78,
                            fontWeight: FontWeight.w900,
                            color: _isAlarmActive ? Colors.red.shade700 : SitiColors.terracotta,
                            height: 1.0,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '/',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w300,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                        Text(
                          targetStr,
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isNepali ? 'सिट्ठी (SITI)' : 'WHISTLES',
                      style: NepaliTypography.labelLarge.copyWith(
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Remaining Status Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _currentWhistles >= _targetWhistles
                  ? Colors.green.shade50
                  : SitiColors.warmWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _currentWhistles >= _targetWhistles
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              statusText,
              style: NepaliTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: _currentWhistles >= _targetWhistles
                    ? Colors.green.shade900
                    : Colors.brown.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualControls() {
    return Row(
      children: [
        // -1 Whistle Fallback
        Expanded(
          flex: 1,
          child: ElevatedButton.icon(
            onPressed: _currentWhistles > 0 ? _decrementWhistle : null,
            icon: const Icon(Icons.remove_rounded, size: 24),
            label: Text(
              _isNepali ? '-१' : '-1',
              style: NepaliTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: SitiColors.dark,
              elevation: 1,
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // +1 Whistle Fallback (Primary Big Button)
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _incrementWhistle,
            icon: const Icon(Icons.add_rounded, size: 28),
            label: Text(
              _isNepali ? '+१ सिट्ठी (+1 Siti)' : '+1 Whistle',
              style: NepaliTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SitiColors.terracotta,
              foregroundColor: Colors.white,
              elevation: 2,
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveStepCard() {
    final recipe = widget.recipe;
    final steps = recipe?.steps ?? [];
    final currentStep = steps.isNotEmpty && _currentStepIndex < steps.length
        ? steps[_currentStepIndex]
        : null;

    final instructionText = currentStep != null
        ? (_isNepali ? currentStep.instructionNe : currentStep.instructionEn)
        : (_isNepali
            ? 'कुकरमा मध्यम आगोमा सिट्ठी लगाउनुहोस् र लक्षित सिट्ठी गन्नुहोस्।'
            : 'Cook on medium heat and track pressure whistles until target count is reached.');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SitiColors.terracotta.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant_rounded,
                        size: 18, color: SitiColors.terracotta),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isNepali
                        ? 'सक्रिय चरण ${NepaliCalendar.toDevanagariDigits(_currentStepIndex + 1)}'
                        : 'Active Step ${_currentStepIndex + 1}',
                    style: NepaliTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: SitiColors.dark,
                    ),
                  ),
                ],
              ),
              if (steps.length > 1)
                Text(
                  _isNepali
                      ? '${NepaliCalendar.toDevanagariDigits(_currentStepIndex + 1)} / ${NepaliCalendar.toDevanagariDigits(steps.length)}'
                      : '${_currentStepIndex + 1} / ${steps.length}',
                  style: NepaliTypography.bodySmall.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Instruction Text
          Text(
            instructionText,
            style: NepaliTypography.bodyLarge.copyWith(
              color: SitiColors.dark,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Cooktop Heat Guidance Pill
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 20,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali
                            ? 'ताप मार्गदर्शन (${_cooktop.labelNe})'
                            : 'Heat Guidance (${_cooktop.labelEn})',
                        style: NepaliTypography.labelMedium.copyWith(
                          color: Colors.brown.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isNepali ? _cooktop.heatGuidanceNe : _cooktop.heatGuidanceEn,
                        style: NepaliTypography.bodySmall.copyWith(
                          color: Colors.brown.shade800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Step Pagination Buttons
          if (steps.length > 1) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _currentStepIndex > 0 ? _prevStep : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(_isNepali ? 'अघिल्लो' : 'Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SitiColors.dark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _currentStepIndex < steps.length - 1 ? _nextStep : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(_isNepali ? 'पछिल्लो चरण' : 'Next Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SitiColors.terracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return Row(
      children: [
        // Reset Counter
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetCounter,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_isNepali ? 'सिट्ठी रिसेट' : 'Reset Counter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Finish Cooking
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _stopAlarm();
              if (widget.onSessionComplete != null) {
                widget.onSessionComplete!();
              }
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(_isNepali ? 'खाना तयार भयो' : 'Finish Cooking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
