<script setup lang="ts">
// Shows the whole series as four stages and marks where we are.
//   active = index of the current stage (0 Terraform, 1 Schematics, ...)
// Stages before `active` are drawn as "done", the active one in Carbon blue.
defineProps<{ active: number }>()

const stages = ['Terraform', 'Schematics', 'Deployable Architectures', 'Projects']
</script>

<template>
  <ol class="pipeline">
    <li
      v-for="(stage, i) in stages"
      :key="stage"
      :class="{ on: i === active, done: i < active }"
    >
      <span class="idx">{{ i + 1 }}</span>
      <span class="name">{{ stage }}</span>
    </li>
  </ol>
</template>

<style scoped>
.pipeline {
  display: flex;
  gap: 4px;
  margin: 28px 0 0;
  padding: 0;
  list-style: none;
}
.pipeline li {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 1 1 0;
  min-width: 0;
  margin: 0;
  padding: 10px 14px 12px;
  background: var(--cds-layer);
  color: var(--cds-text-2);
  font-size: 15px;
  line-height: 1.25;
}
.pipeline .idx {
  font-family: var(--font-plex-mono);
  font-size: 12px;
}
.pipeline .name { font-weight: 600; }
.pipeline li.on {
  background: var(--cds-blue);
  color: #ffffff;
}
.pipeline li.done {
  background: var(--cds-blue-tint);
  color: var(--cds-blue-text);
}
</style>
