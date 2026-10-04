<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import {
  SITI_CAST_NAMESPACE,
  CastProtocolEngine,
  CastCookingSessionState,
  FlameLevel,
  toDevanagariDigits,
} from '@siti-counter/kitchen-engine';

// Default / initial state for Cast smart display
const session = ref<CastCookingSessionState>({
  sessionId: 'cast-live-session',
  recipeNameEn: 'Yellow Lentil Dal & Rice',
  recipeNameNe: 'पहेँलो दाल र भात',
  currentStepIndex: 1,
  totalSteps: 4,
  stepInstructionEn: 'Place cooker over high heat until pressure builds and whistles blow.',
  stepInstructionNe: 'ठूलो आगोमा राख्नुहोस् जबसम्म सिट्ठी बज्न सुरु हुँदैन।',
  whistlesTarget: 3,
  whistlesCurrent: 1,
  timerSecondsRemaining: 340,
  flameLevel: 'high',
  isPaused: false,
  targetReached: false,
});

const isConnected = ref(false);
const celebrationActive = ref(false);
const showDemoControls = ref(false);
const isNepali = ref(true);

const formattedTimer = computed(() => {
  const secs = session.value.timerSecondsRemaining ?? 0;
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
});

const progressPercent = computed(() => {
  if (session.value.whistlesTarget <= 0) return 100;
  return Math.min(100, Math.round((session.value.whistlesCurrent / session.value.whistlesTarget) * 100));
});

const flameLabel = computed(() => {
  switch (session.value.flameLevel) {
    case 'high':
      return isNepali.value ? 'ठूलो आगो (High Flame)' : 'High Flame';
    case 'medium':
      return isNepali.value ? 'मध्यम आगो (Medium Flame)' : 'Medium Flame';
    case 'low':
      return isNepali.value ? 'मन्द आगो (Simmer / Low)' : 'Simmer / Low';
    case 'off':
      return isNepali.value ? 'आगो निभाउनुहोस् (OFF)' : 'Flame Off';
  }
});

function handleIncomingMessage(raw: string) {
  try {
    const msg = CastProtocolEngine.deserialize(raw);
    if (msg.type === 'COOKING_SESSION_UPDATE') {
      session.value = msg.payload as CastCookingSessionState;
      if (session.value.whistlesCurrent >= session.value.whistlesTarget && session.value.whistlesTarget > 0) {
        triggerCelebration();
      }
    } else if (msg.type === 'SITI_COUNT_UPDATE') {
      const p = msg.payload as { current: number; target: number; reached: boolean };
      session.value.whistlesCurrent = p.current;
      session.value.whistlesTarget = p.target;
      if (p.reached) {
        triggerCelebration();
      }
    } else if (msg.type === 'TIMER_UPDATE') {
      const t = msg.payload as { remainingSeconds: number; isPaused: boolean };
      session.value.timerSecondsRemaining = t.remainingSeconds;
      session.value.isPaused = t.isPaused;
    } else if (msg.type === 'TARGET_REACHED') {
      triggerCelebration();
    }
  } catch (err) {
    console.error('Error parsing Cast message:', err);
  }
}

function triggerCelebration() {
  celebrationActive.value = true;
  session.value.targetReached = true;
  session.value.flameLevel = 'off';
  setTimeout(() => {
    celebrationActive.value = false;
  }, 8000);
}

// Local simulation handlers for testing
function incrementWhistle() {
  session.value.whistlesCurrent += 1;
  if (session.value.whistlesCurrent >= session.value.whistlesTarget) {
    triggerCelebration();
  }
}

function decrementWhistle() {
  if (session.value.whistlesCurrent > 0) {
    session.value.whistlesCurrent -= 1;
    session.value.targetReached = false;
  }
}

function cycleFlame() {
  const levels: FlameLevel[] = ['high', 'medium', 'low', 'off'];
  const idx = levels.indexOf(session.value.flameLevel);
  session.value.flameLevel = levels[(idx + 1) % levels.length];
}

// Cast SDK integration
let castReceiverContext: any = null;

onMounted(() => {
  // 1. Check if running inside Google Cast CAF Receiver
  const win = window as any;
  if (win.cast && win.cast.framework) {
    try {
      castReceiverContext = win.cast.framework.CastReceiverContext.getInstance();
      castReceiverContext.addCustomMessageListener(SITI_CAST_NAMESPACE, (event: any) => {
        isConnected.value = true;
        handleIncomingMessage(event.data);
      });
      castReceiverContext.start();
      isConnected.value = true;
    } catch (e) {
      console.warn('Cast receiver framework initialization note:', e);
    }
  }

  // 2. BroadcastChannel for cross-tab or local simulator testing
  try {
    const channel = new BroadcastChannel('siti_cast_channel');
    channel.onmessage = (event) => {
      isConnected.value = true;
      handleIncomingMessage(event.data);
    };
  } catch (e) {
    // BroadcastChannel unsupported or restricted
  }
});

