<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { toDevanagariDigits } from '@siti-counter/kitchen-engine'
import CastReceiver from './components/CastReceiver.vue'
import WebCheckout from './components/WebCheckout.vue'

type Cooktop = 'lpgGas' | 'induction' | 'infrared' | 'electricCoil'

interface CooktopInfo {
  id: Cooktop
  labelEn: string
  labelNe: string
  guidanceEn: string
  guidanceNe: string
  whistleOffset: number
}

const COOKTOPS: Record<Cooktop, CooktopInfo> = {
  lpgGas: {
    id: 'lpgGas',
    labelEn: 'LPG Gas',
    labelNe: 'एलपिजी ग्यास (LPG)',
    guidanceEn: 'Medium flame until first whistle, then reduce to low flame',
    guidanceNe: 'पहिलो सिट्ठीसम्म मध्यम नीलो आगो, त्यसपछि मन्द आगो',
    whistleOffset: 0,
  },
  induction: {
    id: 'induction',
    labelEn: 'Induction',
    labelNe: 'इन्डक्सन (Induction)',
    guidanceEn: '1000–1200W until first whistle, reduce to 800W simmer',
    guidanceNe: '१०००–१२०० वाट (पहिलो सिट्ठीपछि मन्द ८०० वाट)',
    whistleOffset: 0,
  },
  infrared: {
    id: 'infrared',
    labelEn: 'Infrared',
    labelNe: 'इन्फ्रारेड (Infrared)',
    guidanceEn: 'Medium-high, adjust promptly to prevent bottom scorch',
    guidanceNe: 'मध्यम-कडा, फेद डढ्न नदिन छिटो ताप नियन्त्रण गर्नुहोस्',
    whistleOffset: 0,
  },
  electricCoil: {
    id: 'electricCoil',
    labelEn: 'Electric Coil',
    labelNe: 'हटर/क्वाइल (Electric)',
    guidanceEn: 'Setting 4/6, allow slower thermal ramp-up (+1 whistle)',
    guidanceNe: 'मध्यम-कडा (स्तर ४), ढिलो तात्ने हुनाले +१ थप सिट्ठी सिफारिस',
    whistleOffset: 1,
  },
}

const STEPS = [
  {
    step: 1,
    en: 'Wash dal thoroughly and place inside pressure cooker with water, salt, and turmeric.',
    ne: 'दाल सफासँग पखालेर प्रेसर कुकरमा पानी, नुन र बेसारसँगै राख्नुहोस्।',
  },
  {
    step: 2,
    en: 'Secure the lid firmly, place cooker over heat, and track required whistles.',
    ne: 'कुकरको ढक्कन राम्ररी बन्द गरी आगोमा राख्नुहोस् र लक्षित सिट्ठी गन्नुहोस्।',
  },
  {
    step: 3,
    en: 'Turn off flame immediately upon target whistles; let pressure release naturally.',
    ne: 'सिट्ठी पुगेपछि तुरुन्तै आगो बन्द गर्नुहोस् र प्रेसर स्वतः सेलाउन दिनुहोस्।',
  },
]

// State
const count = ref(0)
const baseTarget = ref(3)
const selectedCooktop = ref<Cooktop>('lpgGas')
const language = ref<'ne' | 'en'>('ne')
const isAlarmActive = ref(false)
const isMuted = ref(false)
const isWakeLockActive = ref(false)
const currentStepIndex = ref(1)

const isNepali = computed(() => language.value === 'ne')

const effectiveTarget = computed(() => {
  return baseTarget.value + COOKTOPS[selectedCooktop.value].whistleOffset
})

const currentDisplay = computed(() => {
  return isNepali.value ? toDevanagariDigits(count.value) : `${count.value}`
})

const targetDisplay = computed(() => {
  return isNepali.value ? toDevanagariDigits(effectiveTarget.value) : `${effectiveTarget.value}`
})

const remainingCount = computed(() => {
  return Math.max(0, effectiveTarget.value - count.value)
})

const progressFraction = computed(() => {
  return Math.min(1.0, count.value / (effectiveTarget.value || 1))
})

