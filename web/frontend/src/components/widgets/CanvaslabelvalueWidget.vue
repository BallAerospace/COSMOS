<template>
  <!-- TODO: Draw box or underline? -->
  <text
    :x="parameters[3]"
    :y="parameters[4]"
    :font-size="fontSize"
    :fill="fillColor"
    >{{ _value }}</text
  >
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
  data() {
    return {
      valueId: null,
    }
  },
  computed: {
    _value() {
      return this.$store.state.tlmViewerValues[this.valueId][0]
    },
    fontSize() {
      if (this.parameters[5]) {
        return this.parameters[5] + 'px'
      }
      return '14px'
    },
    fillColor() {
      if (this.parameters[6]) {
        return this.parameters[6]
      }
      return 'black'
    },
  },
  created() {
    this.valueId =
      this.parameters[0] +
      '__' +
      this.parameters[1] +
      '__' +
      this.parameters[2] +
      '__CONVERTED'
    this.$store.commit('tlmViewerAddItem', this.valueId)
  },
  destroyed() {
    this.$store.commit('tlmViewerDeleteItem', this.valueId)
  },
}
</script>
