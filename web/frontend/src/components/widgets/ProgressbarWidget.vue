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
        value = this.$store.state.tlmViewerValues[0][this.valueId]
      }
      return parseInt(parseFloat(value) * this.scaleFactor)
    },
  },
  // Note Vuejs still treats this syncronously, but this allows us to dispatch
  // the store mutation and return the array index.
  // What this means practically is that future lifecycle hooks may not have valueId set.
  async created() {
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
      this.valueId = await this.$store.dispatch('tlmViewerAddItem', {
        target: this.parameters[0],
        packet: this.parameters[1],
        item: this.parameters[2],
        type: type,
      })
    }
  },
}
</script>

<style lang="scss" scoped></style>