// Web Audio API Synthesizer for Distinct Kitchen Alarm
let audioCtx: AudioContext | null = null
let alarmInterval: number | null = null

function getAudioContext(): AudioContext {
  if (!audioCtx) {
    const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext
    audioCtx = new AudioContextClass()
  }
  if (audioCtx.state === 'suspended') {
    audioCtx.resume()
  }
  return audioCtx
}

function playBeep(freq: number, durationSec: number, delaySec = 0) {
  if (isMuted.value) return
  try {
    const ctx = getAudioContext()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()

    osc.type = 'triangle'
    osc.frequency.setValueAtTime(freq, ctx.currentTime + delaySec)

    gain.gain.setValueAtTime(0.001, ctx.currentTime + delaySec)
    gain.gain.exponentialRampToValueAtTime(0.3, ctx.currentTime + delaySec + 0.04)
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + delaySec + durationSec)

    osc.connect(gain)
    gain.connect(ctx.destination)

    osc.start(ctx.currentTime + delaySec)
    osc.stop(ctx.currentTime + delaySec + durationSec)
  } catch (_) {
    // Audio context not allowed before user interaction
  }
}

function playAlarmTone() {
  playBeep(880, 0.18, 0)
  playBeep(1760, 0.25, 0.2)
}

function triggerAlarm() {
  if (isAlarmActive.value) return
  isAlarmActive.value = true
  playAlarmTone()

  if (alarmInterval) clearInterval(alarmInterval)
  alarmInterval = window.setInterval(() => {
    if (!isAlarmActive.value) {
      if (alarmInterval) clearInterval(alarmInterval)
      return
    }
    playAlarmTone()
  }, 1400)
}

function stopAlarm() {
  if (alarmInterval) {
    clearInterval(alarmInterval)
    alarmInterval = null
  }
  isAlarmActive.value = false
}

function increment() {
  count.value++
  if (count.value >= effectiveTarget.value) {
    triggerAlarm()
  }
}

function decrement() {
  if (count.value > 0) {
    count.value--
    if (count.value < effectiveTarget.value && isAlarmActive.value) {
      stopAlarm()
    }
  }
}

function reset() {
  stopAlarm()
  count.value = 0
}

function toggleMute() {
  isMuted.value = !isMuted.value
  if (isMuted.value && isAlarmActive.value) {
    stopAlarm()
  }
}

// Screen Wake Lock API
let wakeLockSentinel: any = null

async function requestWakeLock() {
  try {
    if ('wakeLock' in navigator) {
      wakeLockSentinel = await (navigator as any).wakeLock.request('screen')
      isWakeLockActive.value = true
      wakeLockSentinel.addEventListener('release', () => {
        isWakeLockActive.value = false
      })
    }
  } catch (_) {
    isWakeLockActive.value = false
  }
}

async function releaseWakeLock() {
  if (wakeLockSentinel) {
    try {
      await wakeLockSentinel.release()
    } catch (_) {}
    wakeLockSentinel = null
  }
  isWakeLockActive.value = false
}

const isCastMode = ref(false)
const isCheckoutOpen = ref(false)
const householdId = ref('hh_web_default')
const isPremiumActive = ref(false)

function onSubscriptionUpdated(entitlement: Record<string, unknown>) {
  if (entitlement.tier === 'householdAnnual') {
    isPremiumActive.value = true
  }
}

onMounted(() => {
  requestWakeLock()
  try {
    const params = new URLSearchParams(window.location.search)
    if (params.get('receiver') === 'true' || params.get('receiver') === '1' || params.get('mode') === 'cast') {
      isCastMode.value = true
    }
    if (params.get('gift') || params.get('checkout') === 'true') {
      isCheckoutOpen.value = true
    }
    const cached = localStorage.getItem(`siti_entitlement_${householdId.value}`)
    if (cached) {
      const parsed = JSON.parse(cached)
      if (parsed.tier === 'householdAnnual') {
        isPremiumActive.value = true
      }
    }
  } catch (_) {}
})


onUnmounted(() => {
  stopAlarm()
  releaseWakeLock()
})

