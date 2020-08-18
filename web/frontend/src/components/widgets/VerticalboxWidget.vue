<template>
  <div>
    <v-banner single-line>{{ parameters.join(' ') }}</v-banner>
    <VerticalWidget
      :parameters="parameters"
      :settings="settings"
      :widgets="widgets"
    />
  </div>
</template>

<script>
import VerticalWidget from './VerticalWidget'
import Layout from './Layout'
export default {
  mixins: [Layout],
  components: {
    VerticalWidget
  }
}
</script>

<style scoped>
.v-banner >>> div {
  background-color: var(--v-tertiary-darken2) !important;
}
</style>
