/// Cooking Signal Engine for multi-appliance acoustic classification.
/// Supports traditional pressure cooker whistles, European spring-valve hissing,
/// electric cooker beeps, rice cooker mechanical switch clicks, and boiling kettle whistles.
library;

/// Types of cooking acoustic signals classified by the engine.
enum CookingSignalType {
  /// Traditional South Asian pressure cooker with weighted jiggle valve (Hawkins, Prestige).
  weightedWhistle,

  /// European spring-valve pressure cooker with continuous hiss (Kuhn Rikon, WMF, Fagor).
  springValveHiss,

  /// Electric pressure cooker with target completion beeps (Instant Pot, Ninja Foodi).
  electricBeep,

  /// Mechanical rice cooker with magnetic thermostat switch click (Panasonic, Zojirushi).
  mechanicalClick,

  /// Stovetop boiling kettle whistle.
  kettleWhistle,
}

/// Represents the acoustic characteristics of an analyzed audio frame.
class AcousticFrame {
  /// Total audio frame energy (RMS: 0.0 to 1.0).
  final double totalRmsEnergy;

  /// Energy in the steam whistle band (2,400 Hz – 4,500 Hz).
  final double whistleBandEnergy;

  /// Energy in the high-frequency steam hiss band (3,800 Hz – 9,000 Hz).
  final double highHissBandEnergy;

  /// Energy concentrated in pure tone beep band (2,000 Hz – 3,500 Hz).
  final double beepBandEnergy;

  /// Peak dominant frequency detected in Hz.
  final double dominantFrequencyHz;

  /// Frame duration in milliseconds (typically 50ms – 100ms).
  final int durationMs;

  /// Ratio of peak amplitude to RMS energy (Crest Factor).
  /// High values (>= 3.0) indicate sharp transient clicks/impulses.
  final double crestFactor;

  /// Spectral flatness (0.0 = pure single-frequency tone, 1.0 = white noise).
  final double spectralFlatness;

