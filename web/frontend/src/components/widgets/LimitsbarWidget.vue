<template>
  <div class="limitsbar" :style="[cssProps, computedStyle]">
    <div class="limitsbar__container">
      <div class="limitsbar__redlow" />
      <div class="limitsbar__redhigh" />
      <div class="limitsbar__yellowlow" />
      <div class="limitsbar__yellowhigh" />
      <div class="limitsbar__greenlow" />
      <div class="limitsbar__greenhigh" />
      <div class="limitsbar__blue" />

      <div class="limitsbar__line" />
      <div class="limitsbar__arrow" />
    </div>
  </div>
</template>

<script>
import Widget from './Widget'
import { CosmosApi } from '@/services/cosmos-api.js'

export default {
  mixins: [Widget],
  data() {
    return {
      width: '100%', // users will override with px
      height: 20, // px
      redLow: 0,
      yellowLow: 0,
      greenLow: 0,
      greenHigh: 0,
      yellowHigh: 0,
      redHigh: 0,
      blue: 0,
      api: null,
      limitsSettings: {
        DEFAULT: []
      }
    }
  },
  computed: {
    cssProps() {
      const value = this.$store.state.tlmViewerValues[0][this.valueId]
      // TODO: Pass the current limits set
      this.calcLimits(this.limitsSettings.DEFAULT)
      return {
        '--height': this.height + 'px',
        '--width': this.width,
        '--container-height': this.height - 5 + 'px',
        '--position':
          // TODO: Pass the current limits set
          this.calcPosition(value, this.limitsSettings.DEFAULT) + '%',
        '--redlow-width': this.redLow + '%',
        '--redhigh-width': this.redHigh + '%',
        '--yellowlow-width': this.yellowLow + '%',
        '--yellowhigh-width': this.yellowHigh + '%',
        '--greenlow-width': this.greenLow + '%',
        '--greenhigh-width': this.greenHigh + '%',
        '--blue-width': this.blue + '%'
      }
    }
  },
  async created() {
    this.api = new CosmosApi()
    this.api
      .get_limits(this.parameters[0], this.parameters[1], this.parameters[2])
      .then(data => {
        this.limitsSettings = data
      })

    let type = 'CONVERTED'
    if (this.parameters[3]) {
      type = this.parameters[3]
    }
    this.valueId = await this.$store.dispatch('tlmViewerAddItem', {
      target: this.parameters[0],
      packet: this.parameters[1],
      item: this.parameters[2],
      type: type
    })
  },
  methods: {
    calcPosition(value, limitsSettings) {
      if (!value || !limitsSettings) {
        return
      }
      let divisor = 0.8
      if (limitsSettings[0] === limitsSettings[1]) {
        divisor += 0.1
      }
      if (limitsSettings[2] === limitsSettings[3]) {
        divisor += 0.1
      }
      const scale = (limitsSettings[3] - limitsSettings[0]) / divisor
      const lowValue = limitsSettings[0] - 0.1 * scale
      const highValue = limitsSettings[3] - 0.1 * scale

      if (value.raw) {
        if (value.raw === '-Infinity') {
          return 0
        } else {
          // NaN and Infinity
          return 100
        }
      }
      if (value < this.min) {
        return 0
      } else if (value > this.max) {
        return 100
      } else {
        const result = parseInt(((value - lowValue) / scale) * 100.0)
        if (result > 100) {
          return 100
        } else if (result < 0) {
          return 0
        } else {
          return result
        }
      }
    },
    calcLimits(limitsSettings) {
      if (!limitsSettings) {
        return
      }
      let scale = 80
      if (limitsSettings[0] === limitsSettings[1]) {
        this.redLow = 0
        scale += 10
      } else {
        this.redLow = 10
      }
      if (limitsSettings[2] === limitsSettings[3]) {
        this.redHigh = 0
        scale += 10
      } else {
        this.redHigh = 10
      }
      const range = 1.0 * (limitsSettings[3] - limitsSettings[0])
      this.yellowLow = Math.round(
        ((limitsSettings[1] - limitsSettings[0]) / range) * scale
      )
      this.yellowHigh = Math.round(
        ((limitsSettings[3] - limitsSettings[2]) / range) * scale
      )
      if (limitsSettings.length > 4) {
        this.greenLow = Math.round(
          ((limitsSettings[4] - limitsSettings[1]) / range) * scale
        )
        this.greenHigh = Math.round(
          ((limitsSettings[2] - limitsSettings[5]) / range) * scale
        )
        this.blue = Math.round(
          100 -
            this.redLow -
            this.yellowLow -
            this.greenLow -
            this.greenHigh -
            this.yellowHigh -
            this.redHigh
        )
      } else {
        this.greenLow = Math.round(
          100 - this.redLow - this.yellowLow - this.yellowHigh - this.redHigh
        )
        this.greenHigh = 0
        this.blue = 0
      }
    }
  }
}
</script>

<style lang="scss" scoped>
.limitsbar {
  cursor: default;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 5px;
  width: var(--width);
}
.limitsbar__container {
  position: relative;
  flex: 1;
  height: var(--container-height);
  border: 1px solid black;
  background-color: white;
}
.limitsbar__redlow {
  position: absolute;
  top: -1px;
  left: 0px;
  width: var(--redlow-width);
  height: var(--container-height);
  background-color: red;
}
.limitsbar__redhigh {
  position: absolute;
  top: -1px;
  right: 0px;
  width: var(--redhigh-width);
  height: var(--container-height);
  background-color: red;
}
.limitsbar__yellowlow {
  position: absolute;
  top: -1px;
  left: var(--redlow-width);
  width: var(--yellowlow-width);
  height: var(--container-height);
  background-color: rgb(255, 220, 0);
}
.limitsbar__yellowhigh {
  position: absolute;
  top: -1px;
  right: var(--redhigh-width);
  width: var(--yellowhigh-width);
  height: var(--container-height);
  background-color: rgb(255, 220, 0);
}
.limitsbar__greenlow {
  position: absolute;
  top: -1px;
  left: calc(var(--redlow-width) + var(--yellowlow-width));
  width: var(--greenlow-width);
  height: var(--container-height);
  background-color: green;
}
.limitsbar__greenhigh {
  position: absolute;
  top: -1px;
  right: calc(var(--redhigh-width) + var(--yellowhigh-width));
  width: var(--greenhigh-width);
  height: var(--container-height);
  background-color: green;
}
.limitsbar__blue {
  position: absolute;
  top: -1px;
  left: calc(
    var(--redlow-width) + var(--yellowlow-width) + var(--greenlow-width)
  );
  width: var(--blue-width);
  height: var(--container-height);
  background-color: blue;
}
.limitsbar__line {
  position: absolute;
  left: var(--position);
  width: 1px;
  height: var(--container-height);
  background-color: rgb(128, 128, 128);
}
$arrow-size: 5px;
.limitsbar__arrow {
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