watch(effectiveTarget, (newTarget) => {
  if (count.value >= newTarget && count.value > 0) {
    triggerAlarm()
  } else if (isAlarmActive.value && count.value < newTarget) {
    stopAlarm()
  }
})
</script>

<template>
  <CastReceiver v-if="isCastMode" />
  <div v-else :class="['kitchen-mode-container', { 'alarm-mode': isAlarmActive }]">
    <!-- Header -->
    <header class="app-header">
      <div class="brand">
        <h1>🍲 Siti Counter 3.0</h1>
        <span class="badge kitchen-badge">
          {{ isNepali ? 'भान्सा मोड (Kitchen Mode)' : 'Kitchen Active Session' }}
        </span>
      </div>

      <div class="header-actions">
        <!-- Smart Display / Nest Hub Cast Mode Toggle -->
        <button
          class="icon-btn"
          @click="isCastMode = true"
          :title="isNepali ? 'नेस्ट हब / स्मार्ट डिस्प्ले मोड' : 'Nest Hub / Cast Display Mode'"
        >
          📺
        </button>

        <!-- Wake Lock Status -->
        <span class="badge wake-badge" :title="isWakeLockActive ? 'Screen kept awake' : 'Wake lock inactive'">
          ⚡ {{ isNepali ? (isWakeLockActive ? 'स्क्रिन अन' : 'स्ट्यान्डबाइ') : (isWakeLockActive ? 'Screen Awake' : 'Standby') }}
        </span>

        <!-- Audio Mute Button -->
        <button class="icon-btn" @click="toggleMute" :title="isMuted ? 'Unmute' : 'Mute'">
          {{ isMuted ? '🔇' : '🔔' }}
        </button>

        <!-- Premium Subscription / Gifting Button -->
        <button
          class="premium-toggle-btn"
          @click="isCheckoutOpen = true"
          :title="isNepali ? 'प्रिमियम सदस्यता / उपहार' : 'Premium Subscription / Family Gift'"
        >
          {{ isPremiumActive ? '⭐️ ' + (isNepali ? 'प्रिमियम सक्रिय' : 'Premium Active') : '⭐️ ' + (isNepali ? 'प्रिमियम' : 'Go Premium') }}
        </button>

        <!-- Language Switcher -->
        <button class="lang-toggle-btn" @click="language = language === 'ne' ? 'en' : 'ne'">
          {{ language === 'ne' ? 'English' : 'नेपाली' }}
        </button>
      </div>
    </header>

    <!-- Pulsing Alarm Banner (when target reached) -->
    <section v-if="isAlarmActive" class="alarm-banner" role="alert">
      <div class="alarm-content">
        <span class="alarm-icon">🔔</span>
        <div>
          <h3>{{ isNepali ? 'सिट्ठी पुग्यो! आगो तुरुन्त बन्द गर्नुहोस्' : 'Target Reached! Turn off the flame immediately' }}</h3>
          <p>{{ isNepali ? 'प्रेसर स्वतः सेलाउन दिनुहोस् (Natural Release)' : 'Allow steam pressure to release naturally' }}</p>
        </div>
      </div>
      <button class="stop-alarm-btn" @click="stopAlarm">
        {{ isNepali ? 'अलार्म बन्द' : 'Stop Alarm' }}
      </button>
    </section>

    <main class="kitchen-grid">
      <!-- 2-Meter Glanceable Counter Card -->
      <section class="card counter-card">
        <div class="gauge-container">
          <!-- Circular SVG Gauge -->
          <svg class="progress-ring" viewBox="0 0 280 280" width="280" height="280">
            <circle
              class="track-circle"
              cx="140"
              cy="140"
              r="115"
              fill="none"
              stroke="#eee"
              stroke-width="18"
            />
            <circle
              class="progress-circle"
              cx="140"
              cy="140"
              r="115"
              fill="none"
              :stroke="isAlarmActive ? '#d32f2f' : '#d95328'"
              stroke-width="18"
              stroke-linecap="round"
              :stroke-dasharray="2 * Math.PI * 115"
              :stroke-dashoffset="(1 - progressFraction) * (2 * Math.PI * 115)"
              transform="rotate(-90 140 140)"
            />
          </svg>

          <!-- Massive Center Numbers (2-meter glanceable) -->
          <div class="counter-text-overlay">
            <div class="numbers">
              <span class="count-num">{{ currentDisplay }}</span>
              <span class="slash">/</span>
              <span class="target-num">{{ targetDisplay }}</span>
            </div>
            <div class="siti-label">{{ isNepali ? 'सिट्ठी (SITI)' : 'WHISTLES' }}</div>
          </div>
        </div>

        <!-- Remaining Status Badge -->
        <div :class="['status-pill', { ready: count >= effectiveTarget }]">
          {{ count >= effectiveTarget
              ? (isNepali ? '✓ सिट्ठी पूरा भयो!' : '✓ Target Reached!')
              : (isNepali ? `${toDevanagariDigits(remainingCount)} सिट्ठी बाँकी` : `${remainingCount} whistle${remainingCount === 1 ? '' : 's'} remaining`)
          }}
        </div>

        <!-- Tactile Fallback Buttons (+1 / -1) -->
        <div class="tactile-controls">
          <button class="btn-step" :disabled="count <= 0" @click="decrement" title="-1 Whistle">
            -१ (-1)
          </button>
          <button class="btn-increment" @click="increment" title="+1 Whistle">
            +१ सिट्ठी (+1 Siti)
          </button>
          <button class="btn-reset" @click="reset" title="Reset Counter">
            {{ isNepali ? 'रिसेट' : 'Reset' }}
          </button>
        </div>

        <!-- Target Whistle Adjuster -->
        <div class="target-adjuster">
          <label>{{ isNepali ? 'लक्षित सिट्ठी परिवर्तन:' : 'Target Whistles:' }}</label>
          <div class="stepper">
            <button class="mini-btn" :disabled="baseTarget <= 1" @click="baseTarget--">-</button>
            <span class="base-target-val">
              {{ isNepali ? toDevanagariDigits(baseTarget) : baseTarget }}
            </span>
            <button class="mini-btn" :disabled="baseTarget >= 16" @click="baseTarget++">+</button>
          </div>
        </div>
      </section>

      <!-- Active Step Guide & Heat Guidance Card -->
      <section class="card step-card">
        <!-- Cooktop Selector Tabs -->
        <div class="cooktop-section">
          <h4>{{ isNepali ? 'खाना पकाउने उपकरण (Cooktop)' : 'Cooking Appliance' }}</h4>
          <div class="cooktop-tabs">
            <button
              v-for="ck in (Object.keys(COOKTOPS) as Cooktop[])"
              :key="ck"
              :class="['cooktop-tab', { active: selectedCooktop === ck }]"
              @click="selectedCooktop = ck"
            >
              {{ isNepali ? COOKTOPS[ck].labelNe : COOKTOPS[ck].labelEn }}
            </button>
          </div>

          <!-- Heat Guidance Banner -->
          <div class="heat-guidance-box">
            <span class="heat-icon">🔥</span>
            <div>
              <strong>{{ isNepali ? 'ताप मार्गदर्शन:' : 'Heat Guidance:' }}</strong>
              <p>{{ isNepali ? COOKTOPS[selectedCooktop].guidanceNe : COOKTOPS[selectedCooktop].guidanceEn }}</p>
            </div>
          </div>
        </div>

        <!-- Active Step Instruction -->
        <div class="steps-section">
          <h4>
            {{ isNepali ? `सक्रिय चरण ${toDevanagariDigits(currentStepIndex)} / ${toDevanagariDigits(STEPS.length)}` : `Active Step ${currentStepIndex} of ${STEPS.length}` }}
          </h4>
          <p class="step-instruction">
            {{ isNepali ? STEPS[currentStepIndex - 1].ne : STEPS[currentStepIndex - 1].en }}
          </p>

          <div class="step-nav-buttons">
            <button
              class="secondary-nav-btn"
              :disabled="currentStepIndex <= 1"
              @click="currentStepIndex--"
            >
              {{ isNepali ? 'अघिल्लो चरण' : 'Previous Step' }}
            </button>
            <button
              class="primary-nav-btn"
              :disabled="currentStepIndex >= STEPS.length"
              @click="currentStepIndex++"
            >
              {{ isNepali ? 'पछिल्लो चरण' : 'Next Step' }}
            </button>
          </div>
        </div>
      </section>
    </main>

    <!-- Web Checkout & Entitlements Modal -->
    <WebCheckout
      v-if="isCheckoutOpen"
      :household-id="householdId"
      :language="language"
      @close="isCheckoutOpen = false"
      @subscription-updated="onSubscriptionUpdated"
    />
  </div>
