<template>
  <v-progress-linear height="25" :value="_value" :style="computedStyle">
    <strong>{{ Math.ceil(_value) }}%</strong>
  </v-progress-linear>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  props: {
    value: {
      default: null,
    },
  },
  data() {
    return {
      valueId: null,
      scaleFactor: 1.0,
      width: 80,
    }
  },
  computed: {
    _value: function () {
      let value = this.value
      if (value === null) {
        value = this.$store.state.tlmViewerValues[this.valueId][0]
      }
      return parseInt(parseFloat(value) * this.scaleFactor)
    },
  },
  created() {
    if (this.parameters[3]) {
      this.scaleFactor = parseFloat(this.parameters[3])
    }
    if (this.parameters[4]) {
      this.width = parseInt(this.parameters[4])
    }
    this.settings.unshift(['WIDTH', this.width])
    // If they're not passing us the value we have to register
    if (this.value === null) {
      var type = 'CONVERTED'
      if (this.parameters[5]) {
        type = this.parameters[5]
      }
      this.valueId =
        this.parameters[0] +
        '__' +
        this.parameters[1] +
        '__' +
        this.parameters[2] +
        '__' +
        type
      this.$store.commit('tlmViewerAddItem', this.valueId)
    }
  },
  destroyed() {
    this.$store.commit('tlmViewerDeleteItem', this.valueId)
  },
}
</script>

<style lang="scss" scoped></style>
