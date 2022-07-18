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
  <v-progress-linear height="25" :value="_value" :style="computedStyle">
    <strong>{{ Math.ceil(_value) }}%</strong>
  </v-progress-linear>
</template>

<script>
import Widget from './Widget'
import WidthSetter from './WidthSetter'

export default {
  mixins: [Widget, WidthSetter],
  props: {
    value: {
      default: null,
    },
  },
  data: function () {
    return {
      valueId: null,
      scaleFactor: 1.0,
      width: 80,
    }
  },
  computed: {
    _value: function () {
      let value = this.value
      if (value === null) {
        value = this.$store.state.tlmViewerValues[this.valueId][0]
      }
      return parseInt(parseFloat(value) * this.scaleFactor)
    },
  },
  created: function () {
    if (this.parameters[3]) {
      this.scaleFactor = parseFloat(this.parameters[3])
    }
    if (this.parameters[4]) {
      this.width = parseInt(this.parameters[4])
    }
    // If they're not passing us the value we have to register
    if (this.value === null) {
      var type = 'CONVERTED'
      if (this.parameters[5]) {
        type = this.parameters[5]
      }
      this.valueId = `${this.parameters[0]}__${this.parameters[1]}__${this.parameters[2]}__${type}`
      this.$store.commit('tlmViewerAddItem', this.valueId)
    }
  },
  destroyed: function () {
    this.$store.commit('tlmViewerDeleteItem', this.valueId)
  },
}
</script>
