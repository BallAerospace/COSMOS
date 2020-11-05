<template>
  <div ref="container" class="d-flex flex-row">
    <div class="led align-self-center" :style="[cssProps, computedStyle]"></div>
    <LabelWidget
      :parameters="labelName"
      :settings="settings"
      :style="computedStyle"
      :widgetIndex="1"
    />
  </div>
</template>

<script>
import VWidget from './VWidget'
export default {
  mixins: [VWidget],
  data() {
    return {
      radius: 15,
      fullLabelDisplay: false,
    }
  },
  created() {
    if (this.parameters[4]) {
      this.radius = parseInt(this.parameters[4])
    }
    if (this.parameters[5] && this.parameters[5].toLowerCase() === 'true') {
      this.fullLabelDisplay = true
    }
  },
  computed: {
    labelName() {
      // LabelWidget uses index 0 from the parameters prop
      // so create an array with the label text in the first position
      if (this.fullLabelDisplay) {
        return [
          this.parameters[0] +
            ' ' +
            this.parameters[1] +
            ' ' +
            this.parameters[2],
        ]
      } else {
        return [this.parameters[2]]
      }
    },
    cssProps() {
      const value = this.$store.state.tlmViewerValues[0][this.valueId]
      return {
        '--height': this.radius + 'px',
        '--width': this.radius + 'px',
        '--color': this.limitsColor,
      }
    },
  },
  methods: {
    getType() {
      var type = 'CONVERTED'
      if (this.parameters[3]) {
        type = this.parameters[3]
      }
      return type
    },
  },
}
</script>

<style scoped>
.led {
  height: var(--height);
  width: var(--width);
  background-color: var(--color);
  border-radius: 50%;
}
</style>
