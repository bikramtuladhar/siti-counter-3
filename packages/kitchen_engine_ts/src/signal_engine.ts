/**
 * Cooking Signal Engine for multi-appliance acoustic classification.
 * Supports traditional pressure cooker whistles, European spring-valve hissing,
 * electric cooker beeps, rice cooker mechanical switch clicks, and boiling kettle whistles.
 */

export type CookingSignalType =
  | 'weightedWhistle'
  | 'springValveHiss'
  | 'electricBeep'
  | 'mechanicalClick'
  | 'kettleWhistle'

export interface AcousticFrame {
  totalRmsEnergy: number
  whistleBandEnergy: number
  highHissBandEnergy?: number
  beepBandEnergy?: number
  dominantFrequencyHz: number
  durationMs: number
  crestFactor?: number
  spectralFlatness?: number
}

export interface SignalEngineEvent {
  signalType: CookingSignalType
  status: string
  message: string
  confidence: number
  isTargetReached: boolean
  currentCount?: number
  targetCount?: number
  elapsedSeconds?: number
  timestamp: string
}

export class WeightedWhistleClassifier {
  private static readonly minWhistleRms = 0.05
  private static readonly minEnergyRatio = 0.45
  private static readonly minVentingDurationMs = 1000
  private static readonly maxVentingDurationMs = 6000
  private static readonly refractoryPeriodMs = 8000

  private _whistleCount = 0
  private _state: 'idle' | 'venting' | 'refractory' = 'idle'
  private _sustainedVentingMs = 0
  private _refractoryRemainingMs = 0
  private _consecutiveNoiseFrames = 0

  readonly targetWhistles: number
  readonly onEvent?: (event: SignalEngineEvent) => void

  constructor(options: {
    targetWhistles?: number
    onEvent?: (event: SignalEngineEvent) => void
  } = {}) {
    this.targetWhistles = options.targetWhistles ?? 3
    this.onEvent = options.onEvent
  }

  get whistleCount(): number {
    return this._whistleCount
  }

  get state(): string {
    return this._state
  }

  get isTargetReached(): boolean {
    return this._whistleCount >= this.targetWhistles
  }

  processFrame(frame: AcousticFrame): void {
    if (this._state === 'refractory') {
      this._refractoryRemainingMs -= frame.durationMs
      if (this._refractoryRemainingMs <= 0) {
        this._refractoryRemainingMs = 0
        this._state = 'idle'
      }
      return
    }

    const whistleRatio = frame.totalRmsEnergy > 0.001
      ? frame.whistleBandEnergy / frame.totalRmsEnergy
      : 0.0
    const isWhistleFreq = frame.dominantFrequencyHz >= 2400.0 && frame.dominantFrequencyHz <= 4500.0

    const isWhistle = frame.totalRmsEnergy >= WeightedWhistleClassifier.minWhistleRms &&
      whistleRatio >= WeightedWhistleClassifier.minEnergyRatio &&
      isWhistleFreq

    if (isWhistle) {
      this._consecutiveNoiseFrames = 0
      this._sustainedVentingMs += frame.durationMs
      if (this._sustainedVentingMs >= WeightedWhistleClassifier.minVentingDurationMs && this._state !== 'venting') {
        this._state = 'venting'
        this.onEvent?.({
          signalType: 'weightedWhistle',
          status: 'venting_start',
          message: 'Pressure cooker whistle venting...',
          confidence: 0.85,
          isTargetReached: false,
          currentCount: this._whistleCount,
          targetCount: this.targetWhistles,
          timestamp: new Date().toISOString()
        })
      }
    } else {
      this._consecutiveNoiseFrames++
      if (this._consecutiveNoiseFrames * frame.durationMs >= 250) {
        if (
          this._state === 'venting' &&
          this._sustainedVentingMs >= WeightedWhistleClassifier.minVentingDurationMs &&
          this._sustainedVentingMs <= WeightedWhistleClassifier.maxVentingDurationMs
        ) {
          this._registerWhistle()
        } else {
          this._resetDetection()
        }
      }
    }
  }

  private _registerWhistle(): void {
    this._whistleCount++
    this._state = 'refractory'
    this._refractoryRemainingMs = WeightedWhistleClassifier.refractoryPeriodMs
    this._sustainedVentingMs = 0
    this._consecutiveNoiseFrames = 0

    const targetReached = this._whistleCount >= this.targetWhistles
    this.onEvent?.({
      signalType: 'weightedWhistle',
      status: targetReached ? 'target_reached' : 'whistle_detected',
      message: targetReached
        ? 'Target whistles reached! Turn off heat.'
        : `Whistle ${this._whistleCount} of ${this.targetWhistles} detected.`,
      confidence: 0.98,
      isTargetReached: targetReached,
      currentCount: this._whistleCount,
      targetCount: this.targetWhistles,
      timestamp: new Date().toISOString()
    })
  }

