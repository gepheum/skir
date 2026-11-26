<script setup lang="ts">
import { ref } from 'vue'

const copied = ref(false)
const command = 'npx skir init'

function copy() {
  if (typeof navigator !== 'undefined' && navigator.clipboard) {
    navigator.clipboard.writeText(command)
    copied.value = true
    setTimeout(() => {
      copied.value = false
    }, 1800)
  }
}
</script>

<template>
  <div class="copy-cmd-wrapper">
    <span aria-live="polite" class="copy-cmd-tooltip" :class="{ 'is-copied': copied }">
      {{ copied ? 'Copied!' : 'copy' }}
    </span>

    <button
      type="button"
      class="copy-cmd-button"
      aria-label="Copy npx skir init command"
      @click="copy"
    >
      <span class="copy-cmd-prefix">$</span>
      <span class="copy-cmd-text">{{ command }}</span>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="copy-cmd-icon"
      >
        <rect width="14" height="14" x="8" y="8" rx="2" ry="2" />
        <path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" />
      </svg>
    </button>
  </div>
</template>

<style scoped>
.copy-cmd-wrapper {
  position: relative;
  display: inline-flex;
}

.copy-cmd-tooltip {
  pointer-events: none;
  position: absolute;
  top: -30px;
  left: 50%;
  transform: translateX(-50%) translateY(-4px);
  border-radius: 6px;
  border: 1px solid var(--vp-c-divider);
  background-color: var(--vp-c-bg);
  padding: 2px 8px;
  font-size: 12px;
  font-weight: 500;
  color: var(--vp-c-text-2);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);
  opacity: 0;
  transition:
    opacity 0.15s,
    transform 0.15s;
  white-space: nowrap;
}

.copy-cmd-wrapper:hover .copy-cmd-tooltip,
.copy-cmd-tooltip.is-copied {
  opacity: 1;
  transform: translateX(-50%) translateY(0);
}

.copy-cmd-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 44px;
  padding: 0 22px;
  border-radius: 9999px;
  border: 1px solid var(--vp-c-divider);
  background-color: transparent;
  font-family: var(--vp-font-family-mono);
  font-size: 15px;
  color: var(--vp-c-text-1);
  cursor: pointer;
  transition:
    border-color 0.2s,
    background-color 0.2s;
}

.copy-cmd-button:hover {
  border-color: var(--vp-c-brand-1);
  background-color: var(--vp-c-bg-soft);
}

.copy-cmd-prefix {
  margin-right: 8px;
  color: var(--vp-c-text-3);
}

.copy-cmd-icon {
  margin-left: 12px;
  color: var(--vp-c-text-2);
}
</style>
