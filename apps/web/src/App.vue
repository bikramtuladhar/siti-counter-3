<script setup lang="ts">
import { ref } from 'vue'

const count = ref(0)
const target = ref(3)

function increment() {
  count.value++
}

function reset() {
  count.value = 0
}
</script>

<template>
  <header>
    <h1>🍲 Siti Counter 3.0</h1>
    <p class="subtitle">Household Cooking Companion — Web & Kitchen Display</p>
  </header>

  <main>
    <div class="card">
      <h2>Active Kitchen Session</h2>
      <div class="siti-display">
        <span class="count">{{ count }}</span>
        <span class="divider">/</span>
        <span class="target">{{ target }}</span>
        <span class="unit">siti</span>
      </div>

      <div class="controls">
        <button @click="increment">+1 Siti</button>
        <button class="secondary" @click="reset">Reset</button>
      </div>

      <p class="status" v-if="count >= target">
        🔔 Target reached! Time to turn off the flame.
      </p>
    </div>
  </main>
</template>

<style scoped>
header h1 {
  font-size: 2.2rem;
  margin-bottom: 0.2rem;
  color: #d95328;
}

.subtitle {
  color: #666;
  margin-bottom: 2rem;
}

.siti-display {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: 0.5rem;
  margin: 1.5rem 0;
}

.count {
  font-size: 5rem;
  font-weight: 800;
  color: #d95328;
}

.divider, .target {
  font-size: 3rem;
  font-weight: 500;
  color: #888;
}

.unit {
  font-size: 1.5rem;
  font-weight: 600;
  text-transform: uppercase;
  color: #666;
}

.controls {
  display: flex;
  justify-content: center;
  gap: 1rem;
  margin-top: 1rem;
}

.secondary {
  background-color: #6c757d;
}

.secondary:hover {
  background-color: #5a6268;
}

.status {
  margin-top: 1.5rem;
  font-weight: 600;
  color: #2e7d32;
}
</style>