onUnmounted(() => {
  if (castReceiverContext) {
    try {
      castReceiverContext.stop();
    } catch (e) {
      // Ignore
    }
  }
});
</script>

<template>
  <div class="cast-display flex flex-col justify-between min-h-screen bg-neutral-950 text-white p-6 font-sans select-none overflow-hidden">
    <!-- Top Bar: Recipe Header & Cast Connection Badge -->
    <header class="flex items-center justify-between border-b border-neutral-800 pb-4">
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 rounded-2xl bg-gradient-to-tr from-amber-600 to-red-600 flex items-center justify-center shadow-lg shadow-red-950">
          <span class="text-2xl">🔔</span>
        </div>
        <div>
          <h1 class="text-2xl lg:text-3xl font-extrabold tracking-tight text-white">
            {{ isNepali && session.recipeNameNe ? session.recipeNameNe : session.recipeNameEn }}
          </h1>
          <p class="text-sm font-semibold text-neutral-400">
            {{ isNepali ? `चरण ${session.currentStepIndex + 1} / ${session.totalSteps}` : `Step ${session.currentStepIndex + 1} of ${session.totalSteps}` }}
          </p>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <button
          @click="isNepali = !isNepali"
          class="px-3 py-1.5 rounded-lg border border-neutral-700 bg-neutral-900 text-xs font-bold text-neutral-300 hover:border-neutral-500 transition-colors"
        >
          {{ isNepali ? 'English' : 'नेपाली' }}
        </button>
        <div
          class="flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-semibold"
          :class="isConnected ? 'bg-emerald-950/80 text-emerald-400 border border-emerald-800' : 'bg-neutral-800 text-neutral-400 border border-neutral-700'"
        >
          <span class="w-2.5 h-2.5 rounded-full" :class="isConnected ? 'bg-emerald-400 animate-pulse' : 'bg-neutral-500'"></span>
          <span>{{ isConnected ? 'Google Cast Connected' : 'Nest Hub Display Mode' }}</span>
        </div>
      </div>
    </header>

    <!-- Main Live Screen Area -->
    <main class="grid grid-cols-1 lg:grid-cols-12 gap-8 my-auto py-4 items-center">
      <!-- Left Column: Giant Siti Whistle Counter -->
      <div class="lg:col-span-6 flex flex-col items-center justify-center">
        <div
          class="relative w-64 h-64 lg:w-80 lg:h-80 rounded-full flex flex-col items-center justify-center p-6 border-8 transition-all duration-500 shadow-2xl"
          :class="[
            session.targetReached
              ? 'border-emerald-500 bg-emerald-950/40 shadow-emerald-900/50 scale-105'
              : 'border-amber-500 bg-neutral-900/90 shadow-amber-950/40',
          ]"
        >
          <!-- Circular Progress Ring Indicator -->
          <div class="text-xs uppercase tracking-widest font-black" :class="session.targetReached ? 'text-emerald-400' : 'text-amber-400'">
            {{ isNepali ? 'सिठी काउन्टर' : 'SITI COUNTER' }}
          </div>

          <!-- Giant Digits -->
          <div class="flex items-baseline gap-1 my-1">
            <span class="text-7xl lg:text-9xl font-black tracking-tight" :class="session.targetReached ? 'text-emerald-300 animate-bounce' : 'text-white'">
              {{ isNepali ? toDevanagariDigits(session.whistlesCurrent) : session.whistlesCurrent }}
            </span>
            <span class="text-3xl lg:text-4xl font-bold text-neutral-500">
              / {{ isNepali ? toDevanagariDigits(session.whistlesTarget) : session.whistlesTarget }}
            </span>
          </div>

          <div class="text-sm font-bold text-neutral-400">
            {{ isNepali ? 'लक्षित सिठीहरू' : 'Target Whistles' }}
          </div>

          <!-- Progress Percentage Bar under count -->
          <div class="w-36 h-2 bg-neutral-800 rounded-full mt-3 overflow-hidden border border-neutral-700">
            <div
              class="h-full transition-all duration-500 rounded-full"
              :class="session.targetReached ? 'bg-emerald-400' : 'bg-gradient-to-r from-amber-500 to-red-500'"
              :style="{ width: `${progressPercent}%` }"
            ></div>
          </div>
        </div>
      </div>

      <!-- Right Column: Step Guidance, Flame Status & Timers -->
      <div class="lg:col-span-6 flex flex-col gap-6">
        <!-- Instruction Card -->
        <div class="p-6 rounded-3xl bg-neutral-900 border border-neutral-800 shadow-xl">
          <div class="text-xs font-bold text-amber-500 uppercase tracking-wider mb-2">
            {{ isNepali ? 'हालको निर्देशन' : 'Current Instruction' }}
          </div>
          <p class="text-xl lg:text-2xl font-bold leading-relaxed text-neutral-100">
            {{ isNepali && session.stepInstructionNe ? session.stepInstructionNe : session.stepInstructionEn }}
          </p>
        </div>

        <!-- Metrics Row: Flame Level & Timer -->
        <div class="grid grid-cols-2 gap-4">
          <!-- Flame Level Tile -->
          <div
            class="p-5 rounded-2xl border transition-colors flex flex-col justify-between"
            :class="[
              session.flameLevel === 'off'
                ? 'bg-neutral-900 border-neutral-700 text-neutral-300'
                : 'bg-red-950/30 border-red-800/80 text-red-200',
            ]"
          >
            <div class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-neutral-400">
              <span>🔥</span>
              <span>{{ isNepali ? 'आगोको स्तर' : 'Flame Control' }}</span>
            </div>
            <div class="text-lg lg:text-xl font-black mt-2">
              {{ flameLabel }}
            </div>
          </div>

          <!-- Timer Tile -->
          <div class="p-5 rounded-2xl bg-neutral-900 border border-neutral-800 flex flex-col justify-between">
            <div class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-neutral-400">
              <span>⏱</span>
              <span>{{ isNepali ? 'टाइमर' : 'Cook Timer' }}</span>
            </div>
            <div class="text-2xl lg:text-3xl font-black font-mono mt-1 text-cyan-400">
              {{ formattedTimer }}
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Celebration Banner Overlay when target reached -->
    <transition
      enter-active-class="transform transition ease-out duration-300"
      enter-from-class="translate-y-full opacity-0"
      enter-to-class="translate-y-0 opacity-100"
      leave-active-class="transition ease-in duration-200"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="celebrationActive"
        class="fixed inset-x-4 bottom-6 z-50 p-6 rounded-3xl bg-gradient-to-r from-emerald-600 via-teal-600 to-green-600 text-white shadow-2xl flex items-center justify-between border-2 border-emerald-300"
      >
        <div class="flex items-center gap-4">
          <span class="text-5xl animate-bounce">🎉</span>
          <div>
            <h2 class="text-2xl font-black">
              {{ isNepali ? 'सिठी पूरा भयो! ग्यास बन्द गर्नुहोस्' : 'Target Siti Reached! Turn off heat now' }}
            </h2>
            <p class="text-sm font-semibold opacity-90">
              {{ isNepali ? 'दाल/खाना राम्ररी पाकिसकेको छ।' : 'Pressure cooker cycle is fully complete.' }}
            </p>
          </div>
        </div>
        <button
          @click="celebrationActive = false"
          class="px-5 py-2.5 rounded-xl bg-white text-emerald-950 font-black text-sm hover:bg-neutral-100 transition-colors shadow"
        >
          {{ isNepali ? 'बुझें' : 'Dismiss' }}
        </button>
      </div>
    </transition>

    <!-- Bottom Bar: Simulator Controls (Collapsible for test validation) -->
    <footer class="pt-4 border-t border-neutral-800 flex items-center justify-between text-xs text-neutral-500">
      <div class="flex items-center gap-2">
        <span>Siti Counter 3.0 CAF Receiver • {{ SITI_CAST_NAMESPACE }}</span>
      </div>

      <div class="flex items-center gap-2">
        <button
          @click="showDemoControls = !showDemoControls"
          class="underline hover:text-neutral-300 transition-colors"
        >
          {{ showDemoControls ? 'Hide Simulator' : 'Show Simulator Controls' }}
        </button>

        <div v-if="showDemoControls" class="flex items-center gap-1.5 ml-4">
          <button @click="decrementWhistle" class="px-2 py-1 rounded bg-neutral-800 text-white font-bold hover:bg-neutral-700">- Siti</button>
          <button @click="incrementWhistle" class="px-2 py-1 rounded bg-amber-600 text-white font-bold hover:bg-amber-500">+ Siti</button>
          <button @click="cycleFlame" class="px-2 py-1 rounded bg-neutral-800 text-white font-bold hover:bg-neutral-700">Flame</button>
          <button @click="triggerCelebration" class="px-2 py-1 rounded bg-emerald-700 text-white font-bold hover:bg-emerald-600">Finish</button>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.cast-display {
  aspect-ratio: 16 / 9;
  max-width: 100vw;
  max-height: 100vh;
}
</style>
