import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/audio/whistle_detector.dart';
import 'package:siti_counter/audio/background_cooking_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('BackgroundCookingController & iOS Fallback Spike', () {
    test('initializes in acoustic listening mode', () async {
      final detector = WhistleDetector(targetWhistleCount: 3);
      final controller = BackgroundCookingController(
        detector: detector,
        dishName: 'Dal Bhat',
      );

      await controller.startSession();
      expect(controller.mode, equals(CookingSessionMode.acousticListening));
      controller.dispose();
    });

    test('gracefully switches to timer fallback on audio interruption', () {
      final detector = WhistleDetector(targetWhistleCount: 3);
      String? alertMessage;

      final controller = BackgroundCookingController(
        detector: detector,
        dishName: 'Dal Bhat',
        estimatedSecondsPerWhistle: 120, // 2 minutes
        onInterruptionAlert: (msg) => alertMessage = msg,
      );

      // 1 whistle already detected, 2 whistles left (4 minutes = 240s)
      detector.manualIncrement();

      controller.handleAudioInterruptionBegan();

      expect(controller.mode, equals(CookingSessionMode.timerFallback));
      expect(controller.fallbackSecondsRemaining, equals(240));
      expect(alertMessage, contains('Switched to backup timer: 4 min remaining'));

      controller.dispose();
    });

    test('resumes acoustic listening when interruption ends successfully', () {
      final detector = WhistleDetector(targetWhistleCount: 3);
      String? alertMessage;

      final controller = BackgroundCookingController(
        detector: detector,
        dishName: 'Dal Bhat',
        onInterruptionAlert: (msg) => alertMessage = msg,
      );

      controller.handleAudioInterruptionBegan();
      expect(controller.mode, equals(CookingSessionMode.timerFallback));

      controller.handleAudioInterruptionEnded(canResumeListening: true);
      expect(controller.mode, equals(CookingSessionMode.acousticListening));
      expect(alertMessage, equals('Microphone listening resumed.'));

      controller.dispose();
    });
  });
}
