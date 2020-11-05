<template>
  <div ref="container" class="d-flex flex-row" :style="computedStyle">
    <ValueWidget
      :parameters="getParameters"
      :settings="settings"
      :formatString="parameters[3]"
    />
  </div>
</template>

<script>
import Widget from './Widget'
import ValueWidget from './ValueWidget.vue'

export default {
  mixins: [Widget],
  components: {
    ValueWidget,
  },
  computed: {
    getParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        this.parameters[4],
      ]
    },
  },
}
</script>