</template>

<style scoped>
.premium-toggle-btn {
  background-color: #FFF3E0;
  color: #E65100;
  border: 1px solid #FFE0B2;
  font-weight: 700;
  font-size: 0.85rem;
  border-radius: var(--siti-radius-md);
  padding: 0.5rem 0.8rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.premium-toggle-btn:hover {
  background-color: #FFE0B2;
}

.kitchen-mode-container {

  max-width: 960px;
  margin: 0 auto;
  padding: 1.2rem;
  transition: background-color 0.3s ease;
}

.kitchen-mode-container.alarm-mode {
  background-color: #fff2ef;
}

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
  gap: 1rem;
}

.brand h1 {
  font-size: 1.8rem;
  margin: 0;
  color: var(--siti-color-primary-terracotta);
}

.badge {
  display: inline-block;
  padding: 0.25rem 0.6rem;
  border-radius: var(--siti-radius-md);
  font-size: 0.85rem;
  font-weight: 600;
}

.kitchen-badge {
  background-color: #fbe9e7;
  color: #b9421e;
  margin-top: 0.3rem;
}

.wake-badge {
  background-color: #e8f5e9;
  color: #2e7d32;
  border: 1px solid #c8e6c9;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 0.8rem;
}

.icon-btn, .lang-toggle-btn {
  background-color: #f0f0f0;
  color: #333;
  border-radius: var(--siti-radius-md);
  padding: 0.4rem 0.8rem;
  font-size: 0.9rem;
  min-height: auto;
}

