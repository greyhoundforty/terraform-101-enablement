<script setup lang="ts">
// Cover layout: text on the left, a solid Carbon Blue 60 panel on the right
// with a grid of Carbon icons that stand for the things Terraform manages.
</script>

<template>
  <div class="slidev-layout carbon-cover">
    <div class="cover-text">
      <slot />
    </div>
    <div class="cover-panel" aria-hidden="true">
      <carbon-cloud />
      <carbon-network-4 />
      <carbon-virtual-machine />
      <carbon-code />
      <carbon-renew />
      <carbon-data-base />
      <carbon-locked />
      <carbon-version />
      <carbon-checkmark-outline />
    </div>
  </div>
</template>

<style scoped>
.carbon-cover {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 270px;
  gap: 0;
  padding: 0;
  height: 100%;
}
.cover-text {
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-width: 0;
  padding: 48px 56px 48px 64px;
}
.cover-text :deep(h1) {
  margin: 0 0 14px;
  font-size: 50px;
  line-height: 1.08;
  font-weight: 300;
}
.cover-text :deep(.cover-sub) {
  max-width: 30ch;
  font-size: 22px;
  color: var(--cds-text-2);
}
.cover-text :deep(.presenter) {
  margin: 36px 0 0;
  font-size: 16px;
  color: var(--cds-text-2);
}
.cover-panel {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-auto-rows: 1fr;
  align-items: center;
  justify-items: center;
  background: var(--cds-blue);
  color: #ffffff;
  font-size: 40px;
}
.cover-panel > * { opacity: 0.92; }
</style>
