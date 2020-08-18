<template>
  <div class="rangebar" :style="[cssProps, computedStyle]">
    <div class="rangebar__container">
      <div class="rangebar__line" />
      <div class="rangebar__arrow" />
    </div>
  </div>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  data() {
    return {
      width: '100%', // users will override with px
      height: 20 // px
    }
  },
  computed: {
    cssProps() {
      return {
        '--height': this.height + 'px',
        '--width': this.width,
        '--container-height': this.height - 5 + 'px',
        '--position': this.calcPosition() + '%'
      }
    },
    min() {
      return parseInt(this.parameters[3])
    },
    max() {
      return parseInt(this.parameters[4])
    },
    range() {
      return this.max - this.min
    }
  },
  async created() {
    const type = this.parameters[5] ? this.parameters[5] : 'CONVERTED'
    this.valueId = await this.$store.dispatch('tlmViewerAddItem', {
      target: this.parameters[0],
      packet: this.parameters[1],
      item: this.parameters[2],
      type: type
    })
    if (this.parameters[6]) {
      // Width by default is 100% so add the px designator
      this.width = parseInt(this.parameters[6]) + 'px'
    }
    if (this.parameters[7]) {
      // Height by default is a number
      this.height = parseInt(this.parameters[7])
    }
  },
  methods: {
    calcPosition() {
      const value = this.$store.state.tlmViewerValues[0][this.valueId]
      if (!value) {
        return 0
      }
      if (value.raw) {
        if (value.raw === '-Infinity') {
          return 0
        } else {
          // NaN and Infinity
          return 100
        }
      }
      const result = ((value - this.min) / this.range) * 100
      if (result > 100) {
        return 100
      } else if (result < 0) {
        return 0
      } else {
        return result
      }
    }
  }
}
</script>

<style lang="scss" scoped>
.rangebar {
  cursor: default;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 5px;
  width: var(--width);
}
.rangebar__container {
  position: relative;
  flex: 1;
  height: var(--container-height);
  border: 1px solid black;
  background-color: white;
}
.rangebar__line {
  position: absolute;
  left: var(--position);
  width: 1px;
  height: var(--container-height);
  background-color: rgb(128, 128, 128);
}
$arrow-size: 5px;
.rangebar__arrow {
  position: absolute;
  top: -$arrow-size;
  left: var(--position);
  width: 0;
  height: 0;
  transform: translateX(-$arrow-size); // Transform so it sits over the line
  border-left: $arrow-size solid transparent;
  border-right: $arrow-size solid transparent;
  border-top: $arrow-size solid rgb(128, 128, 128);
}
</style>
