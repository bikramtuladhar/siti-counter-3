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

  /// Peak dominant frequency detected in Hz.
  final double dominantFrequencyHz;

  /// Frame duration in milliseconds (typically 50ms - 100ms).
  final int durationMs;

  const AcousticFrameMetrics({
    required this.totalRmsEnergy,
    required this.whistleBandEnergy,
    required this.dominantFrequencyHz,
    required this.durationMs,
  });

  /// Whistle-to-total energy ratio. High ratio indicates tonal whistle over broadband noise.
  double get whistleEnergyRatio =>
      totalRmsEnergy > 0.001 ? whistleBandEnergy / totalRmsEnergy : 0.0;

  /// True if dominant frequency falls within steam whistle resonant range.
  bool get isWhistleFrequency =>
      dominantFrequencyHz >= 2400.0 && dominantFrequencyHz <= 4500.0;
}

/// Acoustic classifier and temporal integrator for pressure cooker whistle detection.
class WhistleDetector {
  // Acoustic thresholds
  static const double minWhistleRms = 0.05; // Minimum volume threshold
  static const double minEnergyRatio = 0.45; // Must have concentrated band energy
  static const int minVentingDurationMs = 1000; // Whistles last at least 1.0 second
  static const int maxVentingDurationMs = 6000; // Whistles rarely exceed 6.0 seconds
  static const int refractoryPeriodMs = 8000; // Cooker repressurizes for >= 8s

  // State
  WhistleDetectorState _state = WhistleDetectorState.idle;
  int _sustainedVentingMs = 0;
  int _refractoryRemainingMs = 0;
  int _consecutiveNoiseFrames = 0;

  // Session
  int _whistleCount = 0;
  final int targetWhistleCount;

  // Callbacks
  final void Function(int currentCount)? onWhistleDetected;
  final void Function()? onTargetReached;

  WhistleDetector({
    this.targetWhistleCount = 3,
    this.onWhistleDetected,
    this.onTargetReached,
  });

  WhistleDetectorState get state => _state;
  int get whistleCount => _whistleCount;
  bool get isTargetReached => _whistleCount >= targetWhistleCount;

  /// Processes an incoming acoustic frame from microphone analysis.
  void processFrame(AcousticFrameMetrics frame) {
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
      }
    } else {
      // Allow minor brief dropouts (up to 200ms) within continuous venting
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

    if (_whistleCount == targetWhistleCount) {
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
    _whistleCount++;
    onWhistleDetected?.call(_whistleCount);
    if (_whistleCount == targetWhistleCount) {
      onTargetReached?.call();
    }
  }

  /// Manual correction: decrement whistle count (-1)
  void manualDecrement() {
    if (_whistleCount > 0) {
      _whistleCount--;
      onWhistleDetected?.call(_whistleCount);
    }
  }

  /// Reset session
  void reset() {
    _whistleCount = 0;
    _state = WhistleDetectorState.idle;
    _sustainedVentingMs = 0;
    _refractoryRemainingMs = 0;
    _consecutiveNoiseFrames = 0;
  }
}
