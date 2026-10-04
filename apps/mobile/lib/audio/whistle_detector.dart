import 'package:kitchen_engine/kitchen_engine.dart';

export 'package:kitchen_engine/kitchen_engine.dart'
    show
        CookingSignalType,
        AcousticFrame,
        SignalEngineEvent,
        CookingSignalEngine,
        WeightedWhistleClassifier,
        SpringValveHissClassifier,
        ElectricBeepClassifier,
        MechanicalClickClassifier,
        KettleWhistleClassifier;

/// State of the acoustic whistle detector.
enum WhistleDetectorState {
  /// Actively listening to ambient kitchen sounds.
  idle,

  /// Detected rising acoustic energy in steam whistle band.
  potentialWhistle,

  /// Confirmed whistling venting phase in progress.
  venting,

  /// Pressure cooker repressurization cooldown (ignores acoustic echoes/noises).
  refractory,
}

/// Represents the acoustic signature of an audio frame.
class AcousticFrameMetrics {
  /// Total audio frame energy (RMS).
  final double totalRmsEnergy;

  /// Energy concentrated in the whistle frequency band (2,500 Hz – 4,500 Hz).
  final double whistleBandEnergy;

  /// Energy concentrated in high-frequency steam hiss band (3,800 Hz – 9,000 Hz).
  final double highHissBandEnergy;

  /// Energy concentrated in pure tone beep band (2,000 Hz – 3,500 Hz).
  final double beepBandEnergy;

  /// Peak dominant frequency detected in Hz.
  final double dominantFrequencyHz;

  /// Frame duration in milliseconds (typically 50ms - 100ms).
  final int durationMs;

  /// Crest factor (ratio of peak to RMS energy, >= 3.0 for sharp clicks).
  final double crestFactor;

  /// Spectral flatness (0.0 = pure tone, 1.0 = white noise).
  final double spectralFlatness;

  const AcousticFrameMetrics({
    required this.totalRmsEnergy,
    required this.whistleBandEnergy,
    double? highHissBandEnergy,
    double? beepBandEnergy,
    required this.dominantFrequencyHz,
    required this.durationMs,
    this.crestFactor = 1.5,
    this.spectralFlatness = 0.5,
  })  : highHissBandEnergy = highHissBandEnergy ?? whistleBandEnergy,
        beepBandEnergy = beepBandEnergy ?? whistleBandEnergy;

  /// Whistle-to-total energy ratio. High ratio indicates tonal whistle over broadband noise.
  double get whistleEnergyRatio =>
      totalRmsEnergy > 0.001 ? whistleBandEnergy / totalRmsEnergy : 0.0;

  /// High hiss to total energy ratio.
  double get hissEnergyRatio =>
      totalRmsEnergy > 0.001 ? highHissBandEnergy / totalRmsEnergy : 0.0;

  /// Beep tone to total energy ratio.
  double get beepEnergyRatio =>
      totalRmsEnergy > 0.001 ? beepBandEnergy / totalRmsEnergy : 0.0;

  /// True if dominant frequency falls within steam whistle resonant range.
  bool get isWhistleFrequency =>
      dominantFrequencyHz >= 2400.0 && dominantFrequencyHz <= 4500.0;

  /// True if dominant frequency falls within steam hiss range.
  bool get isHissFrequency =>
      dominantFrequencyHz >= 3800.0 && dominantFrequencyHz <= 9000.0;

  /// True if dominant frequency falls within electronic buzzer range.
  bool get isBeepFrequency =>
      dominantFrequencyHz >= 2000.0 && dominantFrequencyHz <= 3500.0;

  /// True if frame represents an impulsive transient click.
  bool get isTransientImpulse => crestFactor >= 3.0 && totalRmsEnergy >= 0.12;

  /// Converts this metrics object to the domain engine's [AcousticFrame].
  AcousticFrame toAcousticFrame() => AcousticFrame(
        totalRmsEnergy: totalRmsEnergy,
        whistleBandEnergy: whistleBandEnergy,
        highHissBandEnergy: highHissBandEnergy,
        beepBandEnergy: beepBandEnergy,
        dominantFrequencyHz: dominantFrequencyHz,
        durationMs: durationMs,
        crestFactor: crestFactor,
        spectralFlatness: spectralFlatness,
      );
}

/// Acoustic classifier and temporal integrator for kitchen cooking signal detection.
/// Supports traditional pressure cookers, European spring-valves, electric cookers,
/// rice cookers, and boiling kettles.
class WhistleDetector {
  // Acoustic thresholds
  static const double minWhistleRms = 0.05; // Minimum volume threshold
  static const double minEnergyRatio = 0.45; // Must have concentrated band energy
  static const int minVentingDurationMs = 1000; // Whistles last at least 1.0 second
  static const int maxVentingDurationMs = 6000; // Whistles rarely exceed 6.0 seconds
  static const int refractoryPeriodMs = 8000; // Cooker repressurizes for >= 8s

  final CookingSignalType signalType;

  // State (for weightedWhistle mode)
  WhistleDetectorState _state = WhistleDetectorState.idle;
  int _sustainedVentingMs = 0;
  int _refractoryRemainingMs = 0;
  int _consecutiveNoiseFrames = 0;

  // Session
  int _whistleCount = 0;
  final int targetWhistleCount;
  final int targetSimmerSeconds;
  final int targetBeepCount;

  // Signal engine instance (for non-weighted or unified modes)
  late final CookingSignalEngine _signalEngine;

