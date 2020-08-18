<template>
  <div
    ref="container"
    class="d-flex flex-row"
    :style="[defaultStyle, computedStyle]"
  >
    <ValueWidget :parameters="parameters" />
    <LimitsbarWidget :parameters="limitsBarParameters" />
  </div>
</template>

<script>
import ValueWidget from './ValueWidget.vue'
import LimitsbarWidget from './LimitsbarWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    ValueWidget,
    LimitsbarWidget
  },
  computed: {
    limitsBarParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        'CONVERTED'
      ]
    },
    defaultStyle() {
      return {
        width: '300px'
      }
    }
  }
}
</script>