  private _resetDetection(): void {
    this._state = 'idle'
    this._sustainedVentingMs = 0
    this._consecutiveNoiseFrames = 0
  }

  manualIncrement(): void {
    this._whistleCount++
    const targetReached = this._whistleCount >= this.targetWhistles
    this.onEvent?.({
      signalType: 'weightedWhistle',
      status: targetReached ? 'target_reached' : 'whistle_detected',
      message: `Whistle manually marked. Current count: ${this._whistleCount}`,
      confidence: 1.0,
      isTargetReached: targetReached,
      currentCount: this._whistleCount,
      targetCount: this.targetWhistles,
      timestamp: new Date().toISOString()
    })
  }

  manualDecrement(): void {
    if (this._whistleCount > 0) {
      this._whistleCount--
      this.onEvent?.({
        signalType: 'weightedWhistle',
        status: 'whistle_adjusted',
        message: `Whistle manually adjusted. Current count: ${this._whistleCount}`,
        confidence: 1.0,
        isTargetReached: this._whistleCount >= this.targetWhistles,
        currentCount: this._whistleCount,
        targetCount: this.targetWhistles,
        timestamp: new Date().toISOString()
      })
    }
  }

  reset(): void {
    this._whistleCount = 0
    this._state = 'idle'
    this._sustainedVentingMs = 0
    this._refractoryRemainingMs = 0
    this._consecutiveNoiseFrames = 0
  }
}

export class SpringValveHissClassifier {
  private static readonly minHissRms = 0.08
  private static readonly minHissRatio = 0.40
  private static readonly minHissOnsetMs = 2000
  private static readonly overpressureRmsThreshold = 0.60

  readonly targetSimmerSeconds: number
  readonly onEvent?: (event: SignalEngineEvent) => void

  private _state: 'idle' | 'pressure_rising' | 'at_pressure' | 'simmering' = 'idle'
  private _sustainedHissMs = 0
  private _simmerElapsedMs = 0
  private _dropoutMs = 0
  private _targetFired = false

  constructor(options: {
    targetSimmerSeconds?: number
    onEvent?: (event: SignalEngineEvent) => void
  } = {}) {
    this.targetSimmerSeconds = options.targetSimmerSeconds ?? 300
    this.onEvent = options.onEvent
  }

  get state(): string {
    return this._state
  }

  get isAtPressure(): boolean {
    return this._state === 'at_pressure' || this._state === 'simmering'
  }

  get elapsedSimmerSeconds(): number {
    return Math.floor(this._simmerElapsedMs / 1000)
  }

  get isTargetReached(): boolean {
    return this._targetFired
  }

  processFrame(frame: AcousticFrame): void {
    const hissEnergy = frame.highHissBandEnergy ?? frame.whistleBandEnergy
    const hissRatio = frame.totalRmsEnergy > 0.001
      ? hissEnergy / frame.totalRmsEnergy
      : 0.0
    const isHissFreq = frame.dominantFrequencyHz >= 3800.0 && frame.dominantFrequencyHz <= 9000.0

    const isHissing = frame.totalRmsEnergy >= SpringValveHissClassifier.minHissRms &&
      hissRatio >= SpringValveHissClassifier.minHissRatio &&
      isHissFreq

    if (isHissing && frame.totalRmsEnergy >= SpringValveHissClassifier.overpressureRmsThreshold) {
      this.onEvent?.({
        signalType: 'springValveHiss',
        status: 'overpressure_alert',
        message: 'High steam venting detected! Reduce heat to low simmer.',
        confidence: 0.95,
        isTargetReached: false,
        elapsedSeconds: this.elapsedSimmerSeconds,
        timestamp: new Date().toISOString()
      })
    }

    if (isHissing) {
      this._dropoutMs = 0
      this._sustainedHissMs += frame.durationMs

      if (this._state === 'idle' || this._state === 'pressure_rising') {
        if (this._sustainedHissMs < SpringValveHissClassifier.minHissOnsetMs) {
          this._state = 'pressure_rising'
        } else {
          this._state = 'at_pressure'
          this.onEvent?.({
            signalType: 'springValveHiss',
            status: 'pressure_reached',
            message: 'Operating pressure reached! Reduce heat to simmer.',
            confidence: 0.92,
            isTargetReached: false,
            elapsedSeconds: 0,
            timestamp: new Date().toISOString()
          })
        }
      } else if (this.isAtPressure) {
        this._state = 'simmering'
        this._simmerElapsedMs += frame.durationMs

        if (!this._targetFired && this.elapsedSimmerSeconds >= this.targetSimmerSeconds) {
          this._targetFired = true
          this.onEvent?.({
            signalType: 'springValveHiss',
            status: 'target_reached',
            message: 'Simmer timer complete! Turn off heat.',
            confidence: 0.98,
            isTargetReached: true,
            elapsedSeconds: this.elapsedSimmerSeconds,
            timestamp: new Date().toISOString()
          })
        }
      }
    } else {
      if (this.isAtPressure) {
        this._dropoutMs += frame.durationMs
        if (this._dropoutMs >= 4000) {
          this._state = 'idle'
          this._sustainedHissMs = 0
          this.onEvent?.({
            signalType: 'springValveHiss',
            status: 'pressure_lost',
            message: 'Hiss stopped - pressure lost! Slightly raise heat.',
            confidence: 0.88,
            isTargetReached: false,
            elapsedSeconds: this.elapsedSimmerSeconds,
            timestamp: new Date().toISOString()
          })
        }
      } else {
        this._sustainedHissMs = 0
        this._state = 'idle'
      }
    }
  }

