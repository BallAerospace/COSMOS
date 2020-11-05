<template>
  <svg id="canvas" :width="width" :height="height">
    <component
      v-for="(widget, index) in widgets"
      :key="index"
      :is="widget.type"
      :parameters="widget.parameters"
      :settings="widget.settings"
      :widgets="widget.widgets"
    ></component>
  </svg>
</template>

<script>
import Layout from './Layout'
export default {
  mixins: [Layout],
  computed: {
    width() {
      return this.parameters[0] + 'px'
    },
    height() {
      return this.parameters[1] + 'px'
    },
  },
}
</script>

<style lang="scss" scoped>
svg {
  background-color: white;
}
</style>