.icon-btn:hover, .lang-toggle-btn:hover {
  background-color: #e0e0e0;
}

/* Alarm Banner */
.alarm-banner {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: #d32f2f;
  color: #ffffff;
  padding: 1rem 1.4rem;
  border-radius: var(--siti-radius-lg);
  margin-bottom: 1.5rem;
  box-shadow: 0 4px 16px rgba(211, 47, 47, 0.4);
  animation: pulseAlarm 1.2s infinite alternate;
}

@keyframes pulseAlarm {
  0% { transform: scale(1); }
  100% { transform: scale(1.02); }
}

.alarm-content {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.alarm-icon {
  font-size: 2rem;
}

.alarm-content h3 {
  margin: 0 0 0.2rem 0;
  font-size: 1.2rem;
  font-weight: 700;
}

.alarm-content p {
  margin: 0;
  font-size: 0.9rem;
  opacity: 0.9;
}

.stop-alarm-btn {
  background-color: #ffffff;
  color: #d32f2f;
  font-weight: 800;
  border-radius: var(--siti-radius-md);
  padding: 0.6rem 1.2rem;
}

.stop-alarm-btn:hover {
  background-color: #fdf2f2;
}

/* Grid Layout */
.kitchen-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
}

@media (max-width: 768px) {
  .kitchen-grid {
    grid-template-columns: 1fr;
  }
}

/* Counter Card */
.counter-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 2rem 1.5rem;
}

.gauge-container {
  position: relative;
  width: 280px;
  height: 280px;
  margin-bottom: 1.5rem;
}

.progress-ring {
  transform: rotate(-90deg);
}

.progress-circle {
  transition: stroke-dashoffset 0.4s ease, stroke 0.3s ease;
}

.counter-text-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
}

.numbers {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: 0.2rem;
}

.count-num {
  font-size: var(--siti-typography-siti-counter-across-room, 100px);
  font-weight: 900;
  color: var(--siti-color-primary-terracotta);
  line-height: 1;
}

.slash {
  font-size: 2.5rem;
  color: #ccc;
  margin: 0 0.2rem;
}

.target-num {
  font-size: 3.2rem;
  font-weight: 700;
  color: #666;
  line-height: 1;
}

