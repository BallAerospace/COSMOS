<template>
  <div
    ref="container"
    class="d-flex flex-row"
    :style="[defaultStyle, computedStyle]"
  >
    <LabelvalueWidget :parameters="labelValueParameters" />
    <RangebarWidget :parameters="rangebarParameters" />
  </div>
</template>

<script>
import LabelvalueWidget from './LabelvalueWidget.vue'
import RangebarWidget from './RangebarWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    LabelvalueWidget,
    RangebarWidget
  },
  computed: {
    labelValueParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        'WITH_UNITS'
      ]
    },
    rangebarParameters() {
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