  const AcousticFrame({
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

  /// Whistle-to-total energy ratio.
  double get whistleEnergyRatio =>
      totalRmsEnergy > 0.001 ? whistleBandEnergy / totalRmsEnergy : 0.0;

  /// High-hiss to total energy ratio.
  double get hissEnergyRatio =>
      totalRmsEnergy > 0.001 ? highHissBandEnergy / totalRmsEnergy : 0.0;

  /// Beep pure tone energy ratio.
  double get beepEnergyRatio =>
      totalRmsEnergy > 0.001 ? beepBandEnergy / totalRmsEnergy : 0.0;

  /// True if dominant frequency falls within steam whistle resonant range.
  bool get isWhistleFrequency =>
      dominantFrequencyHz >= 2400.0 && dominantFrequencyHz <= 4500.0;

  /// True if dominant frequency falls within high-frequency steam hiss range.
  bool get isHissFrequency =>
      dominantFrequencyHz >= 3800.0 && dominantFrequencyHz <= 9000.0;

  /// True if dominant frequency falls within electronic buzzer/beeper range.
  bool get isBeepFrequency =>
      dominantFrequencyHz >= 2000.0 && dominantFrequencyHz <= 3500.0;

  /// True if frame represents a sharp impulsive transient sound.
  bool get isTransientImpulse => crestFactor >= 3.0 && totalRmsEnergy >= 0.12;

  /// True if frame represents a resonant kettle whistle (1,800 Hz – 3,800 Hz).
  bool get isKettleFrequency =>
      dominantFrequencyHz >= 1800.0 && dominantFrequencyHz <= 3800.0;
}

/// An event emitted by the signal engine when an acoustic pattern changes or completes.
class SignalEngineEvent {
  /// Signal type detected or being tracked.
  final CookingSignalType signalType;

  /// Machine-readable status code.
  final String status;

  /// Friendly descriptive message.
  final String message;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// True if the cooking target (whistles, simmer duration, beeps, warm switch) has been reached.
  final bool isTargetReached;

  /// Current count (for whistles or beeps).
  final int? currentCount;

  /// Target count (for whistles or beeps).
  final int? targetCount;

  /// Elapsed duration in seconds (for simmer timers or kettle boiling).
  final int? elapsedSeconds;

  /// Timestamp of event generation.
  final DateTime timestamp;

  SignalEngineEvent({
    required this.signalType,
    required this.status,
    required this.message,
    required this.confidence,
    this.isTargetReached = false,
    this.currentCount,
    this.targetCount,
    this.elapsedSeconds,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'SignalEngineEvent($signalType: $status, "$message", targetReached: $isTargetReached)';
}

/// Classifier for traditional South Asian weighted-valve pressure cookers.
class WeightedWhistleClassifier {
  static const double minWhistleRms = 0.05;
  static const double minEnergyRatio = 0.45;
  static const int minVentingDurationMs = 1000;
  static const int maxVentingDurationMs = 6000;
  static const int refractoryPeriodMs = 8000;

  int _whistleCount = 0;
  final int targetWhistles;
  String _state = 'idle'; // 'idle', 'venting', 'refractory'
  int _sustainedVentingMs = 0;
  int _refractoryRemainingMs = 0;
  int _consecutiveNoiseFrames = 0;

  final void Function(SignalEngineEvent event)? onEvent;

  WeightedWhistleClassifier({
    this.targetWhistles = 3,
    this.onEvent,
  });

  int get whistleCount => _whistleCount;
  String get state => _state;
  bool get isTargetReached => _whistleCount >= targetWhistles;

  void processFrame(AcousticFrame frame) {
    if (_state == 'refractory') {
      _refractoryRemainingMs -= frame.durationMs;
      if (_refractoryRemainingMs <= 0) {
        _refractoryRemainingMs = 0;
        _state = 'idle';
      }
      return;
    }

    final isWhistle = frame.totalRmsEnergy >= minWhistleRms &&
        frame.whistleEnergyRatio >= minEnergyRatio &&
        frame.isWhistleFrequency;

    if (isWhistle) {
      _consecutiveNoiseFrames = 0;
      _sustainedVentingMs += frame.durationMs;
      if (_sustainedVentingMs >= minVentingDurationMs && _state != 'venting') {
        _state = 'venting';
        onEvent?.call(SignalEngineEvent(
          signalType: CookingSignalType.weightedWhistle,
          status: 'venting_start',
          message: 'Pressure cooker whistle venting...',
          confidence: 0.85,
          currentCount: _whistleCount,
          targetCount: targetWhistles,
        ));
      }
    } else {
      _consecutiveNoiseFrames++;
      if (_consecutiveNoiseFrames * frame.durationMs >= 250) {
        if (_state == 'venting' &&
            _sustainedVentingMs >= minVentingDurationMs &&
            _sustainedVentingMs <= maxVentingDurationMs) {
          _registerWhistle();
        } else {
          _resetDetection();
        }
      }
    }
  }

  void _registerWhistle() {
    _whistleCount++;
    _state = 'refractory';
    _refractoryRemainingMs = refractoryPeriodMs;
    _sustainedVentingMs = 0;
    _consecutiveNoiseFrames = 0;

    final targetReached = _whistleCount >= targetWhistles;
    onEvent?.call(SignalEngineEvent(
      signalType: CookingSignalType.weightedWhistle,
      status: targetReached ? 'target_reached' : 'whistle_detected',
      message: targetReached
          ? 'Target whistles reached! Turn off heat.'
          : 'Whistle $_whistleCount of $targetWhistles detected.',
      confidence: 0.98,
      isTargetReached: targetReached,
      currentCount: _whistleCount,
      targetCount: targetWhistles,
    ));
  }

  void _resetDetection() {
    _state = 'idle';
    _sustainedVentingMs = 0;
    _consecutiveNoiseFrames = 0;
  }

  void manualIncrement() {
    _whistleCount++;
    final targetReached = _whistleCount >= targetWhistles;
    onEvent?.call(SignalEngineEvent(
      signalType: CookingSignalType.weightedWhistle,
      status: targetReached ? 'target_reached' : 'whistle_detected',
      message: 'Whistle manually marked. Current count: $_whistleCount',
      confidence: 1.0,
      isTargetReached: targetReached,
      currentCount: _whistleCount,
      targetCount: targetWhistles,
    ));
  }

  void manualDecrement() {
    if (_whistleCount > 0) {
      _whistleCount--;
      onEvent?.call(SignalEngineEvent(
        signalType: CookingSignalType.weightedWhistle,
        status: 'whistle_adjusted',
        message: 'Whistle manually adjusted. Current count: $_whistleCount',
        confidence: 1.0,
        isTargetReached: _whistleCount >= targetWhistles,
        currentCount: _whistleCount,
        targetCount: targetWhistles,
      ));
    }
  }

  void reset() {
    _whistleCount = 0;
    _state = 'idle';
    _sustainedVentingMs = 0;
    _refractoryRemainingMs = 0;
    _consecutiveNoiseFrames = 0;
  }
}

/// Classifier for European spring-valve pressure cookers (Kuhn Rikon, WMF, Fagor).
/// Spring valves do not release rhythmic burst whistles. Instead, they emit a steady,
/// continuous hiss in the 3.8 kHz – 9.0 kHz band once operating pressure is achieved.
class SpringValveHissClassifier {
  static const double minHissRms = 0.08;
  static const double minHissRatio = 0.40;
  static const int minHissOnsetMs = 2000; // Continuous hiss for 2s indicates at pressure
  static const double overpressureRmsThreshold = 0.60;

  final int targetSimmerSeconds;
  final void Function(SignalEngineEvent event)? onEvent;

  String _state = 'idle'; // 'idle', 'pressure_rising', 'at_pressure', 'simmering'
  int _sustainedHissMs = 0;
  int _simmerElapsedMs = 0;
  int _dropoutMs = 0;
  bool _targetFired = false;

  SpringValveHissClassifier({
    this.targetSimmerSeconds = 300, // 5 minutes default simmer
    this.onEvent,
  });

  String get state => _state;
  bool get isAtPressure => _state == 'at_pressure' || _state == 'simmering';
  int get elapsedSimmerSeconds => _simmerElapsedMs ~/ 1000;
  bool get isTargetReached => _targetFired;

  void processFrame(AcousticFrame frame) {
    final isHissing = frame.totalRmsEnergy >= minHissRms &&
        frame.hissEnergyRatio >= minHissRatio &&
        frame.isHissFrequency;

    // Check for excessive violent overpressure venting
    if (isHissing && frame.totalRmsEnergy >= overpressureRmsThreshold) {
      onEvent?.call(SignalEngineEvent(
        signalType: CookingSignalType.springValveHiss,
        status: 'overpressure_alert',
        message: 'High steam venting detected! Reduce heat to low simmer.',
        confidence: 0.95,
        elapsedSeconds: elapsedSimmerSeconds,
      ));
    }

    if (isHissing) {
      _dropoutMs = 0;
      _sustainedHissMs += frame.durationMs;

      if (_state == 'idle' || _state == 'pressure_rising') {
        if (_sustainedHissMs < minHissOnsetMs) {
          _state = 'pressure_rising';
        } else {
          // Reached full operating pressure!
          _state = 'at_pressure';
          onEvent?.call(SignalEngineEvent(
            signalType: CookingSignalType.springValveHiss,
            status: 'pressure_reached',
            message: 'Operating pressure reached! Reduce heat to simmer.',
            confidence: 0.92,
            elapsedSeconds: 0,
          ));
        }
      } else if (isAtPressure) {
        _state = 'simmering';
        _simmerElapsedMs += frame.durationMs;

        if (!_targetFired && elapsedSimmerSeconds >= targetSimmerSeconds) {
          _targetFired = true;
          onEvent?.call(SignalEngineEvent(
            signalType: CookingSignalType.springValveHiss,
            status: 'target_reached',
            message: 'Simmer timer complete! Turn off heat.',
            confidence: 0.98,
            isTargetReached: true,
            elapsedSeconds: elapsedSimmerSeconds,
          ));
        }
      }
    } else {
      // Hiss dropped out
      if (isAtPressure) {
        _dropoutMs += frame.durationMs;
        // If hiss ceases for > 4.0 seconds, pressure has been lost (heat too low)
        if (_dropoutMs >= 4000) {
          _state = 'idle';
          _sustainedHissMs = 0;
          onEvent?.call(SignalEngineEvent(
            signalType: CookingSignalType.springValveHiss,
            status: 'pressure_lost',
            message: 'Hiss stopped - pressure lost! Slightly raise heat.',
            confidence: 0.88,
            elapsedSeconds: elapsedSimmerSeconds,
          ));
        }
      } else {
        _sustainedHissMs = 0;
        _state = 'idle';
      }
    }
  }

  void reset() {
    _state = 'idle';
    _sustainedHissMs = 0;
    _simmerElapsedMs = 0;
    _dropoutMs = 0;
    _targetFired = false;
  }
}

/// Classifier for Electric Pressure Cooker completion beeps (Instant Pot, Ninja Foodi).
/// Recognizes high-purity tone beeps (2.0 kHz – 3.5 kHz) in a rhythmic train.
class ElectricBeepClassifier {
  static const double minBeepRms = 0.08;
  static const double minBeepPurityRatio = 0.65; // Highly concentrated tone
  static const int minBeepDurationMs = 80;
  static const int maxBeepDurationMs = 500;
  static const int maxInterBeepSilenceMs = 600;

  final int targetBeepCount;
  final void Function(SignalEngineEvent event)? onEvent;

  String _state = 'idle'; // 'idle', 'in_beep', 'inter_beep', 'completed'
  int _currentBeepDurationMs = 0;
  int _silenceDurationMs = 0;
  int _detectedBeeps = 0;
  bool _targetFired = false;

  ElectricBeepClassifier({
    this.targetBeepCount = 3, // Instant Pot emits 3 or 10 beeps
    this.onEvent,
  });

  String get state => _state;
  int get detectedBeeps => _detectedBeeps;
  bool get isTargetReached => _targetFired;

  void processFrame(AcousticFrame frame) {
    if (_targetFired) return;

    final isBeepTone = frame.totalRmsEnergy >= minBeepRms &&
        frame.beepEnergyRatio >= minBeepPurityRatio &&
        frame.isBeepFrequency;

    if (isBeepTone) {
      _currentBeepDurationMs += frame.durationMs;
      _silenceDurationMs = 0;

      if (_state == 'idle' || _state == 'inter_beep') {
        _state = 'in_beep';
      }
    } else {
      if (_state == 'in_beep') {
        // Just exited a candidate beep tone
        if (_currentBeepDurationMs >= minBeepDurationMs &&
            _currentBeepDurationMs <= maxBeepDurationMs) {
          _detectedBeeps++;
          onEvent?.call(SignalEngineEvent(
            signalType: CookingSignalType.electricBeep,
            status: 'beep_detected',
            message: 'Electric cooker beep $_detectedBeeps detected.',
            confidence: 0.90,
            currentCount: _detectedBeeps,
            targetCount: targetBeepCount,
          ));

          if (_detectedBeeps >= targetBeepCount) {
            _targetFired = true;
            _state = 'completed';
            onEvent?.call(SignalEngineEvent(
              signalType: CookingSignalType.electricBeep,
              status: 'target_reached',
              message: 'Electric cooker completion chimes finished! Food is ready.',
              confidence: 0.99,
              isTargetReached: true,
              currentCount: _detectedBeeps,
              targetCount: targetBeepCount,
            ));
            return;
          }
          _state = 'inter_beep';
        } else {
          // Tone was too short or too long to be an electric beep
          if (_detectedBeeps == 0) {
            _state = 'idle';
          }
        }
        _currentBeepDurationMs = 0;
      } else if (_state == 'inter_beep') {
        _silenceDurationMs += frame.durationMs;
        // If silence exceeds timeout, beep train has ended or broken
        if (_silenceDurationMs > maxInterBeepSilenceMs) {
          _state = 'idle';
          _detectedBeeps = 0;
          _silenceDurationMs = 0;
        }
      }
    }
  }

  void reset() {
    _state = 'idle';
    _currentBeepDurationMs = 0;
    _silenceDurationMs = 0;
    _detectedBeeps = 0;
    _targetFired = false;
  }
}

/// Classifier for Rice Cooker mechanical switch clicks (Panasonic, National, Zojirushi).
/// Detects the sharp mechanical thermostat snap when tripping from Cook to Warm,
/// and validates the subsequent post-click thermal drop in bubbling/steaming acoustic energy.
class MechanicalClickClassifier {
  static const double minTransientCrest = 3.0;
  static const int maxClickDurationMs = 150;
  static const int validationWindowMs = 2000;

  final void Function(SignalEngineEvent event)? onEvent;

  String _state = 'cooking'; // 'cooking', 'candidate_click', 'validating_drop', 'warm_confirmed'
  int _transientDurationMs = 0;
  int _postClickTimeMs = 0;
  double _baselineBoilingEnergy = 0.25;
  bool _targetFired = false;

  MechanicalClickClassifier({this.onEvent});

  String get state => _state;
  bool get isTargetReached => _targetFired;

  void processFrame(AcousticFrame frame) {
    if (_targetFired) return;

    if (_state == 'cooking') {
      // Track ambient baseline boiling noise when not in transient
      if (!frame.isTransientImpulse && frame.totalRmsEnergy > 0.05) {
        _baselineBoilingEnergy = (_baselineBoilingEnergy * 0.9) + (frame.totalRmsEnergy * 0.1);
      }

      // Check for sharp mechanical switch transient
      if (frame.isTransientImpulse) {
        _transientDurationMs += frame.durationMs;
        if (_transientDurationMs <= maxClickDurationMs) {
          _state = 'validating_drop';
          _postClickTimeMs = 0;
          onEvent?.call(SignalEngineEvent(
            signalType: CookingSignalType.mechanicalClick,
            status: 'click_detected',
            message: 'Switch click detected! Confirming warm transition...',
            confidence: 0.75,
          ));
        }
      }
    } else if (_state == 'validating_drop') {
      _postClickTimeMs += frame.durationMs;

      // In validation window: check if acoustic energy drops significantly below baseline boiling
      // If loud boiling continues, it was likely cutlery or lid noise, not the magnetic switch trip
      if (_postClickTimeMs >= validationWindowMs) {
        // Average energy in quiet post-click phase should be lower than active boiling
        final hasAcousticDrop = frame.totalRmsEnergy < (_baselineBoilingEnergy * 0.65);

        if (hasAcousticDrop) {
          _targetFired = true;
          _state = 'warm_confirmed';
          onEvent?.call(SignalEngineEvent(
            signalType: CookingSignalType.mechanicalClick,
            status: 'target_reached',
            message: 'Rice cooker switched to Keep Warm! Rice is ready.',
            confidence: 0.96,
            isTargetReached: true,
          ));
        } else {
          // False alarm (e.g. dropped spoon while water keeps bubbling)
          _state = 'cooking';
          _transientDurationMs = 0;
          _postClickTimeMs = 0;
        }
      }
    }
  }

  void reset() {
    _state = 'cooking';
    _transientDurationMs = 0;
    _postClickTimeMs = 0;
    _targetFired = false;
  }
}

/// Classifier for stovetop boiling kettle whistles.
/// Detects continuous, resonant pipe tone (1.8 kHz – 3.8 kHz) sustained without cutoff.
class KettleWhistleClassifier {
  static const double minKettleRms = 0.08;
  static const double minKettleRatio = 0.50;
  static const int minBoilSustainedMs = 3000; // Sustained whistle for 3 seconds = rolling boil

  final void Function(SignalEngineEvent event)? onEvent;

  String _state = 'idle'; // 'idle', 'whistling', 'boil_alert'
  int _sustainedWhistleMs = 0;
  bool _targetFired = false;

  KettleWhistleClassifier({this.onEvent});

  String get state => _state;
  bool get isTargetReached => _targetFired;

  void processFrame(AcousticFrame frame) {
    if (_targetFired) return;

    final isKettleWhistling = frame.totalRmsEnergy >= minKettleRms &&
        frame.whistleEnergyRatio >= minKettleRatio &&
        frame.isKettleFrequency;

    if (isKettleWhistling) {
      _sustainedWhistleMs += frame.durationMs;

      if (_state == 'idle' && _sustainedWhistleMs >= 1000) {
        _state = 'whistling';
        onEvent?.call(SignalEngineEvent(
          signalType: CookingSignalType.kettleWhistle,
          status: 'whistle_start',
          message: 'Kettle whistle starting...',
          confidence: 0.85,
        ));
      }

      if (_sustainedWhistleMs >= minBoilSustainedMs) {
        _targetFired = true;
        _state = 'boil_alert';
        onEvent?.call(SignalEngineEvent(
          signalType: CookingSignalType.kettleWhistle,
          status: 'target_reached',
          message: 'Water has reached full rolling boil! Remove kettle from heat.',
          confidence: 0.98,
          isTargetReached: true,
          elapsedSeconds: _sustainedWhistleMs ~/ 1000,
        ));
      }
    } else {
      if (_sustainedWhistleMs < minBoilSustainedMs) {
        _sustainedWhistleMs = 0;
        _state = 'idle';
      }
    }
  }

  void reset() {
    _state = 'idle';
    _sustainedWhistleMs = 0;
    _targetFired = false;
  }
}

/// Unified cooking signal engine capable of operating in a specific appliance mode
/// or automatically classifying multi-appliance acoustic signatures in modern kitchens.
class CookingSignalEngine {
  final CookingSignalType activeType;
  final void Function(SignalEngineEvent event)? onEvent;

  late final WeightedWhistleClassifier _weightedClassifier;
  late final SpringValveHissClassifier _springClassifier;
  late final ElectricBeepClassifier _electricClassifier;
  late final MechanicalClickClassifier _clickClassifier;
  late final KettleWhistleClassifier _kettleClassifier;

  CookingSignalEngine({
    this.activeType = CookingSignalType.weightedWhistle,
    int targetWhistles = 3,
    int targetSimmerSeconds = 300,
    int targetBeeps = 3,
    this.onEvent,
  }) {
    _weightedClassifier = WeightedWhistleClassifier(
      targetWhistles: targetWhistles,
      onEvent: _relayEvent,
    );
    _springClassifier = SpringValveHissClassifier(
      targetSimmerSeconds: targetSimmerSeconds,
      onEvent: _relayEvent,
    );
    _electricClassifier = ElectricBeepClassifier(
      targetBeepCount: targetBeeps,
      onEvent: _relayEvent,
    );
    _clickClassifier = MechanicalClickClassifier(
      onEvent: _relayEvent,
    );
    _kettleClassifier = KettleWhistleClassifier(
      onEvent: _relayEvent,
    );
  }

  void _relayEvent(SignalEngineEvent event) {
    onEvent?.call(event);
  }

  /// Processes an audio frame according to the currently active cooker signal type.
  void processFrame(AcousticFrame frame) {
    switch (activeType) {
      case CookingSignalType.weightedWhistle:
        _weightedClassifier.processFrame(frame);
        break;
      case CookingSignalType.springValveHiss:
        _springClassifier.processFrame(frame);
        break;
      case CookingSignalType.electricBeep:
        _electricClassifier.processFrame(frame);
        break;
      case CookingSignalType.mechanicalClick:
        _clickClassifier.processFrame(frame);
        break;
      case CookingSignalType.kettleWhistle:
        _kettleClassifier.processFrame(frame);
        break;
    }
  }

  /// True if the target cooking milestone for the active mode has been reached.
  bool get isTargetReached {
    switch (activeType) {
      case CookingSignalType.weightedWhistle:
        return _weightedClassifier.isTargetReached;
      case CookingSignalType.springValveHiss:
        return _springClassifier.isTargetReached;
      case CookingSignalType.electricBeep:
        return _electricClassifier.isTargetReached;
      case CookingSignalType.mechanicalClick:
        return _clickClassifier.isTargetReached;
      case CookingSignalType.kettleWhistle:
        return _kettleClassifier.isTargetReached;
    }
  }

  /// Current whistle count (for weighted cookers).
  int get whistleCount => _weightedClassifier.whistleCount;

  /// Current elapsed simmer seconds (for spring-valve cookers).
  int get elapsedSimmerSeconds => _springClassifier.elapsedSimmerSeconds;

  /// Current detected beep count (for electric cookers).
  int get detectedBeeps => _electricClassifier.detectedBeeps;

  /// Manually increment whistle count (for weighted cookers).
  void manualIncrementWhistle() => _weightedClassifier.manualIncrement();

  /// Manually decrement whistle count (for weighted cookers).
  void manualDecrementWhistle() => _weightedClassifier.manualDecrement();

  /// Reset all detectors to clean state.
  void reset() {
    _weightedClassifier.reset();
    _springClassifier.reset();
    _electricClassifier.reset();
    _clickClassifier.reset();
    _kettleClassifier.reset();
  }
}
