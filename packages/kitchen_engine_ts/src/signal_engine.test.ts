import { describe, it } from 'node:test'
import assert from 'node:assert'
import {
  WeightedWhistleClassifier,
  SpringValveHissClassifier,
  ElectricBeepClassifier,
  MechanicalClickClassifier,
  KettleWhistleClassifier,
  CookingSignalEngine,
  SignalEngineEvent,
  AcousticFrame
} from './signal_engine.js'

describe('CookingSignalEngine TypeScript Parity Tests', () => {
  describe('WeightedWhistleClassifier', () => {
    it('accurately detects authentic pressure cooker whistle bursts', () => {
      const events: SignalEngineEvent[] = []
      const classifier = new WeightedWhistleClassifier({
        targetWhistles: 2,
        onEvent: (e) => events.push(e)
      })

      // 1. Idle background noise (1.0s, 10 frames)
      for (let i = 0; i < 10; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.whistleCount, 0)
      assert.strictEqual(classifier.state, 'idle')

      // 2. Venting whistle 1: 1.5s (15 frames) at 3,200 Hz
      for (let i = 0; i < 15; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.35,
          whistleBandEnergy: 0.28,
          dominantFrequencyHz: 3200.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.state, 'venting')

      // 3. Vent cutoff / return to quiet (4 frames)
      for (let i = 0; i < 4; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.whistleCount, 1)
      assert.strictEqual(classifier.state, 'refractory')
      assert.strictEqual(classifier.isTargetReached, false)

      // 4. Refractory bypass (8s cooldown, 80 frames)
      for (let i = 0; i < 80; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.state, 'idle')

      // 5. Venting whistle 2: 1.8s (18 frames) -> reaches target!
      for (let i = 0; i < 18; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.40,
          whistleBandEnergy: 0.32,
          dominantFrequencyHz: 3100.0,
          durationMs: 100
        })
      }
      for (let i = 0; i < 4; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100
        })
      }

      assert.strictEqual(classifier.whistleCount, 2)
      assert.strictEqual(classifier.isTargetReached, true)
      assert.ok(events.some((e) => e.isTargetReached && e.status === 'target_reached'))
    })

    it('rejects exhaust fan rumble and brief clatter', () => {
      const classifier = new WeightedWhistleClassifier({ targetWhistles: 3 })

      // Exhaust fan low rumble
      for (let i = 0; i < 30; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.40,
          whistleBandEnergy: 0.03,
          dominantFrequencyHz: 120.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.whistleCount, 0)

      // Clattering spoon spike for 200ms
      for (let i = 0; i < 2; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.80,
          whistleBandEnergy: 0.60,
          dominantFrequencyHz: 3000.0,
          durationMs: 100
        })
      }
      for (let i = 0; i < 5; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.01,
          whistleBandEnergy: 0.001,
          dominantFrequencyHz: 100.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.whistleCount, 0)
    })

    it('supports manual increment and decrement', () => {
      const events: SignalEngineEvent[] = []
      const classifier = new WeightedWhistleClassifier({
        targetWhistles: 2,
        onEvent: (e) => events.push(e)
      })

      classifier.manualIncrement()
      assert.strictEqual(classifier.whistleCount, 1)
      assert.strictEqual(classifier.isTargetReached, false)

      classifier.manualIncrement()
      assert.strictEqual(classifier.whistleCount, 2)
      assert.strictEqual(classifier.isTargetReached, true)

      classifier.manualDecrement()
      assert.strictEqual(classifier.whistleCount, 1)
      assert.strictEqual(classifier.isTargetReached, false)
    })
  })

  describe('SpringValveHissClassifier', () => {
    it('detects continuous hiss, pressure onset, simmer timing, and completion', () => {
      const events: SignalEngineEvent[] = []
      const classifier = new SpringValveHissClassifier({
        targetSimmerSeconds: 5,
        onEvent: (e) => events.push(e)
      })

      // 1. Initial heating
      for (let i = 0; i < 10; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.03,
          whistleBandEnergy: 0.005,
          highHissBandEnergy: 0.005,
          dominantFrequencyHz: 500.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.isAtPressure, false)

      // 2. High frequency hiss begins (5,500 Hz, 2.5s continuous)
      for (let i = 0; i < 25; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.05,
          highHissBandEnergy: 0.18,
          dominantFrequencyHz: 5500.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.isAtPressure, true)
      assert.ok(events.some((e) => e.status === 'pressure_reached'))

      // 3. Simmer for 5 seconds (50 frames)
      for (let i = 0; i < 50; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.20,
          whistleBandEnergy: 0.04,
          highHissBandEnergy: 0.15,
          dominantFrequencyHz: 5200.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.isTargetReached, true)
      assert.ok(events.some((e) => e.status === 'target_reached'))
    })

    it('alerts on overpressure venting and detects loss of pressure', () => {
      const events: SignalEngineEvent[] = []
      const classifier = new SpringValveHissClassifier({
        targetSimmerSeconds: 60,
        onEvent: (e) => events.push(e)
      })

      // Establish pressure (2.5s)
      for (let i = 0; i < 25; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.05,
          highHissBandEnergy: 0.18,
          dominantFrequencyHz: 5500.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.isAtPressure, true)

      // Overpressure: violent steam venting (RMS = 0.75)
      classifier.processFrame({
        totalRmsEnergy: 0.75,
        whistleBandEnergy: 0.10,
        highHissBandEnergy: 0.55,
        dominantFrequencyHz: 6000.0,
        durationMs: 100
      })
      assert.ok(events.some((e) => e.status === 'overpressure_alert'))

      // Heat turned off -> hiss ceases for 4.5s
      for (let i = 0; i < 45; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          highHissBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100
        })
      }
      assert.strictEqual(classifier.isAtPressure, false)
      assert.ok(events.some((e) => e.status === 'pressure_lost'))
    })
  })

  describe('ElectricBeepClassifier', () => {
    it('detects rhythmic completion beep train (3-beep pattern)', () => {
      const events: SignalEngineEvent[] = []
      const classifier = new ElectricBeepClassifier({
        targetBeepCount: 3,
        onEvent: (e) => events.push(e)
      })

      const emitBeep = (durationMs: number, freqHz: number) => {
        const frames = Math.floor(durationMs / 50)
        for (let i = 0; i < frames; i++) {
          classifier.processFrame({
            totalRmsEnergy: 0.30,
            whistleBandEnergy: 0.02,
            beepBandEnergy: 0.26,
            dominantFrequencyHz: freqHz,
            durationMs: 50
          })
        }
      }

      const emitSilence = (durationMs: number) => {
        const frames = Math.floor(durationMs / 50)
        for (let i = 0; i < frames; i++) {
          classifier.processFrame({
            totalRmsEnergy: 0.02,
            whistleBandEnergy: 0.001,
            beepBandEnergy: 0.001,
            dominantFrequencyHz: 150.0,
            durationMs: 50
          })
        }
      }

      // Beep 1
      emitBeep(200, 2800.0)
      emitSilence(150)
      assert.strictEqual(classifier.detectedBeeps, 1)

      // Beep 2
      emitBeep(200, 2800.0)
      emitSilence(150)
      assert.strictEqual(classifier.detectedBeeps, 2)
      assert.strictEqual(classifier.isTargetReached, false)

      // Beep 3 -> Target Reached!
      emitBeep(200, 2800.0)
      emitSilence(50)
      assert.strictEqual(classifier.detectedBeeps, 3)
      assert.strictEqual(classifier.isTargetReached, true)
      assert.ok(events.some((e) => e.status === 'target_reached'))
    })

    it('resets on silence timeout after isolated microwave button beep', () => {
      const classifier = new ElectricBeepClassifier({ targetBeepCount: 3 })

      // Single 150ms beep tone
      for (let i = 0; i < 3; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.30,
          whistleBandEnergy: 0.02,
          beepBandEnergy: 0.25,
          dominantFrequencyHz: 2800.0,
          durationMs: 50
        })
      }
      // Followed by silence > 600ms
      for (let i = 0; i < 14; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.01,
          whistleBandEnergy: 0.001,
          beepBandEnergy: 0.001,
          dominantFrequencyHz: 100.0,
          durationMs: 50
        })
      }
      assert.strictEqual(classifier.detectedBeeps, 0)
      assert.strictEqual(classifier.isTargetReached, false)
    })
  })

  describe('MechanicalClickClassifier', () => {
    it('confirms warm transition after click impulse and subsequent thermal/boiling drop', () => {
      const events: SignalEngineEvent[] = []
      const classifier = new MechanicalClickClassifier({ onEvent: (e) => events.push(e) })

      // 1. Active boiling (2.0s)
      for (let i = 0; i < 20; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.28,
          whistleBandEnergy: 0.04,
          dominantFrequencyHz: 800.0,
          durationMs: 100,
          crestFactor: 1.4
        })
      }

      // 2. Mechanical click impulse (crest factor 3.8)
      classifier.processFrame({
        totalRmsEnergy: 0.45,
        whistleBandEnergy: 0.05,
        dominantFrequencyHz: 2200.0,
        durationMs: 100,
        crestFactor: 3.8
      })
      assert.ok(events.some((e) => e.status === 'click_detected'))

      // 3. Post-click quiet warm hum (2.2s)
      for (let i = 0; i < 22; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.04,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 200.0,
          durationMs: 100,
          crestFactor: 1.2
        })
      }

      assert.strictEqual(classifier.isTargetReached, true)
      assert.ok(events.some((e) => e.status === 'target_reached'))
    })

    it('rejects clatter if boiling noise continues unabated', () => {
      const classifier = new MechanicalClickClassifier()

      // Active boiling (2.0s)
      for (let i = 0; i < 20; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.03,
          dominantFrequencyHz: 800.0,
          durationMs: 100,
          crestFactor: 1.4
        })
      }

      // Cutlery clatter impulse
      classifier.processFrame({
        totalRmsEnergy: 0.50,
        whistleBandEnergy: 0.05,
        dominantFrequencyHz: 2500.0,
        durationMs: 100,
        crestFactor: 3.5
      })

      // Water continues boiling vigorously
      for (let i = 0; i < 22; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.03,
          dominantFrequencyHz: 800.0,
          durationMs: 100,
          crestFactor: 1.4
        })
      }

      assert.strictEqual(classifier.isTargetReached, false)
    })
  })

  describe('KettleWhistleClassifier', () => {
    it('triggers boil alert on sustained kettle whistle', () => {
      const events: SignalEngineEvent[] = []
      const classifier = new KettleWhistleClassifier({ onEvent: (e) => events.push(e) })

      // Heating
      for (let i = 0; i < 10; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.02,
          whistleBandEnergy: 0.002,
          dominantFrequencyHz: 300.0,
          durationMs: 100
        })
      }

      // Continuous 2,800 Hz resonant whistle for 3.5 seconds
      for (let i = 0; i < 35; i++) {
        classifier.processFrame({
          totalRmsEnergy: 0.35,
          whistleBandEnergy: 0.28,
          dominantFrequencyHz: 2800.0,
          durationMs: 100
        })
      }

      assert.strictEqual(classifier.isTargetReached, true)
      assert.ok(events.some((e) => e.status === 'target_reached'))
    })
  })

  describe('CookingSignalEngine Unified', () => {
    it('dispatches frames correctly to selected active mode', () => {
      let targetEvents = 0
      const engine = new CookingSignalEngine({
        activeType: 'springValveHiss',
        targetSimmerSeconds: 2,
        onEvent: (e) => {
          if (e.isTargetReached) targetEvents++
        }
      })

      // Pressure onset (2.2s)
      for (let i = 0; i < 22; i++) {
        engine.processFrame({
          totalRmsEnergy: 0.25,
          whistleBandEnergy: 0.04,
          highHissBandEnergy: 0.18,
          dominantFrequencyHz: 5500.0,
          durationMs: 100
        })
      }

      // Simmer 2 seconds
      for (let i = 0; i < 20; i++) {
        engine.processFrame({
          totalRmsEnergy: 0.20,
          whistleBandEnergy: 0.03,
          highHissBandEnergy: 0.15,
          dominantFrequencyHz: 5200.0,
          durationMs: 100
        })
      }

      assert.strictEqual(engine.isTargetReached, true)
      assert.strictEqual(targetEvents, 1)
    })
  })
})
