<script setup lang="ts">
// Footer shown on every slide except the cover.
// $slidev.nav gives us the current page number and layout name.
</script>

<template>
  <div v-if="$slidev.nav.currentLayout !== 'carbon-cover'" class="deck-footer">
    <span>IaC on IBM Cloud · Session 1</span>
    <span>{{ $slidev.nav.currentPage }}</span>
  </div>
</template>