  // Callbacks
  final void Function(int currentCount)? onWhistleDetected;
  final void Function()? onTargetReached;
  final void Function(SignalEngineEvent event)? onSignalEvent;

  WhistleDetector({
    this.signalType = CookingSignalType.weightedWhistle,
    this.targetWhistleCount = 3,
    this.targetSimmerSeconds = 300,
    this.targetBeepCount = 3,
    this.onWhistleDetected,
    this.onTargetReached,
    this.onSignalEvent,
  }) {
    _signalEngine = CookingSignalEngine(
      activeType: signalType,
      targetWhistles: targetWhistleCount,
      targetSimmerSeconds: targetSimmerSeconds,
      targetBeeps: targetBeepCount,
      onEvent: (event) {
        onSignalEvent?.call(event);
        if (event.isTargetReached) {
          onTargetReached?.call();
        }
      },
    );
  }

  WhistleDetectorState get state => _state;
  int get whistleCount =>
      signalType == CookingSignalType.weightedWhistle ? _whistleCount : _signalEngine.whistleCount;
  int get elapsedSimmerSeconds => _signalEngine.elapsedSimmerSeconds;
  int get detectedBeeps => _signalEngine.detectedBeeps;
  bool get isTargetReached =>
      signalType == CookingSignalType.weightedWhistle
          ? _whistleCount >= targetWhistleCount
          : _signalEngine.isTargetReached;

  /// Processes an incoming acoustic frame from microphone analysis.
  void processFrame(AcousticFrameMetrics frame) {
    if (signalType != CookingSignalType.weightedWhistle) {
      _signalEngine.processFrame(frame.toAcousticFrame());
      return;
    }

    // 1. Handle refractory period (repressurization debounce)
    if (_state == WhistleDetectorState.refractory) {
      _refractoryRemainingMs -= frame.durationMs;
      if (_refractoryRemainingMs <= 0) {
        _refractoryRemainingMs = 0;
        _state = WhistleDetectorState.idle;
      }
      return;
    }

    // 2. Evaluate if frame matches whistle acoustic signature
    final isWhistleSignature = frame.totalRmsEnergy >= minWhistleRms &&
        frame.whistleEnergyRatio >= minEnergyRatio &&
        frame.isWhistleFrequency;

    if (isWhistleSignature) {
      _consecutiveNoiseFrames = 0;
      _sustainedVentingMs += frame.durationMs;

      if (_sustainedVentingMs >= minVentingDurationMs &&
          _state != WhistleDetectorState.venting) {
        _state = WhistleDetectorState.venting;
        onSignalEvent?.call(SignalEngineEvent(
          signalType: CookingSignalType.weightedWhistle,
          status: 'venting_start',
          message: 'Pressure cooker whistle venting...',
          confidence: 0.85,
          currentCount: _whistleCount,
          targetCount: targetWhistleCount,
        ));
      }
    } else {
      // Allow minor brief dropouts (up to 250ms) within continuous venting
      _consecutiveNoiseFrames++;
      if (_consecutiveNoiseFrames * frame.durationMs >= 250) {
        if (_state == WhistleDetectorState.venting &&
            _sustainedVentingMs >= minVentingDurationMs &&
            _sustainedVentingMs <= maxVentingDurationMs) {
          // Confirmed completed whistle event!
          _registerWhistle();
        } else {
          // Reset false alarm / brief sound
          _resetDetection();
        }
      }
    }
  }

  void _registerWhistle() {
    _whistleCount++;
    _state = WhistleDetectorState.refractory;
    _refractoryRemainingMs = refractoryPeriodMs;
    _sustainedVentingMs = 0;
    _consecutiveNoiseFrames = 0;

    onWhistleDetected?.call(_whistleCount);

    final targetReached = _whistleCount >= targetWhistleCount;
    onSignalEvent?.call(SignalEngineEvent(
      signalType: CookingSignalType.weightedWhistle,
      status: targetReached ? 'target_reached' : 'whistle_detected',
      message: targetReached
          ? 'Target whistles reached! Turn off heat.'
          : 'Whistle $_whistleCount of $targetWhistleCount detected.',
      confidence: 0.98,
      isTargetReached: targetReached,
      currentCount: _whistleCount,
      targetCount: targetWhistleCount,
    ));

    if (targetReached) {
      onTargetReached?.call();
    }
  }

  void _resetDetection() {
    _state = WhistleDetectorState.idle;
    _sustainedVentingMs = 0;
    _consecutiveNoiseFrames = 0;
  }

  /// Manual correction: increment whistle count (+1)
  void manualIncrement() {
    if (signalType == CookingSignalType.weightedWhistle) {
      _whistleCount++;
      onWhistleDetected?.call(_whistleCount);
      if (_whistleCount == targetWhistleCount) {
        onTargetReached?.call();
      }
    } else {
      _signalEngine.manualIncrementWhistle();
    }
  }

  /// Manual correction: decrement whistle count (-1)
  void manualDecrement() {
    if (signalType == CookingSignalType.weightedWhistle) {
      if (_whistleCount > 0) {
        _whistleCount--;
        onWhistleDetected?.call(_whistleCount);
      }
    } else {
      _signalEngine.manualDecrementWhistle();
    }
  }

  /// Reset session
  void reset() {
    _whistleCount = 0;
    _state = WhistleDetectorState.idle;
    _sustainedVentingMs = 0;
    _refractoryRemainingMs = 0;
    _consecutiveNoiseFrames = 0;
    _signalEngine.reset();
  }
}