.siti-label {
  font-size: 1.1rem;
  font-weight: 800;
  letter-spacing: 2px;
  color: #888;
  margin-top: 0.2rem;
}

.status-pill {
  padding: 0.4rem 1.2rem;
  border-radius: var(--siti-radius-full);
  background-color: #f7f7f7;
  color: #555;
  font-weight: 700;
  font-size: 1rem;
  margin-bottom: 1.5rem;
  border: 1px solid #e0e0e0;
}

.status-pill.ready {
  background-color: #e8f5e9;
  color: #2e7d32;
  border-color: #a5d6a7;
}

/* Tactile Controls */
.tactile-controls {
  display: flex;
  gap: 0.8rem;
  width: 100%;
  margin-bottom: 1.5rem;
}

.btn-step, .btn-reset {
  background-color: #f0f0f0;
  color: #333;
  font-weight: 700;
  padding: 0.8rem 1rem;
  border-radius: var(--siti-radius-lg);
  flex: 1;
}

.btn-increment {
  flex: 2;
  background-color: var(--siti-color-primary-terracotta);
  color: #ffffff;
  font-size: 1.15rem;
  font-weight: 800;
  padding: 0.8rem 1.2rem;
  border-radius: var(--siti-radius-lg);
  box-shadow: 0 4px 12px rgba(217, 83, 40, 0.35);
}

.btn-increment:hover {
  background-color: var(--siti-color-primary-terracotta-dark);
}

.target-adjuster {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding-top: 1rem;
  border-top: 1px solid #eee;
  font-size: 0.9rem;
}

.stepper {
  display: flex;
  align-items: center;
  gap: 0.6rem;
}

.mini-btn {
  background-color: #e0e0e0;
  color: #333;
  width: 32px;
  height: 32px;
  padding: 0;
  border-radius: var(--siti-radius-md);
  font-size: 1.1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: auto;
}

.base-target-val {
  font-weight: 800;
  font-size: 1.2rem;
  min-width: 28px;
  text-align: center;
  color: var(--siti-color-primary-terracotta);
}

/* Step & Guidance Card */
.step-card {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  text-align: left;
}

.cooktop-section h4, .steps-section h4 {
  margin: 0 0 0.8rem 0;
  font-size: 1rem;
  color: #444;
}

.cooktop-tabs {
  display: flex;
  gap: 0.4rem;
  flex-wrap: wrap;
  margin-bottom: 0.8rem;
}

.cooktop-tab {
  background-color: #f5f5f5;
  color: #555;
  font-size: 0.85rem;
  font-weight: 600;
  padding: 0.4rem 0.8rem;
  border-radius: var(--siti-radius-md);
  min-height: auto;
}

.cooktop-tab.active {
  background-color: var(--siti-color-primary-terracotta);
  color: #ffffff;
}

.heat-guidance-box {
  display: flex;
  gap: 0.8rem;
  background-color: #fff8e1;
  border: 1px solid #ffe082;
  border-radius: var(--siti-radius-md);
  padding: 0.8rem 1rem;
}

.heat-icon {
  font-size: 1.4rem;
}

.heat-guidance-box strong {
  display: block;
  font-size: 0.85rem;
  color: #e65100;
  margin-bottom: 0.2rem;
}

.heat-guidance-box p {
  margin: 0;
  font-size: 0.9rem;
  color: #5d4037;
  font-weight: 600;
}

.step-instruction {
  font-size: 1.15rem;
  font-weight: 600;
  line-height: 1.4;
  color: #222;
  background-color: #fafafa;
  padding: 1.2rem;
  border-radius: var(--siti-radius-lg);
  border-left: 4px solid var(--siti-color-primary-terracotta);
}

.step-nav-buttons {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  margin-top: 1rem;
}

.secondary-nav-btn {
  background-color: #f0f0f0;
  color: #444;
  font-weight: 600;
  border-radius: var(--siti-radius-md);
}

.primary-nav-btn {
  background-color: var(--siti-color-primary-terracotta);
  color: #ffffff;
  font-weight: 700;
  border-radius: var(--siti-radius-md);
}
</style>
