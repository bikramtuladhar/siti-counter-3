import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CookingSignalEngine - WeightedWhistleClassifier', () {
    test('accurately detects authentic pressure cooker whistle bursts', () {
      final events = <SignalEngineEvent>[];
      final classifier = WeightedWhistleClassifier(
        targetWhistles: 2,
        onEvent: events.add,
      );

      // 1. Idle background noise (1.0s, 10 frames)
      for (int i = 0; i < 10; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
        ));
      }
      expect(classifier.whistleCount, equals(0));
      expect(classifier.state, equals('idle'));

      // 2. Venting whistle 1: 1.5s (15 frames) at 3,200 Hz
      for (int i = 0; i < 15; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.35,
          whistleBandEnergy: 0.28,
          dominantFrequencyHz: 3200.0,
          durationMs: 100,
        ));
      }
      expect(classifier.state, equals('venting'));

      // 3. Vent cutoff / return to quiet (4 frames)
      for (int i = 0; i < 4; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
        ));
      }
      expect(classifier.whistleCount, equals(1));
      expect(classifier.state, equals('refractory'));
      expect(classifier.isTargetReached, isFalse);

      // 4. Refractory bypass (8s cooldown, 80 frames)
      for (int i = 0; i < 80; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
        ));
      }
      expect(classifier.state, equals('idle'));

      // 5. Venting whistle 2: 1.8s (18 frames) -> reaches target!
      for (int i = 0; i < 18; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.40,
          whistleBandEnergy: 0.32,
          dominantFrequencyHz: 3100.0,
          durationMs: 100,
        ));
      }
      for (int i = 0; i < 4; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
        ));
      }

      expect(classifier.whistleCount, equals(2));
      expect(classifier.isTargetReached, isTrue);
      expect(events.any((e) => e.isTargetReached && e.status == 'target_reached'), isTrue);
    });

    test('rejects kitchen rumble and clatter', () {
      final classifier = WeightedWhistleClassifier(targetWhistles: 3);

      // Exhaust fan low rumble (dominant 120Hz)
      for (int i = 0; i < 30; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.40,
          whistleBandEnergy: 0.03,
          dominantFrequencyHz: 120.0,
          durationMs: 100,
        ));
      }
      expect(classifier.whistleCount, equals(0));

      // Clattering spoon spike for 200ms
      for (int i = 0; i < 2; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.80,
          whistleBandEnergy: 0.60,
          dominantFrequencyHz: 3000.0,
          durationMs: 100,
        ));
      }
      for (int i = 0; i < 5; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.01,
          whistleBandEnergy: 0.001,
          dominantFrequencyHz: 100.0,
          durationMs: 100,
        ));
      }
      expect(classifier.whistleCount, equals(0));
    });

    test('supports manual increment and decrement', () {
      final events = <SignalEngineEvent>[];
      final classifier = WeightedWhistleClassifier(targetWhistles: 2, onEvent: events.add);

      classifier.manualIncrement();
      expect(classifier.whistleCount, equals(1));
      expect(classifier.isTargetReached, isFalse);

      classifier.manualIncrement();
      expect(classifier.whistleCount, equals(2));
      expect(classifier.isTargetReached, isTrue);

      classifier.manualDecrement();
      expect(classifier.whistleCount, equals(1));
      expect(classifier.isTargetReached, isFalse);
    });
  });

  group('CookingSignalEngine - SpringValveHissClassifier', () {
    test('detects continuous hiss, pressure onset, simmer timing, and completion', () {
      final events = <SignalEngineEvent>[];
      final classifier = SpringValveHissClassifier(
        targetSimmerSeconds: 5, // 5 seconds for test
        onEvent: events.add,
      );

      // 1. Initial warm-up heating (no hiss)
      for (int i = 0; i < 10; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.03,
          whistleBandEnergy: 0.005,
          highHissBandEnergy: 0.005,
          dominantFrequencyHz: 500.0,
          durationMs: 100,
        ));
      }
      expect(classifier.isAtPressure, isFalse);

      // 2. High-frequency steam hiss begins (5,500 Hz, 2.5s continuous)
      for (int i = 0; i < 25; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.05,
          highHissBandEnergy: 0.18, // hiss ratio = 0.72
          dominantFrequencyHz: 5500.0,
          durationMs: 100,
        ));
      }

      // Reached operating pressure!
      expect(classifier.isAtPressure, isTrue);
      expect(events.any((e) => e.status == 'pressure_reached'), isTrue);

      // 3. Continue simmering for 5 seconds (50 frames)
      for (int i = 0; i < 50; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.20,
          whistleBandEnergy: 0.04,
          highHissBandEnergy: 0.15,
          dominantFrequencyHz: 5200.0,
          durationMs: 100,
        ));
      }

      expect(classifier.isTargetReached, isTrue);
      expect(events.any((e) => e.status == 'target_reached'), isTrue);
    });

    test('alerts on overpressure violent venting and detects loss of pressure', () {
      final events = <SignalEngineEvent>[];
      final classifier = SpringValveHissClassifier(
        targetSimmerSeconds: 60,
        onEvent: events.add,
      );

      // 1. Establish pressure (2.5s)
      for (int i = 0; i < 25; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.05,
          highHissBandEnergy: 0.18,
          dominantFrequencyHz: 5500.0,
          durationMs: 100,
        ));
      }
      expect(classifier.isAtPressure, isTrue);

      // 2. Overpressure: heat left on high, violent steam venting (RMS = 0.75)
      classifier.processFrame(const AcousticFrame(
        totalRmsEnergy: 0.75,
        whistleBandEnergy: 0.10,
        highHissBandEnergy: 0.55,
        dominantFrequencyHz: 6000.0,
        durationMs: 100,
      ));
      expect(events.any((e) => e.status == 'overpressure_alert'), isTrue);

      // 3. Heat turned completely off -> hiss ceases for 4.5 seconds (45 frames)
      for (int i = 0; i < 45; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          highHissBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
        ));
      }
      expect(classifier.isAtPressure, isFalse);
      expect(events.any((e) => e.status == 'pressure_lost'), isTrue);
    });
  });

  group('CookingSignalEngine - ElectricBeepClassifier', () {
    test('detects rhythmic completion beep train (Instant Pot 3-beep pattern)', () {
      final events = <SignalEngineEvent>[];
      final classifier = ElectricBeepClassifier(
        targetBeepCount: 3,
        onEvent: events.add,
      );

      void emitBeep(int durationMs, double freqHz) {
        final frames = durationMs ~/ 50;
        for (int i = 0; i < frames; i++) {
          classifier.processFrame(AcousticFrame(
            totalRmsEnergy: 0.30,
            whistleBandEnergy: 0.02,
            beepBandEnergy: 0.26, // high pure tone ratio 0.86
            dominantFrequencyHz: freqHz,
            durationMs: 50,
          ));
        }
      }

      void emitSilence(int durationMs) {
        final frames = durationMs ~/ 50;
        for (int i = 0; i < frames; i++) {
          classifier.processFrame(const AcousticFrame(
            totalRmsEnergy: 0.02,
            whistleBandEnergy: 0.001,
            beepBandEnergy: 0.001,
            dominantFrequencyHz: 150.0,
            durationMs: 50,
          ));
        }
      }

      // Beep 1 (200ms tone at 2,800 Hz) + 150ms gap
      emitBeep(200, 2800.0);
      emitSilence(150);
      expect(classifier.detectedBeeps, equals(1));

      // Beep 2 (200ms tone at 2,800 Hz) + 150ms gap
      emitBeep(200, 2800.0);
      emitSilence(150);
      expect(classifier.detectedBeeps, equals(2));
      expect(classifier.isTargetReached, isFalse);

      // Beep 3 (200ms tone at 2,800 Hz) -> completion!
      emitBeep(200, 2800.0);
      emitSilence(50);
      expect(classifier.detectedBeeps, equals(3));
      expect(classifier.isTargetReached, isTrue);
      expect(events.any((e) => e.status == 'target_reached'), isTrue);
    });

    test('rejects isolated button click or single microwave beep after silence timeout', () {
      final classifier = ElectricBeepClassifier(targetBeepCount: 3);

      // Single 150ms beep tone
      for (int i = 0; i < 3; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.30,
          whistleBandEnergy: 0.02,
          beepBandEnergy: 0.25,
          dominantFrequencyHz: 2800.0,
          durationMs: 50,
        ));
      }
      // Followed by silence exceeding 600ms (700ms = 14 frames)
      for (int i = 0; i < 14; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.01,
          whistleBandEnergy: 0.001,
          beepBandEnergy: 0.001,
          dominantFrequencyHz: 100.0,
          durationMs: 50,
        ));
      }

      // Counter should reset to 0 after silence timeout
      expect(classifier.detectedBeeps, equals(0));
      expect(classifier.isTargetReached, isFalse);
    });
  });

  group('CookingSignalEngine - MechanicalClickClassifier', () {
    test('confirms warm transition after click impulse and subsequent thermal/boiling drop', () {
      final events = <SignalEngineEvent>[];
      final classifier = MechanicalClickClassifier(onEvent: events.add);

      // 1. Active boiling rice: energetic bubbling noise (2.0 seconds)
      for (int i = 0; i < 20; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.28,
          whistleBandEnergy: 0.04,
          dominantFrequencyHz: 800.0,
          durationMs: 100,
          crestFactor: 1.4,
        ));
      }

      // 2. Magnetic switch trips: mechanical snap (100ms, crest factor 3.8)
      classifier.processFrame(const AcousticFrame(
        totalRmsEnergy: 0.45,
        whistleBandEnergy: 0.05,
        dominantFrequencyHz: 2200.0,
        durationMs: 100,
        crestFactor: 3.8,
      ));
      expect(events.any((e) => e.status == 'click_detected'), isTrue);

      // 3. Post-click thermal drop: heater turns off, water is absorbed, boiling stops (2.2s quiet)
      for (int i = 0; i < 22; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.04, // Dropped to quiet warm hum (< 0.28 * 0.65)
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
          crestFactor: 1.2,
        ));
      }

      expect(classifier.isTargetReached, isTrue);
      expect(events.any((e) => e.status == 'target_reached'), isTrue);
    });

    test('rejects dropped spoon/lid clang if loud boiling continues unabated', () {
      final classifier = MechanicalClickClassifier();

      // Active boiling (2.0s)
      for (int i = 0; i < 20; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.03,
          dominantFrequencyHz: 800.0,
          durationMs: 100,
          crestFactor: 1.4,
        ));
      }

      // Cutlery clatter impulse
      classifier.processFrame(const AcousticFrame(
        totalRmsEnergy: 0.50,
        whistleBandEnergy: 0.05,
        dominantFrequencyHz: 2500.0,
        durationMs: 100,
        crestFactor: 3.5,
      ));

      // Water continues boiling vigorously (energy remains 0.25, no drop)
      for (int i = 0; i < 22; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.03,
          dominantFrequencyHz: 800.0,
          durationMs: 100,
          crestFactor: 1.4,
        ));
      }

      // Should NOT confirm warm because boiling did not drop!
      expect(classifier.isTargetReached, isFalse);
    });
  });

  group('CookingSignalEngine - KettleWhistleClassifier', () {
    test('triggers boil alert on sustained kettle whistle', () {
      final events = <SignalEngineEvent>[];
      final classifier = KettleWhistleClassifier(onEvent: events.add);

      // 1. Water heating, quiet
      for (int i = 0; i < 10; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 300.0,
          durationMs: 100,
        ));
      }

      // 2. Kettle begins whistling: continuous 2,800 Hz resonant tone for 3.5 seconds
      for (int i = 0; i < 35; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.35,
          whistleBandEnergy: 0.28,
          dominantFrequencyHz: 2800.0,
          durationMs: 100,
        ));
      }

      expect(classifier.isTargetReached, isTrue);
      expect(events.any((e) => e.status == 'target_reached'), isTrue);
    });

    test('does not prematurely alert on brief audio spike', () {
      final classifier = KettleWhistleClassifier();

      // Brief whistle for only 1.2s then cuts off
      for (int i = 0; i < 12; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.30,
          whistleBandEnergy: 0.22,
          dominantFrequencyHz: 2800.0,
          durationMs: 100,
        ));
      }
      for (int i = 0; i < 5; i++) {
        classifier.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.01,
          whistleBandEnergy: 0.001,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
        ));
      }

      expect(classifier.isTargetReached, isFalse);
    });
  });

  group('CookingSignalEngine - Unified Interface', () {
    test('dispatches frames correctly to selected active mode', () {
      int targetEvents = 0;

      final engine = CookingSignalEngine(
        activeType: CookingSignalType.springValveHiss,
        targetSimmerSeconds: 2,
        onEvent: (e) {
          if (e.isTargetReached) targetEvents++;
        },
      );

      // Pressure onset (2.2s)
      for (int i = 0; i < 22; i++) {
        engine.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.04,
          highHissBandEnergy: 0.18,
          dominantFrequencyHz: 5500.0,
          durationMs: 100,
        ));
      }
      // Simmer 2 seconds
      for (int i = 0; i < 20; i++) {
        engine.processFrame(const AcousticFrame(
          totalRmsEnergy: 0.20,
          whistleBandEnergy: 0.03,
          highHissBandEnergy: 0.15,
          dominantFrequencyHz: 5200.0,
          durationMs: 100,
        ));
      }

      expect(engine.isTargetReached, isTrue);
      expect(targetEvents, equals(1));
    });
  });
}
