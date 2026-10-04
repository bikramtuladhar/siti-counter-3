import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siti_counter/audio/whistle_detector.dart';
import 'package:siti_counter/screens/active_cooking_session_screen.dart';

void main() {
  group('WhistleDetector Multi-Appliance Signal Tests', () {
    test('springValveHiss detects pressure onset and completion', () {
      final events = <SignalEngineEvent>[];
      bool targetReached = false;

      final detector = WhistleDetector(
        signalType: CookingSignalType.springValveHiss,
        targetSimmerSeconds: 2,
        onSignalEvent: events.add,
        onTargetReached: () => targetReached = true,
      );

      expect(detector.signalType, equals(CookingSignalType.springValveHiss));

      // 1. High frequency steam hiss for 2.2 seconds (22 frames of 100ms at 5,500 Hz)
      for (int i = 0; i < 22; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.04,
          highHissBandEnergy: 0.18,
          dominantFrequencyHz: 5500.0,
          durationMs: 100,
        ));
      }

      expect(events.any((e) => e.status == 'pressure_reached'), isTrue);

      // 2. Simmer for 2 seconds (20 frames)
      for (int i = 0; i < 20; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.20,
          whistleBandEnergy: 0.03,
          highHissBandEnergy: 0.15,
          dominantFrequencyHz: 5200.0,
          durationMs: 100,
        ));
      }

      expect(detector.isTargetReached, isTrue);
      expect(targetReached, isTrue);
    });

    test('electricBeep detects completion chimes', () {
      final events = <SignalEngineEvent>[];
      bool targetReached = false;

      final detector = WhistleDetector(
        signalType: CookingSignalType.electricBeep,
        targetBeepCount: 3,
        onSignalEvent: events.add,
        onTargetReached: () => targetReached = true,
      );

      void emitBeep(int durationMs) {
        final frames = durationMs ~/ 50;
        for (int i = 0; i < frames; i++) {
          detector.processFrame(const AcousticFrameMetrics(
            totalRmsEnergy: 0.30,
            whistleBandEnergy: 0.02,
            beepBandEnergy: 0.26,
            dominantFrequencyHz: 2800.0,
            durationMs: 50,
          ));
        }
      }

      void emitSilence(int durationMs) {
        final frames = durationMs ~/ 50;
        for (int i = 0; i < frames; i++) {
          detector.processFrame(const AcousticFrameMetrics(
            totalRmsEnergy: 0.01,
            whistleBandEnergy: 0.001,
            beepBandEnergy: 0.001,
            dominantFrequencyHz: 100.0,
            durationMs: 50,
          ));
        }
      }

      // 3 rhythmic beeps
      emitBeep(200);
      emitSilence(150);
      expect(detector.detectedBeeps, equals(1));

      emitBeep(200);
      emitSilence(150);
      expect(detector.detectedBeeps, equals(2));

      emitBeep(200);
      emitSilence(50);
      expect(detector.detectedBeeps, equals(3));
      expect(detector.isTargetReached, isTrue);
      expect(targetReached, isTrue);
    });

    test('mechanicalClick detects rice cooker transition to Warm', () {
      final events = <SignalEngineEvent>[];
      bool targetReached = false;

      final detector = WhistleDetector(
        signalType: CookingSignalType.mechanicalClick,
        onSignalEvent: events.add,
        onTargetReached: () => targetReached = true,
      );

      // 1. Active boiling (2.0s)
      for (int i = 0; i < 20; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.28,
          whistleBandEnergy: 0.04,
          dominantFrequencyHz: 800.0,
          durationMs: 100,
          crestFactor: 1.4,
        ));
      }

      // 2. Mechanical click impulse
      detector.processFrame(const AcousticFrameMetrics(
        totalRmsEnergy: 0.45,
        whistleBandEnergy: 0.05,
        dominantFrequencyHz: 2200.0,
        durationMs: 100,
        crestFactor: 3.8,
      ));
      expect(events.any((e) => e.status == 'click_detected'), isTrue);

      // 3. Post-click thermal drop (quiet hum, 2.2s)
      for (int i = 0; i < 22; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.03,
          whistleBandEnergy: 0.001,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
          crestFactor: 1.2,
        ));
      }

      expect(detector.isTargetReached, isTrue);
      expect(targetReached, isTrue);
    });

    test('kettleWhistle detects continuous resonant boil whistle', () {
      final events = <SignalEngineEvent>[];
      bool targetReached = false;

      final detector = WhistleDetector(
        signalType: CookingSignalType.kettleWhistle,
        onSignalEvent: events.add,
        onTargetReached: () => targetReached = true,
      );

      // Continuous 2,800 Hz whistle for 3.5 seconds
      for (int i = 0; i < 35; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.35,
          whistleBandEnergy: 0.28,
          dominantFrequencyHz: 2800.0,
          durationMs: 100,
        ));
      }

      expect(detector.isTargetReached, isTrue);
      expect(targetReached, isTrue);
    });
  });

  group('ActiveCookingSessionScreen Multi-Signal Widget Tests', () {
    testWidgets('switches between cooker appliance types and renders specialized canvas',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ActiveCookingSessionScreen(
            currentLanguage: 'ne',
            targetWhistles: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initially weighted pressure cooker is selected
      expect(find.text('सिट्ठी (SITI)'), findsOneWidget);
      expect(find.text('+१ सिट्ठी (+1 Siti)'), findsOneWidget);

      // 2. Tap Spring-Valve chip
      final springChip = find.text('स्प्रिङ भल्भ (Hiss)');
      await tester.tap(springChip);
      await tester.pumpAndSettle();

      expect(find.text('स्प्रिङ भल्भ प्रेसर कुकर'), findsOneWidget);
      expect(find.textContaining('निरन्तर बाफ'), findsOneWidget);

      // 3. Tap Electric Cooker chip
      final electricChip = find.text('विद्युतीय (Beep)');
      await tester.tap(electricChip);
      await tester.pumpAndSettle();

      expect(find.text('विद्युतीय प्रेसर कुकर'), findsOneWidget);
      expect(find.textContaining('बिप आवाज'), findsOneWidget);

      // 4. Tap Rice Cooker chip (scroll to it if offscreen)
      final riceChip = find.text('राइस कुकर (Click)');
      await tester.ensureVisible(riceChip);
      await tester.tap(riceChip);
      await tester.pumpAndSettle();

      expect(find.text('पारम्परिक राइस कुकर'), findsOneWidget);
      expect(find.textContaining('क्लिक'), findsWidgets);

      // 5. Tap Kettle chip (scroll to it if offscreen)
      final kettleChip = find.text('किट्ली (Kettle)');
      await tester.ensureVisible(kettleChip);
      await tester.tap(kettleChip);
      await tester.pumpAndSettle();

      expect(find.text('उम्लने चिया किट्ली'), findsOneWidget);
      expect(find.textContaining('पानी उम्लँदा'), findsOneWidget);

      // 6. Tap ready button triggers alarm
      final readyBtn = find.text('तयार भयो (Target Reached)');
      await tester.tap(readyBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Target Reached'), findsOneWidget);
    });

    testWidgets('triggers alarm when detector processes target completion frame',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detector = WhistleDetector(
        signalType: CookingSignalType.kettleWhistle,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveCookingSessionScreen(
            currentLanguage: 'en',
            signalType: CookingSignalType.kettleWhistle,
            detector: detector,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continuous Resonant Kettle Whistle'), findsOneWidget);

      // Feed kettle whistle frames for 3.5 seconds
      for (int i = 0; i < 35; i++) {
        detector.processFrame(const AcousticFrameMetrics(
          totalRmsEnergy: 0.35,
          whistleBandEnergy: 0.28,
          dominantFrequencyHz: 2800.0,
          durationMs: 100,
        ));
      }

      await tester.pump(const Duration(milliseconds: 300));

      // Alarm banner should appear!
      expect(find.textContaining('Target Reached'), findsOneWidget);
    });
  });
}
