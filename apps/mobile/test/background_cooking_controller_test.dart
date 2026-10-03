import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/audio/background_cooking_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundCookingController', () {
    test('initializes with acoustic listening mode and default parameters', () {
      final controller = BackgroundCookingController(
        dishName: 'काउली आलु तरकारी',
        cookerType: 'Pressure Cooker',
        estimatedSecondsPerWhistle: 120,
      );

      expect(controller.mode, equals(CookingSessionMode.acousticListening));
      expect(controller.fallbackSecondsRemaining, equals(0));
      expect(controller.dishName, equals('काउली आलु तरकारी'));
      expect(controller.cookerType, equals('Pressure Cooker'));
      expect(controller.isServiceRunning, isFalse);

      controller.dispose();
    });

    test('startSession sets mode and invokes platform hooks safely', () async {
      final controller = BackgroundCookingController(
        dishName: 'नेपाली खसीको मासु',
      );

      await controller.startSession(
        currentWhistles: 1,
        targetWhistles: 5,
        currentStep: 'Step 2',
      );

      expect(controller.mode, equals(CookingSessionMode.acousticListening));

      await controller.updateProgress(
        currentWhistles: 2,
        targetWhistles: 5,
      );

      await controller.stopSession();
      controller.dispose();
    });

    test('gracefully transitions to timer fallback upon audio interruption', () async {
      String? alertMessage;
      int? tickedSeconds;
      bool completed = false;

      final controller = BackgroundCookingController(
        dishName: 'दाल भात',
        estimatedSecondsPerWhistle: 2, // 2 seconds per whistle for fast test
        onInterruptionAlert: (msg) {
          alertMessage = msg;
        },
        onTimerTick: (sec) {
          tickedSeconds = sec;
        },
        onSessionCompleted: () {
          completed = true;
        },
      );

      await controller.startSession(
        currentWhistles: 1,
        targetWhistles: 2, // 1 remaining whistle -> 2 seconds total fallback
      );

      expect(controller.mode, equals(CookingSessionMode.acousticListening));

      // Trigger audio interruption (e.g. phone call / Siri)
      controller.handleAudioInterruptionBegan();

      expect(controller.mode, equals(CookingSessionMode.timerFallback));
      expect(controller.fallbackSecondsRemaining, equals(2));
      expect(alertMessage, contains('Microphone listening was interrupted'));

      // Wait for timer ticks
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(tickedSeconds, isNotNull);

      // Wait for completion
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(controller.mode, equals(CookingSessionMode.completed));
      expect(completed, isTrue);

      controller.dispose();
    });

    test('resumes acoustic listening when interruption ends with canResume true',
        () async {
      String? alertMessage;

      final controller = BackgroundCookingController(
        dishName: 'क्वॉती',
        estimatedSecondsPerWhistle: 180,
        onInterruptionAlert: (msg) {
          alertMessage = msg;
        },
      );

      await controller.startSession(currentWhistles: 0, targetWhistles: 4);

      // Interruption starts
      controller.handleAudioInterruptionBegan();
      expect(controller.mode, equals(CookingSessionMode.timerFallback));

      // Interruption ends
      controller.handleAudioInterruptionEnded(canResumeListening: true);
      expect(controller.mode, equals(CookingSessionMode.acousticListening));
      expect(alertMessage, equals('Microphone listening resumed.'));

      controller.dispose();
    });

    test('relays quick action callbacks when invoked', () {
      String? triggeredAction;

      final controller = BackgroundCookingController(
        dishName: 'मस्यौरा',
        onQuickAction: (action) {
          triggeredAction = action;
        },
      );

      controller.onQuickAction?.call('plus_1');
      expect(triggeredAction, equals('plus_1'));

      controller.onQuickAction?.call('minus_1');
      expect(triggeredAction, equals('minus_1'));

      controller.onQuickAction?.call('stop');
      expect(triggeredAction, equals('stop'));

      controller.dispose();
    });
  });
}
