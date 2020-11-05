<template>
  <text :x="parameters[0]" :y="parameters[1]" :fill="fillColor">{{
    parameters[2]
  }}</text>
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
  computed: {
    fillColor() {
      if (this.parameters[3]) {
        return this.parameters[3]
      }
      return 'black'
    },
  },
}
</script>
