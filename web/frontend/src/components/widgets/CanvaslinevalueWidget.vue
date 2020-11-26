<template>
  <line
    :x1="parameters[3]"
    :y1="parameters[4]"
    :x2="parameters[5]"
    :y2="parameters[6]"
    :style="calcStyle"
  />
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
  data() {
    return {
      valueId: 0,
    }
  },
  computed: {
    calcStyle() {
      let color = this.parameters[8]
      if (parseInt(this.$store.state.tlmViewerValues[this.valueId][0]) === 1) {
        color = this.parameters[7]
      }
      let width = 1
      if (this.parameters[9]) {
        width = this.parameters[9]
      }
      return 'stroke:' + color + ';stroke-width:' + width
    },
  },
  created() {
    this.valueId =
      this.parameters[0] +
      '__' +
      this.parameters[1] +
      '__' +
      this.parameters[2] +
      '__RAW'
    this.$store.commit('tlmViewerAddItem', this.valueId)
  },
  destroyed() {
    this.$store.commit('tlmViewerDeleteItem', this.valueId)
  },
}
</script>
