<template>
  <div>
    <v-banner single-line>{{ parameters.join(' ') }}</v-banner>
    <HorizontalWidget
      :parameters="parameters"
      :settings="settings"
      :widgets="widgets"
    />
  </div>
</template>

<script>
import HorizontalWidget from './HorizontalWidget'
import Layout from './Layout'
export default {
  mixins: [Layout],
  components: {
    HorizontalWidget,
  },
}
</script>

<style scoped>
.v-banner >>> div {
  background-color: var(--v-tertiary-darken2) !important;
}
</style>
