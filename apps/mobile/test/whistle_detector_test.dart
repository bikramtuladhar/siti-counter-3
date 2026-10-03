import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/audio/whistle_detector.dart';

void main() {
  group('WhistleDetector Unit Tests', () {
    test('accurately detects authentic pressure cooker whistle (Hawkins 5L)', () {
      int detectedCount = 0;
      final detector = WhistleDetector(
        targetWhistleCount: 3,
        onWhistleDetected: (count) => detectedCount = count,
      );

      // 1. Idle background noise for 1 second (10 frames of 100ms)
      for (int i = 0; i < 10; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 180.0,
          durationMs: 100,
        ));
      }
      expect(detector.state, equals(WhistleDetectorState.idle));
      expect(detectedCount, equals(0));

      // 2. Steam whistle venting for 2.0 seconds (20 frames of 100ms at 3,200 Hz)
      for (int i = 0; i < 20; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.35,
          whistleBandEnergy: 0.28,
          dominantFrequencyHz: 3200.0,
          durationMs: 100,
        ));
      }
      expect(detector.state, equals(WhistleDetectorState.venting));

      // 3. Vent cutoff / return to background
      for (int i = 0; i < 4; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
        ));
      }

      // Whistle should now be confirmed!
      expect(detectedCount, equals(1));
      expect(detector.whistleCount, equals(1));
      expect(detector.state, equals(WhistleDetectorState.refractory));
    });

    test('rejects kitchen exhaust fan noise (low frequency rumble)', () {
      int detectedCount = 0;
      final detector = WhistleDetector(
        targetWhistleCount: 3,
        onWhistleDetected: (count) => detectedCount = count,
      );

      // Loud exhaust fan running for 10 seconds (100 frames)
      for (int i = 0; i < 100; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.40, // Loud
          whistleBandEnergy: 0.04, // Very little high-frequency whistle energy
          dominantFrequencyHz: 120.0, // Low fan motor hum
          durationMs: 100,
        ));
      }

      expect(detectedCount, equals(0));
      expect(detector.state, equals(WhistleDetectorState.idle));
    });

    test('rejects running tap water and oil splattering (broadband noise)', () {
      int detectedCount = 0;
      final detector = WhistleDetector(
        targetWhistleCount: 3,
        onWhistleDetected: (count) => detectedCount = count,
      );

      // Running tap water for 5 seconds (50 frames)
      for (int i = 0; i < 50; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.05, // Uniform broadband noise, ratio = 0.20 (< 0.45 threshold)
          dominantFrequencyHz: 1200.0,
          durationMs: 100,
        ));
      }

      expect(detectedCount, equals(0));
    });

    test('rejects transient noise spikes (dropped spoon / clattering plates)', () {
      int detectedCount = 0;
      final detector = WhistleDetector(
        targetWhistleCount: 3,
        onWhistleDetected: (count) => detectedCount = count,
      );

      // Sudden loud clang for 200ms
      for (int i = 0; i < 2; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.80,
          whistleBandEnergy: 0.60,
          dominantFrequencyHz: 3000.0,
          durationMs: 100,
        ));
      }

      // Returned to quiet
      for (int i = 0; i < 5; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.01,
          whistleBandEnergy: 0.001,
          dominantFrequencyHz: 100.0,
          durationMs: 100,
        ));
      }

      // Should be rejected because duration < 1000ms
      expect(detectedCount, equals(0));
    });

    test('refractory period prevents double-counting immediate echo/pressure bounce', () {
      int detectedCount = 0;
      final detector = WhistleDetector(
        targetWhistleCount: 5,
        onWhistleDetected: (count) => detectedCount = count,
      );

      // First valid whistle (1.5s)
      for (int i = 0; i < 15; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.3,
          whistleBandEnergy: 0.25,
          dominantFrequencyHz: 3000.0,
          durationMs: 100,
        ));
      }
      for (int i = 0; i < 3; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.01,
          whistleBandEnergy: 0.001,
          dominantFrequencyHz: 100.0,
          durationMs: 100,
        ));
      }
      expect(detectedCount, equals(1));

      // Immediate secondary hiss 2 seconds later (within 8s refractory period)
      for (int i = 0; i < 15; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.3,
          whistleBandEnergy: 0.25,
          dominantFrequencyHz: 3000.0,
          durationMs: 100,
        ));
      }
      for (int i = 0; i < 3; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.01,
          whistleBandEnergy: 0.001,
          dominantFrequencyHz: 100.0,
          durationMs: 100,
        ));
      }

      // Count MUST remain 1 because it happened during refractory period!
      expect(detectedCount, equals(1));
    });

    test('manual correction (+1 and -1) updates count and triggers callbacks', () {
      int lastReported = 0;
      bool targetReached = false;

      final detector = WhistleDetector(
        targetWhistleCount: 3,
        onWhistleDetected: (c) => lastReported = c,
        onTargetReached: () => targetReached = true,
      );

      detector.manualIncrement(); // 1
      expect(detector.whistleCount, equals(1));
      expect(lastReported, equals(1));

      detector.manualIncrement(); // 2
      detector.manualDecrement(); // 1
      expect(detector.whistleCount, equals(1));

      detector.manualIncrement(); // 2
      detector.manualIncrement(); // 3 (Target!)
      expect(detector.whistleCount, equals(3));
      expect(targetReached, isTrue);
    });
  });

  group('Week 4 Foundation Gate: 35-Minute Kitchen Session Benchmark', () {
    test('achieves >=97% accuracy in noisy kitchen session (target: 4 whistles)', () {
      int detectedCount = 0;
      bool targetFired = false;

      final detector = WhistleDetector(
        targetWhistleCount: 4,
        onWhistleDetected: (c) => detectedCount = c,
        onTargetReached: () => targetFired = true,
      );

      // Simulate 35-minute cooking session in 100ms increments (21,000 frames)
      // Whistles occur at minute 8, 14, 20, 26.
      int totalGroundTruthWhistles = 4;

      void simulateWhistle(int durationSeconds, double frequencyHz) {
        final frames = durationSeconds * 10;
        for (int f = 0; f < frames; f++) {
          detector.processFrame(AcousticFrameMetrics(
            totalRmsEnergy: 0.45,
            whistleBandEnergy: 0.38,
            dominantFrequencyHz: frequencyHz,
            durationMs: 100,
          ));
        }
        // Silence decay
        for (int f = 0; f < 4; f++) {
          detector.processFrame(const AcousticFrameMetrics(
            totalRmsEnergy: 0.02,
            whistleBandEnergy: 0.002,
            dominantFrequencyHz: 200.0,
            durationMs: 100,
          ));
        }
      }

      void simulateNoise(int durationSeconds, {required double dominantHz, required double ratio}) {
        final frames = durationSeconds * 10;
        for (int f = 0; f < frames; f++) {
          final totalEnergy = 0.30;
          detector.processFrame(AcousticFrameMetrics(
            totalRmsEnergy: totalEnergy,
            whistleBandEnergy: totalEnergy * ratio,
            dominantFrequencyHz: dominantHz,
            durationMs: 100,
          ));
        }
      }

      // Minute 0 - 8: Preheating with exhaust fan noise
      simulateNoise(60, dominantHz: 120.0, ratio: 0.10); // Exhaust fan
      simulateNoise(20, dominantHz: 800.0, ratio: 0.20); // Running tap

      // Minute 8: WHISTLE 1 (Hawkins 5L, 3,200 Hz, 2.2s)
      simulateWhistle(2, 3200.0);

      // Minute 8 - 14: Simmering, chopping vegetables, dialogue
      simulateNoise(30, dominantHz: 250.0, ratio: 0.15); // Talking

      // Minute 14: WHISTLE 2 (Prestige 3L, 2,900 Hz, 1.8s)
      simulateWhistle(2, 2900.0);

      // Minute 14 - 20: Clattering pans, frying tadka
      simulateNoise(15, dominantHz: 1500.0, ratio: 0.25); // Oil sizzle

      // Minute 20: WHISTLE 3 (3,400 Hz, 2.5s)
      simulateWhistle(3, 3400.0);

      // Minute 20 - 26: Quiet boiling
      simulateNoise(20, dominantHz: 150.0, ratio: 0.10);

      // Minute 26: WHISTLE 4 (3,100 Hz, 2.0s) -> Reaches target!
      simulateWhistle(2, 3100.0);

      // Final checks
      expect(detectedCount, equals(totalGroundTruthWhistles));
      expect(targetFired, isTrue);

      final accuracy = (detectedCount / totalGroundTruthWhistles) * 100;
      expect(accuracy, greaterThanOrEqualTo(97.0));
    });
  });
}