  reset(): void {
    this._state = 'idle'
    this._sustainedHissMs = 0
    this._simmerElapsedMs = 0
    this._dropoutMs = 0
    this._targetFired = false
  }
}

export class ElectricBeepClassifier {
  private static readonly minBeepRms = 0.08
  private static readonly minBeepPurityRatio = 0.65
  private static readonly minBeepDurationMs = 80
  private static readonly maxBeepDurationMs = 500
  private static readonly maxInterBeepSilenceMs = 600

  readonly targetBeepCount: number
  readonly onEvent?: (event: SignalEngineEvent) => void

  private _state: 'idle' | 'in_beep' | 'inter_beep' | 'completed' = 'idle'
  private _currentBeepDurationMs = 0
  private _silenceDurationMs = 0
  private _detectedBeeps = 0
  private _targetFired = false

  constructor(options: {
    targetBeepCount?: number
    onEvent?: (event: SignalEngineEvent) => void
  } = {}) {
    this.targetBeepCount = options.targetBeepCount ?? 3
    this.onEvent = options.onEvent
  }

  get state(): string {
    return this._state
  }

  get detectedBeeps(): number {
    return this._detectedBeeps
  }

  get isTargetReached(): boolean {
    return this._targetFired
  }

  processFrame(frame: AcousticFrame): void {
    if (this._targetFired) return

    const beepEnergy = frame.beepBandEnergy ?? frame.whistleBandEnergy
    const beepRatio = frame.totalRmsEnergy > 0.001
      ? beepEnergy / frame.totalRmsEnergy
      : 0.0
    const isBeepFreq = frame.dominantFrequencyHz >= 2000.0 && frame.dominantFrequencyHz <= 3500.0

    const isBeepTone = frame.totalRmsEnergy >= ElectricBeepClassifier.minBeepRms &&
      beepRatio >= ElectricBeepClassifier.minBeepPurityRatio &&
      isBeepFreq

    if (isBeepTone) {
      this._currentBeepDurationMs += frame.durationMs
      this._silenceDurationMs = 0

      if (this._state === 'idle' || this._state === 'inter_beep') {
        this._state = 'in_beep'
      }
    } else {
      if (this._state === 'in_beep') {
        if (
          this._currentBeepDurationMs >= ElectricBeepClassifier.minBeepDurationMs &&
          this._currentBeepDurationMs <= ElectricBeepClassifier.maxBeepDurationMs
        ) {
          this._detectedBeeps++
          this.onEvent?.({
            signalType: 'electricBeep',
            status: 'beep_detected',
            message: `Electric cooker beep ${this._detectedBeeps} detected.`,
            confidence: 0.90,
            isTargetReached: false,
            currentCount: this._detectedBeeps,
            targetCount: this.targetBeepCount,
            timestamp: new Date().toISOString()
          })

          if (this._detectedBeeps >= this.targetBeepCount) {
            this._targetFired = true
            this._state = 'completed'
            this.onEvent?.({
              signalType: 'electricBeep',
              status: 'target_reached',
              message: 'Electric cooker completion chimes finished! Food is ready.',
              confidence: 0.99,
              isTargetReached: true,
              currentCount: this._detectedBeeps,
              targetCount: this.targetBeepCount,
              timestamp: new Date().toISOString()
            })
            return
          }
          this._state = 'inter_beep'
        } else {
          if (this._detectedBeeps === 0) {
            this._state = 'idle'
          }
        }
        this._currentBeepDurationMs = 0
      } else if (this._state === 'inter_beep') {
        this._silenceDurationMs += frame.durationMs
        if (this._silenceDurationMs > ElectricBeepClassifier.maxInterBeepSilenceMs) {
          this._state = 'idle'
          this._detectedBeeps = 0
          this._silenceDurationMs = 0
        }
      }
    }
  }

