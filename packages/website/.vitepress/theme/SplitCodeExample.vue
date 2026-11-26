<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue'

const props = withDefaults(
  defineProps<{
    defaultTab?: string
  }>(),
  {
    defaultTab: 'Kotlin',
  },
)

const rootRef = ref<HTMLElement | null>(null)

onMounted(() => {
  const root = rootRef.value
  if (!root) return

  const tabsEl = root.querySelector<HTMLElement>('.vp-code-group .tabs')
  const labels = Array.from(root.querySelectorAll<HTMLLabelElement>('.vp-code-group .tabs label'))
  const inputs = Array.from(root.querySelectorAll<HTMLInputElement>('.vp-code-group .tabs input'))
  const blocks = Array.from(root.querySelectorAll<HTMLElement>('.vp-code-group .blocks > div'))

  const targetIndex = labels.findIndex((label) => label.textContent?.trim() === props.defaultTab)

  if (targetIndex !== -1) {
    inputs.forEach((input, idx) => {
      input.checked = idx === targetIndex
    })
    blocks.forEach((block, idx) => {
      block.classList.toggle('active', idx === targetIndex)
    })

    const targetLabel = labels[targetIndex]
    if (tabsEl && targetLabel) {
      const centerTargetTab = () => {
        const targetLeft =
          targetLabel.offsetLeft - tabsEl.clientWidth / 2 + targetLabel.clientWidth / 2
        tabsEl.scrollLeft = Math.max(0, targetLeft)
      }
      centerTargetTab()
      nextTick(centerTargetTab)
      requestAnimationFrame(centerTargetTab)
    }
  }
})
</script>

<template>
  <div ref="rootRef" class="split-showcase vp-doc">
    <div class="split-pane split-pane-left">
      <slot name="left" />
    </div>
    <div class="split-pane split-pane-right">
      <slot name="right" />
    </div>
  </div>
</template>

<style scoped>
.split-showcase {
  display: grid;
  grid-template-columns: 1fr;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  overflow: hidden;
  background-color: var(--vp-code-block-bg);
  margin: 1.5rem 0;
  text-align: left;
}

@media (min-width: 860px) {
  .split-showcase {
    grid-template-columns: 42% 58%;
    height: 540px;
  }
}

.split-pane {
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
  height: 100%;
}

.split-pane-left {
  border-bottom: 1px solid var(--vp-c-divider);
}

@media (min-width: 860px) {
  .split-pane-left {
    border-bottom: none;
    border-right: 1px solid var(--vp-c-divider);
  }
}

/* Hide the redundant top-right language label and copy button inside the split showcase */
.split-pane :deep(span.lang),
.split-pane :deep(button.copy) {
  display: none !important;
}

/* Make VitePress code blocks and code-groups fill their pane cleanly */
.split-pane :deep(.vp-code-group),
.split-pane :deep(div[class*='language-']) {
  margin: 0 !important;
  border-radius: 0 !important;
  background-color: transparent !important;
}

.split-pane-left :deep(div[class*='language-']) {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.split-pane-left :deep(div[class*='language-']::before) {
  content: attr(data-title);
  display: flex;
  align-items: center;
  height: 46px;
  padding: 0 20px;
  font-size: 14px;
  font-weight: 500;
  color: var(--vp-c-brand-1);
  border-bottom: 1px solid var(--vp-c-divider);
  background-color: var(--vp-code-tab-bg);
  flex-shrink: 0;
}

.split-pane-left :deep(pre),
.split-pane-right :deep(pre) {
  flex: 1;
  overflow: auto;
  margin: 0 !important;
  padding: 20px 24px !important;
}

.split-pane-left :deep(pre code),
.split-pane-right :deep(pre code) {
  padding: 0 !important;
  font-size: 13.5px;
  line-height: 1.6;
}

.split-pane-right :deep(.vp-code-group) {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.split-pane-right :deep(.tabs) {
  margin: 0 !important;
  border-radius: 0 !important;
  padding: 0 !important;
  height: 46px;
  display: flex;
  align-items: stretch;
  border-bottom: 1px solid var(--vp-c-divider);
  background-color: var(--vp-code-tab-bg);
  overflow-x: auto;
  overflow-y: hidden;
  flex-shrink: 0;
  box-shadow: none !important;
  scrollbar-width: thin;
  scrollbar-color: rgba(128, 128, 128, 0.45) transparent;
}

.split-pane-right :deep(.tabs::-webkit-scrollbar) {
  height: 2px;
}

.split-pane-right :deep(.tabs::-webkit-scrollbar-track) {
  background: transparent;
}

.split-pane-right :deep(.tabs::-webkit-scrollbar-thumb) {
  background-color: rgba(128, 128, 128, 0.45);
  border-radius: 9999px;
}

.split-pane-right :deep(.tabs::-webkit-scrollbar-thumb:hover) {
  background-color: rgba(128, 128, 128, 0.75);
}

.split-pane-right :deep(.tabs label) {
  display: inline-flex;
  align-items: center;
  height: 100%;
  line-height: 1;
  padding: 0 16px;
  border-bottom: none !important;
  white-space: nowrap;
  font-size: 14px;
  font-weight: 500;
  color: var(--vp-c-text-2);
  transition:
    color 0.2s,
    background-color 0.2s,
    box-shadow 0.2s;
}

.split-pane-right :deep(.tabs label::after) {
  display: none !important;
}

.split-pane-right :deep(.tabs label:hover) {
  color: var(--vp-c-text-1);
  background-color: var(--vp-c-brand-soft);
}

.split-pane-right :deep(.tabs input:checked + label) {
  color: var(--vp-c-brand-1);
  background-color: var(--vp-code-block-bg);
  box-shadow: inset 0 -2px 0 var(--vp-c-brand-1);
}

.split-pane-right :deep(.blocks) {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.split-pane-right :deep(.blocks > div[class*='language-']) {
  display: none;
}

.split-pane-right :deep(.blocks > div[class*='language-'].active) {
  flex: 1;
  display: flex !important;
  flex-direction: column;
  min-height: 0;
}
</style>
