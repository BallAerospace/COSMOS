<template>
  <span
    data-test="label"
    class="pa-1 mt-1 label"
    :style="[cssProps, computedStyle]"
    >{{ labelText }}</span
  >
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  data() {
    return {
      fontFamily: null,
      fontSize: null,
      fontWeight: 'normal',
      fontStyle: 'normal',
    }
  },
  computed: {
    labelText() {
      return this.parameters[0]
    },
    cssProps() {
      var size = null
      if (this.fontSize) {
        size = this.fontSize + 'px'
      }
      return {
        '--font-family': this.fontFamily,
        '--font-size': size,
        '--font-weight': this.fontWeight,
        '--font-style': this.fontStyle,
      }
    },
  },
  created() {
    if (this.parameters[1]) {
      this.fontFamily = this.parameters[1]
    }
    if (this.parameters[2]) {
      this.fontSize = this.parameters[2]
    }
    if (this.parameters[3]) {
      this.fontWeight = this.parameters[3]
    }
    if (this.parameters[4]) {
      this.fontStyle = this.parameters[4]
    }
  },
}
</script>

<style scoped>
.label {
  font-family: var(--font-family);
  font-size: var(--font-size);
  font-weight: var(--font-weight);
  font-style: var(--font-style);
}
</style>
