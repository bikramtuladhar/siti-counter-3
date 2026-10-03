import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/audio/whistle_detector.dart';

void main() {
  group('Low-End Android (2 GB RAM) AOT Performance Spike', () {
    test('cold start initialization finishes within budget (<50ms in VM)', () {
      final stopwatch = Stopwatch()..start();
      final detector = WhistleDetector(targetWhistleCount: 3);
      stopwatch.stop();

      expect(detector.whistleCount, equals(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('processes 10,000 audio frames with minimal latency (<0.05ms per frame)', () {
      final detector = WhistleDetector(targetWhistleCount: 5);

      const frame = AcousticFrameMetrics(
        totalRmsEnergy: 0.15,
        whistleBandEnergy: 0.02,
        dominantFrequencyHz: 250.0,
        durationMs: 100,
      );

      final stopwatch = Stopwatch()..start();
      const frameCount = 10000; // Represents 16.6 minutes of continuous audio
      for (int i = 0; i < frameCount; i++) {
        detector.processFrame(frame);
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      final avgMsPerFrame = totalMs / frameCount;

      // Ensure frame processing is well under 1ms (target <0.05ms) so CPU usage is <1%
      expect(avgMsPerFrame, lessThan(0.05));
    });

    test('memory footprint remains constant and leak-free across 50,000 frames', () {
      final detector = WhistleDetector(targetWhistleCount: 10);

      // Warm up
      for (int i = 0; i < 1000; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.05,
          whistleBandEnergy: 0.005,
          dominantFrequencyHz: 120.0,
          durationMs: 100,
        ));
      }

      final initialMemory = ProcessInfo.currentRss;

      // Process 50,000 frames (representing 83 minutes of continuous listening)
      for (int i = 0; i < 50000; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.05,
          whistleBandEnergy: 0.005,
          dominantFrequencyHz: 120.0,
          durationMs: 100,
        ));
      }

      final finalMemory = ProcessInfo.currentRss;
      final memoryDeltaMb = (finalMemory - initialMemory) / (1024 * 1024);

      // Memory growth across 83 minutes of listening must be negligible (<15 MB)
      expect(memoryDeltaMb, lessThan(15.0));
    });
  });
}
