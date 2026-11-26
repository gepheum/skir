<script setup lang="ts">
import { ref } from 'vue'

defineProps<{
  src: string
  maxWidth?: string
}>()

const videoRef = ref<HTMLVideoElement | null>(null)
const isPlaying = ref(false)

function onMouseEnter() {
  if (videoRef.current || videoRef.value) {
    const v = videoRef.value
    if (!v) return
    const p = v.play()
    if (p !== undefined) {
      p.then(() => {
        isPlaying.value = true
      }).catch(() => {})
    }
  }
}

function onMouseLeave() {
  const v = videoRef.value
  if (!v) return
  v.pause()
  v.currentTime = 0
  isPlaying.value = false
}
</script>

<template>
  <div
    class="hover-video-card"
    :style="maxWidth ? { maxWidth } : undefined"
    @mouseenter="onMouseEnter"
    @mouseleave="onMouseLeave"
  >
    <video
      ref="videoRef"
      muted
      loop
      playsinline
      controls
      controlslist="nofullscreen nodownload noremoteplayback"
      disablepictureinpicture
      class="hover-video-el"
    >
      <source :src="src" type="video/mp4" />
    </video>
  </div>
</template>

<style scoped>
.hover-video-card {
  margin: 1.25rem auto;
  max-width: 780px;
  border-radius: 12px;
  border: 1px solid var(--vp-c-divider);
  background: #000;
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.18);
  overflow: hidden;
}

.hover-video-el {
  width: 100%;
  height: auto;
  display: block;
}
</style>
