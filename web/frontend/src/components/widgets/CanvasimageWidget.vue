<template>
  <image
    :href="calcHref"
    :x="parameters[1]"
    :y="parameters[2]"
    :width="calcWidth"
    :height="calcHeight"
  />
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
  computed: {
    calcHref() {
      if (this.parameters[0].includes('http')) {
        return this.parameters[0]
      } else {
        return 'img/' + this.parameters[0]
      }
    },
    calcWidth() {
      if (this.parameters[3]) {
        return this.parameters[3] + 'px'
      }
      return '100%'
    },
    calcHeight() {
      if (this.parameters[4]) {
        return this.parameters[4] + 'px'
      }
      return '100%'
    },
  },
}
</script>