  reset(): void {
    this._state = 'idle'
    this._currentBeepDurationMs = 0
    this._silenceDurationMs = 0
    this._detectedBeeps = 0
    this._targetFired = false
  }
}

export class MechanicalClickClassifier {
  private static readonly minTransientCrest = 3.0
  private static readonly maxClickDurationMs = 150
  private static readonly validationWindowMs = 2000

  readonly onEvent?: (event: SignalEngineEvent) => void

  private _state: 'cooking' | 'validating_drop' | 'warm_confirmed' = 'cooking'
  private _transientDurationMs = 0
  private _postClickTimeMs = 0
  private _baselineBoilingEnergy = 0.25
  private _targetFired = false

  constructor(options: { onEvent?: (event: SignalEngineEvent) => void } = {}) {
    this.onEvent = options.onEvent
  }

  get state(): string {
    return this._state
  }

  get isTargetReached(): boolean {
    return this._targetFired
  }

  processFrame(frame: AcousticFrame): void {
    if (this._targetFired) return

    const crest = frame.crestFactor ?? 1.5
    const isTransient = crest >= MechanicalClickClassifier.minTransientCrest && frame.totalRmsEnergy >= 0.12

    if (this._state === 'cooking') {
      if (!isTransient && frame.totalRmsEnergy > 0.05) {
        this._baselineBoilingEnergy = (this._baselineBoilingEnergy * 0.9) + (frame.totalRmsEnergy * 0.1)
      }

      if (isTransient) {
        this._transientDurationMs += frame.durationMs
        if (this._transientDurationMs <= MechanicalClickClassifier.maxClickDurationMs) {
          this._state = 'validating_drop'
          this._postClickTimeMs = 0
          this.onEvent?.({
            signalType: 'mechanicalClick',
            status: 'click_detected',
            message: 'Switch click detected! Confirming warm transition...',
            confidence: 0.75,
            isTargetReached: false,
            timestamp: new Date().toISOString()
          })
        }
      }
    } else if (this._state === 'validating_drop') {
      this._postClickTimeMs += frame.durationMs

      if (this._postClickTimeMs >= MechanicalClickClassifier.validationWindowMs) {
        const hasAcousticDrop = frame.totalRmsEnergy < (this._baselineBoilingEnergy * 0.65)

        if (hasAcousticDrop) {
          this._targetFired = true
          this._state = 'warm_confirmed'
          this.onEvent?.({
            signalType: 'mechanicalClick',
            status: 'target_reached',
            message: 'Rice cooker switched to Keep Warm! Rice is ready.',
            confidence: 0.96,
            isTargetReached: true,
            timestamp: new Date().toISOString()
          })
        } else {
          this._state = 'cooking'
          this._transientDurationMs = 0
          this._postClickTimeMs = 0
        }
      }
    }
  }

  reset(): void {
    this._state = 'cooking'
    this._transientDurationMs = 0
    this._postClickTimeMs = 0
    this._targetFired = false
  }
}

export class KettleWhistleClassifier {
  private static readonly minKettleRms = 0.08
  private static readonly minKettleRatio = 0.50
  private static readonly minBoilSustainedMs = 3000

  readonly onEvent?: (event: SignalEngineEvent) => void

  private _state: 'idle' | 'whistling' | 'boil_alert' = 'idle'
  private _sustainedWhistleMs = 0
  private _targetFired = false

  constructor(options: { onEvent?: (event: SignalEngineEvent) => void } = {}) {
    this.onEvent = options.onEvent
  }

  get state(): string {
    return this._state
  }

  get isTargetReached(): boolean {
    return this._targetFired
  }

