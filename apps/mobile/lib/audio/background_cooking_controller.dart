import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'whistle_detector.dart';

/// Top-level callback for the foreground task isolate.
@pragma('vm:entry-point')
void startCookingForegroundTask() {
  FlutterForegroundTask.setTaskHandler(SitiKitchenTaskHandler());
}

/// Task handler running inside the background isolate for Android foreground service.
class SitiKitchenTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    // Relay notification button presses back to the main isolate
    FlutterForegroundTask.sendDataToMain({'action': id});
  }

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}

/// Execution mode of the cooking session.
enum CookingSessionMode {
  /// Acoustic whistle detection active via microphone.
  acousticListening,

  /// Fallback countdown timer active when audio capture is interrupted.
  timerFallback,

  /// Cooking target reached.
  completed,
}

/// Controls background cooking sessions and orchestrates native Android foreground
/// services, iOS Live Activities/Dynamic Island via ActivityKit, and graceful timer fallbacks.
class BackgroundCookingController {
  static const MethodChannel _liveActivityChannel =
      MethodChannel('com.siticounter.app/live_activity');
  static const MethodChannel _audioSessionChannel =
      MethodChannel('com.siticounter.app/audio_session');

  final WhistleDetector? detector;
  final String dishName;
  final String cookerType;
  final int estimatedSecondsPerWhistle;

  CookingSessionMode _mode = CookingSessionMode.acousticListening;
  Timer? _fallbackTimer;
  int _fallbackSecondsRemaining = 0;
  bool _isServiceRunning = false;

  int _currentWhistles = 0;
  int _targetWhistles = 4;
  String _currentStep = '';

  // Notification / Alert callbacks
  final void Function(String action)? onQuickAction; // 'plus_1', 'minus_1', 'stop'
  final void Function(String message)? onInterruptionAlert;
  final void Function(int secondsRemaining)? onTimerTick;
  final void Function()? onSessionCompleted;

  BackgroundCookingController({
    this.detector,
    required this.dishName,
    this.cookerType = 'Pressure Cooker',
    this.estimatedSecondsPerWhistle = 180, // Default 3 min per whistle estimate
    this.onQuickAction,
    this.onInterruptionAlert,
    this.onTimerTick,
    this.onSessionCompleted,
  }) {
    _initForegroundTaskDataCallback();
  }

  CookingSessionMode get mode => _mode;
  int get fallbackSecondsRemaining => _fallbackSecondsRemaining;
  bool get isServiceRunning => _isServiceRunning;

  void _initForegroundTaskDataCallback() {
    try {
      FlutterForegroundTask.addTaskDataCallback((data) {
        if (data is Map && data.containsKey('action')) {
          final action = data['action'] as String;
          onQuickAction?.call(action);
        }
      });
    } catch (_) {
      // Platform / testing environment fallback
    }
  }

