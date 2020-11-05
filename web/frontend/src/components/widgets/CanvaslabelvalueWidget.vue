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
      return this.$store.state.tlmViewerValues[0][this.valueId]
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
  // Note Vuejs still treats this syncronously, but this allows us to dispatch
  // the store mutation and return the array index.
  // What this means practically is that future lifecycle hooks may not have valueId set.
  async created() {
    this.valueId = await this.$store.dispatch('tlmViewerAddItem', {
      target: this.parameters[0],
      packet: this.parameters[1],
      item: this.parameters[2],
      type: 'CONVERTED',
    })
  },
}
</script>