  processFrame(frame: AcousticFrame): void {
    if (this._targetFired) return

    const whistleRatio = frame.totalRmsEnergy > 0.001
      ? frame.whistleBandEnergy / frame.totalRmsEnergy
      : 0.0
    const isKettleFreq = frame.dominantFrequencyHz >= 1800.0 && frame.dominantFrequencyHz <= 3800.0

    const isKettleWhistling = frame.totalRmsEnergy >= KettleWhistleClassifier.minKettleRms &&
      whistleRatio >= KettleWhistleClassifier.minKettleRatio &&
      isKettleFreq

    if (isKettleWhistling) {
      this._sustainedWhistleMs += frame.durationMs

      if (this._state === 'idle' && this._sustainedWhistleMs >= 1000) {
        this._state = 'whistling'
        this.onEvent?.({
          signalType: 'kettleWhistle',
          status: 'whistle_start',
          message: 'Kettle whistle starting...',
          confidence: 0.85,
          isTargetReached: false,
          timestamp: new Date().toISOString()
        })
      }

      if (this._sustainedWhistleMs >= KettleWhistleClassifier.minBoilSustainedMs) {
        this._targetFired = true
        this._state = 'boil_alert'
        this.onEvent?.({
          signalType: 'kettleWhistle',
          status: 'target_reached',
          message: 'Water has reached full rolling boil! Remove kettle from heat.',
          confidence: 0.98,
          isTargetReached: true,
          elapsedSeconds: Math.floor(this._sustainedWhistleMs / 1000),
          timestamp: new Date().toISOString()
        })
      }
    } else {
      if (this._sustainedWhistleMs < KettleWhistleClassifier.minBoilSustainedMs) {
        this._sustainedWhistleMs = 0
        this._state = 'idle'
      }
    }
  }

  reset(): void {
    this._state = 'idle'
    this._sustainedWhistleMs = 0
    this._targetFired = false
  }
}

export class CookingSignalEngine {
  readonly activeType: CookingSignalType
  readonly onEvent?: (event: SignalEngineEvent) => void

  private readonly _weightedClassifier: WeightedWhistleClassifier
  private readonly _springClassifier: SpringValveHissClassifier
  private readonly _electricClassifier: ElectricBeepClassifier
  private readonly _clickClassifier: MechanicalClickClassifier
  private readonly _kettleClassifier: KettleWhistleClassifier

  constructor(options: {
    activeType?: CookingSignalType
    targetWhistles?: number
    targetSimmerSeconds?: number
    targetBeeps?: number
    onEvent?: (event: SignalEngineEvent) => void
  } = {}) {
    this.activeType = options.activeType ?? 'weightedWhistle'
    this.onEvent = options.onEvent

    const relay = (e: SignalEngineEvent) => this.onEvent?.(e)

    this._weightedClassifier = new WeightedWhistleClassifier({
      targetWhistles: options.targetWhistles ?? 3,
      onEvent: relay
    })
    this._springClassifier = new SpringValveHissClassifier({
      targetSimmerSeconds: options.targetSimmerSeconds ?? 300,
      onEvent: relay
    })
    this._electricClassifier = new ElectricBeepClassifier({
      targetBeepCount: options.targetBeeps ?? 3,
      onEvent: relay
    })
    this._clickClassifier = new MechanicalClickClassifier({
      onEvent: relay
    })
    this._kettleClassifier = new KettleWhistleClassifier({
      onEvent: relay
    })
  }

  processFrame(frame: AcousticFrame): void {
    switch (this.activeType) {
      case 'weightedWhistle':
        this._weightedClassifier.processFrame(frame)
        break
      case 'springValveHiss':
        this._springClassifier.processFrame(frame)
        break
      case 'electricBeep':
        this._electricClassifier.processFrame(frame)
        break
      case 'mechanicalClick':
        this._clickClassifier.processFrame(frame)
        break
      case 'kettleWhistle':
        this._kettleClassifier.processFrame(frame)
        break
    }
  }

  get isTargetReached(): boolean {
    switch (this.activeType) {
      case 'weightedWhistle':
        return this._weightedClassifier.isTargetReached
      case 'springValveHiss':
        return this._springClassifier.isTargetReached
      case 'electricBeep':
        return this._electricClassifier.isTargetReached
      case 'mechanicalClick':
        return this._clickClassifier.isTargetReached
      case 'kettleWhistle':
        return this._kettleClassifier.isTargetReached
    }
  }

  get whistleCount(): number {
    return this._weightedClassifier.whistleCount
  }

  get elapsedSimmerSeconds(): number {
    return this._springClassifier.elapsedSimmerSeconds
  }

  get detectedBeeps(): number {
    return this._electricClassifier.detectedBeeps
  }

  manualIncrementWhistle(): void {
    this._weightedClassifier.manualIncrement()
  }

  manualDecrementWhistle(): void {
    this._weightedClassifier.manualDecrement()
  }

  reset(): void {
    this._weightedClassifier.reset()
    this._springClassifier.reset()
    this._electricClassifier.reset()
    this._clickClassifier.reset()
    this._kettleClassifier.reset()
  }
}
