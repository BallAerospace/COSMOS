<template>
  <line
    :x1="parameters[0]"
    :y1="parameters[1]"
    :x2="parameters[2]"
    :y2="parameters[3]"
    :style="calcStyle"
  />
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
  computed: {
    calcStyle() {
      let color = 'black'
      if (this.parameters[4]) {
        color = this.parameters[4]
      }
      let width = 1
      if (this.parameters[5]) {
        width = this.parameters[5]
      }
      return 'stroke:' + color + ';stroke-width:' + width
    },
  },
}
</script>
