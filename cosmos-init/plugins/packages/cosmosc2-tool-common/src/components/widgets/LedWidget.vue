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
  <div class="led mt-2" :style="[cssProps, computedStyle]"></div>
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
  data() {
    return {
      valueId: null,
      colors: {
        TRUE: 'green',
        FALSE: 'red',
      },
    }
  },
  computed: {
    width() {
      return this.parameters[4] ? parseInt(this.parameters[4]) : 20
    },
    height() {
      return this.parameters[5] ? parseInt(this.parameters[5]) : 20
    },
    cssProps() {
      const value = this.$store.state.tlmViewerValues[this.valueId][0]
      let color = this.colors[value]
      if (!color) {
        color = this.colors.ANY
      }
      if (!color) {
        color = 'BLACK'
      }
      return {
        '--height': this.height + 'px',
        '--width': this.width + 'px',
        '--color': color.toLowerCase(),
      }
    },
  },
  // Note Vuejs still treats this syncronously, but this allows us to dispatch
  // the store mutation and return the array index.
  // What this means practically is that future lifecycle hooks may not have valueId set.
  created() {
    this.settings.forEach((setting) => {
      switch (setting[0]) {
        case 'LED_COLOR':
          this.colors[setting[1]] = setting[2]
          break
      }
    })
    if (!this.parameters[3]) {
      this.parameters[3] = 'CONVERTED'
    }
    this.valueId = `${this.parameters[0]}__${this.parameters[1]}__${this.parameters[2]}__${this.parameters[3]}`
    this.$store.commit('tlmViewerAddItem', this.valueId)
  },
  destroyed() {
    this.$store.commit('tlmViewerDeleteItem', this.valueId)
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
