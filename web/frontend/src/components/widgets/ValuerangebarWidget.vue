<template>
  <div
    ref="container"
    class="d-flex flex-row"
    :style="[defaultStyle, computedStyle]"
  >
    <ValueWidget :parameters="valueParameters" />
    <RangebarWidget :parameters="parameters" />
  </div>
</template>

<script>
import ValueWidget from './ValueWidget.vue'
import RangebarWidget from './RangebarWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    ValueWidget,
    RangebarWidget,
  },
  computed: {
    valueParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        'WITH_UNITS',
      ]
    },
    defaultStyle() {
      return {
        width: '300px',
      }
    },
  },
}
</script>
