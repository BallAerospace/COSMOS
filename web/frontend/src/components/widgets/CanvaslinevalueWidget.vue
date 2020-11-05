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
      if (parseInt(this.$store.state.tlmViewerValues[0][this.valueId]) === 1) {
        color = this.parameters[7]
      }
      let width = 1
      if (this.parameters[9]) {
        width = this.parameters[9]
      }
      return 'stroke:' + color + ';stroke-width:' + width
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
      type: 'RAW',
    })
  },
}
</script>
