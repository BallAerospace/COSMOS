<!--
# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
-->

<template>
  <div ref="container" class="d-flex flex-row">
    <div class="led align-self-center" :style="[cssProps, computedStyle]"></div>
    <label-widget
      :parameters="labelName"
      :settings="settings"
      :style="computedStyle"
      :widget-index="1"
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
      const value = this.$store.state.tlmViewerValues[this.valueId][0]
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