  /// Initialize Android foreground task options if running on Android.
  Future<void> initForegroundTask() async {
    try {
      if (Platform.isAndroid) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'siti_counter_cooking_channel',
            channelName: 'Siti Counter Active Cooking',
            channelDescription:
                'Monitors pressure cooker whistles in background with quick actions',
            channelImportance: NotificationChannelImportance.HIGH,
            priority: NotificationPriority.HIGH,
          ),
          iosNotificationOptions: const IOSNotificationOptions(
            showNotification: false,
            playSound: false,
          ),
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.nothing(),
            autoRunOnBoot: false,
            autoRunOnMyPackageReplaced: false,
            allowWakeLock: true,
            allowWifiLock: false,
          ),
        );
      }
    } catch (_) {
      // Ignore during test mocks
    }
  }

  /// Starts the background cooking session on Android and iOS.
  Future<void> startSession({
    int currentWhistles = 0,
    int targetWhistles = 4,
    String currentStep = '',
  }) async {
    _mode = CookingSessionMode.acousticListening;
    _currentWhistles = currentWhistles;
    _targetWhistles = targetWhistles;
    _currentStep = currentStep;

    // 1. Configure iOS Audio Session & Start Live Activity if on iOS
    try {
      if (Platform.isIOS) {
        await _audioSessionChannel.invokeMethod('configureAudioSession');
        await _liveActivityChannel.invokeMethod('startLiveActivity', {
          'dishName': dishName,
          'cookerType': cookerType,
          'currentSiti': _currentWhistles,
          'targetSiti': _targetWhistles,
          'currentStep': _currentStep,
        });
      }
    } catch (_) {
      // Platform channels not bound in unit tests / mock environment
    }

    // 2. Start Android Foreground Service with persistent notification and quick actions
    try {
      if (Platform.isAndroid) {
        await initForegroundTask();
        await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.microphone],
          notificationTitle: dishName,
          notificationText: 'सिट्ठी: $_currentWhistles / $_targetWhistles (Listening...)',
          notificationButtons: const [
            NotificationButton(id: 'stop', text: 'Stop'),
            NotificationButton(id: 'plus_1', text: '+1 Siti'),
            NotificationButton(id: 'minus_1', text: '-1 Siti'),
          ],
          callback: startCookingForegroundTask,
        );
        _isServiceRunning = true;
      }
    } catch (_) {
      // Platform channels not bound in unit tests
    }
  }

  /// Updates whistle progress across native Android notification and iOS ActivityKit.
  Future<void> updateProgress({
    required int currentWhistles,
    required int targetWhistles,
    String? currentStep,
  }) async {
    _currentWhistles = currentWhistles;
    _targetWhistles = targetWhistles;
    if (currentStep != null) {
      _currentStep = currentStep;
    }

    final isTargetReached = _currentWhistles >= _targetWhistles;
    final statusText = isTargetReached
        ? '🔔 सिट्ठी पूरा भयो! आगो बन्द गर्नुहोस् (Target Reached)'
        : 'सिट्ठी: $_currentWhistles / $_targetWhistles';

    // Update Android notification
    try {
      if (Platform.isAndroid && _isServiceRunning) {
        await FlutterForegroundTask.updateService(
          notificationTitle: dishName,
          notificationText: statusText,
          notificationButtons: const [
            NotificationButton(id: 'stop', text: 'Stop'),
            NotificationButton(id: 'plus_1', text: '+1 Siti'),
            NotificationButton(id: 'minus_1', text: '-1 Siti'),
          ],
        );
      }
    } catch (_) {
      // Ignore during test mocks
    }

    // Update iOS Live Activity
    try {
      if (Platform.isIOS) {
        await _liveActivityChannel.invokeMethod('updateLiveActivity', {
          'currentSiti': _currentWhistles,
          'targetSiti': _targetWhistles,
          'currentStep': _currentStep,
        });
      }
    } catch (_) {
      // Ignore during test mocks
    }
  }

  /// Stops the background cooking session and cleans up native notifications/activities.
  Future<void> stopSession() async {
    _fallbackTimer?.cancel();

    try {
      if (Platform.isAndroid && _isServiceRunning) {
        await FlutterForegroundTask.stopService();
        _isServiceRunning = false;
      }
    } catch (_) {
      // Ignore
    }

    try {
      if (Platform.isIOS) {
        await _liveActivityChannel.invokeMethod('endLiveActivity');
      }
    } catch (_) {
      // Ignore
    }
  }

  /// Called when operating system interrupts audio capture (e.g. phone call, Siri, OS suspension).
  void handleAudioInterruptionBegan() {
    if (_mode == CookingSessionMode.completed) return;

    _mode = CookingSessionMode.timerFallback;
    final remainingWhistles = (_targetWhistles - _currentWhistles).clamp(1, 99);
    _fallbackSecondsRemaining = remainingWhistles * estimatedSecondsPerWhistle;

    onInterruptionAlert?.call(
      'Microphone listening was interrupted by your phone. Switched to backup timer: '
      '${(_fallbackSecondsRemaining / 60).ceil()} min remaining.',
    );

    // Update notification with backup timer info
    try {
      if (Platform.isAndroid && _isServiceRunning) {
        FlutterForegroundTask.updateService(
          notificationTitle: '$dishName (Backup Timer)',
          notificationText: '⏱️ ${(_fallbackSecondsRemaining / 60).ceil()} min remaining',
        );
      }
    } catch (_) {}

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_fallbackSecondsRemaining > 0) {
        _fallbackSecondsRemaining--;
        onTimerTick?.call(_fallbackSecondsRemaining);
        if (_fallbackSecondsRemaining == 0) {
          timer.cancel();
          _mode = CookingSessionMode.completed;
          onSessionCompleted?.call();
        }
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
      updateProgress(currentWhistles: _currentWhistles, targetWhistles: _targetWhistles);
    }
  }

  /// Dispose timers and clean up background resources.
  void dispose() {
    _fallbackTimer?.cancel();
    stopSession();
  }
}
