import 'dart:async';
import 'package:flutter/services.dart';
import 'whistle_detector.dart';

/// Execution mode of the cooking session.
enum CookingSessionMode {
  /// Acoustic whistle detection active via microphone.
  acousticListening,

  /// Fallback countdown timer active when audio capture is interrupted.
  timerFallback,

  /// Cooking target reached.
  completed,
}

/// Controls background cooking sessions and orchestrates graceful timer fallbacks.
class BackgroundCookingController {
  static const MethodChannel _channel = MethodChannel('com.siticounter/cooking_session');

  final WhistleDetector detector;
  final String dishName;
  final int estimatedSecondsPerWhistle;

  CookingSessionMode _mode = CookingSessionMode.acousticListening;
  Timer? _fallbackTimer;
  int _fallbackSecondsRemaining = 0;

  // Notification / Alert callbacks
  final void Function(String message)? onInterruptionAlert;
  final void Function(int secondsRemaining)? onTimerTick;
  final void Function()? onSessionCompleted;

  BackgroundCookingController({
    required this.detector,
    required this.dishName,
    this.estimatedSecondsPerWhistle = 180, // Default 3 min per whistle estimate
    this.onInterruptionAlert,
    this.onTimerTick,
    this.onSessionCompleted,
  });

  CookingSessionMode get mode => _mode;
  int get fallbackSecondsRemaining => _fallbackSecondsRemaining;

  /// Starts the background session.
  Future<void> startSession() async {
    _mode = CookingSessionMode.acousticListening;
    try {
      await _channel.invokeMethod('startLiveActivity', {
        'dishName': dishName,
        'currentSiti': detector.whistleCount,
        'targetSiti': detector.targetWhistleCount,
      });
    } on MissingPluginException {
      // Platform channels not bound in unit tests / mock environment
    }
  }

  /// Called when the operating system interrupts audio capture (e.g. incoming call, Siri, OS suspension).
  void handleAudioInterruptionBegan() {
    if (_mode == CookingSessionMode.completed) return;

    _mode = CookingSessionMode.timerFallback;
    final remainingWhistles = detector.targetWhistleCount - detector.whistleCount;
    _fallbackSecondsRemaining = remainingWhistles * estimatedSecondsPerWhistle;

    onInterruptionAlert?.call(
      'Microphone listening was interrupted by your phone. Switched to backup timer: '
      '${(_fallbackSecondsRemaining / 60).ceil()} min remaining.',
    );

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_fallbackSecondsRemaining > 0) {
        _fallbackSecondsRemaining--;
        onTimerTick?.call(_fallbackSecondsRemaining);
      } else {
        timer.cancel();
        _mode = CookingSessionMode.completed;
        onSessionCompleted?.call();
      }
    });
  }

  /// Called when audio interruption ends and microphone capture can resume.
  void handleAudioInterruptionEnded({required bool canResumeListening}) {
    if (canResumeListening && _mode == CookingSessionMode.timerFallback) {
      _fallbackTimer?.cancel();
      _mode = CookingSessionMode.acousticListening;
      onInterruptionAlert?.call('Microphone listening resumed.');
    }
  }

  /// Dispose timers and clean up background resources.
  void dispose() {
    _fallbackTimer?.cancel();
  }
}
