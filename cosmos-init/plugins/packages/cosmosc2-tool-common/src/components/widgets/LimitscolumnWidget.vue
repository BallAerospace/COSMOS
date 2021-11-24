<!--
# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

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
import { CosmosApi } from '../../services/cosmos-api.js'

export default {
  mixins: [Widget],
  data() {
    return {
      width: 20, // px
      height: 100, // users will override with px
      redLow: 0,
      yellowLow: 0,
      greenLow: 0,
      greenHigh: 0,
      yellowHigh: 0,
      redHigh: 0,
      blue: 0,
      api: null,
      limitsSettings: {
        DEFAULT: [],
      },
    }
  },
  computed: {
    cssProps() {
      const value = this.$store.state.tlmViewerValues[this.valueId][0]
      // TODO: Pass the current limits set
      this.calcLimits(this.limitsSettings.DEFAULT)
      return {
        '--height': this.height + 'px',
        '--width': this.width + 'px',
        '--container-width': this.width - 5 + 'px',
        '--position':
          // TODO: Pass the current limits set
          this.calcPosition(value, this.limitsSettings.DEFAULT) + '%',
        '--redlow-height': this.redLow + '%',
        '--redhigh-height': this.redHigh + '%',
        '--yellowlow-height': this.yellowLow + '%',
        '--yellowhigh-height': this.yellowHigh + '%',
        '--greenlow-height': this.greenLow + '%',
        '--greenhigh-height': this.greenHigh + '%',
        '--blue-height': this.blue + '%',
      }
    },
  },
  created() {
    this.api = new CosmosApi()
    this.api
      .get_limits(this.parameters[0], this.parameters[1], this.parameters[2])
      .then((data) => {
        this.limitsSettings = data
      })

    let type = 'CONVERTED'
    if (this.parameters[3]) {
      type = this.parameters[3]
    }
    this.valueId = `${this.parameters[0]}__${this.parameters[1]}__${this.parameters[2]}__${type}`

    this.$store.commit('tlmViewerAddItem', this.valueId)
  },
  destroyed() {
    this.$store.commit('tlmViewerDeleteItem', this.valueId)
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
    },
  },
}
</script>

<style lang="scss" scoped>
.limitsbar {
  cursor: default;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 5px;
  height: var(--height);
}
.limitsbar__container {
  position: relative;
  flex: 1 1 100%;
  width: var(--container-width);
  border: 1px solid black;
  background-color: white;
}
.limitsbar__redlow {
  position: absolute;
  bottom: 0px;
  width: var(--container-width);
  height: var(--redlow-height);
  background-color: red;
}
.limitsbar__redhigh {
  position: absolute;
  top: 0px;
  width: var(--container-width);
  height: var(--redhigh-height);
  background-color: red;
}
.limitsbar__yellowlow {
  position: absolute;
  bottom: var(--redlow-height);
  height: var(--yellowlow-height);
  width: var(--container-width);
  background-color: rgb(255, 220, 0);
}
.limitsbar__yellowhigh {
  position: absolute;
  top: var(--redhigh-height);
  height: var(--yellowhigh-height);
  width: var(--container-width);
  background-color: rgb(255, 220, 0);
}
.limitsbar__greenlow {
  position: absolute;
  bottom: calc(var(--redlow-height) + var(--yellowlow-height));
  width: var(--container-width);
  height: var(--greenlow-height);
  background-color: green;
}
.limitsbar__greenhigh {
  position: absolute;
  top: calc(var(--redhigh-height) + var(--yellowhigh-height));
  width: var(--container-width);
  height: var(--greenhigh-height);
  background-color: green;
}
.limitsbar__blue {
  position: absolute;
  bottom: calc(
    var(--redlow-height) + var(--yellowlow-height) + var(--greenlow-height)
  );
  width: var(--container-width);
  height: var(--blue-height);
  background-color: blue;
}
.limitsbar__line {
  position: absolute;
  bottom: var(--position);
  width: var(--container-width);
  height: 1px;
  background-color: rgb(128, 128, 128);
}
$arrow-size: 5px;
.limitsbar__arrow {
  position: absolute;
  bottom: var(--position);
  left: var(--container-width);
  width: 0;
  height: 0;
  transform: translateY($arrow-size); // Transform so it sits over the line
  border-top: $arrow-size solid transparent;
  border-bottom: $arrow-size solid transparent;
  border-right: $arrow-size solid rgb(128, 128, 128);
}
</style>
