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
  <v-container>
    <packet-summary-component
      :key="packet.time"
      :packet="packet"
      :received-count="history.length"
    />
    <v-radio-group v-model="format" row hide-details>
      <v-radio label="Hex" value="hex" />
      <v-radio label="ASCII" value="ascii" />
    </v-radio-group>
    <v-textarea :value="hexText" auto-grow readonly filled />
  </v-container>
</template>

<script>
import _ from 'lodash'
import PacketSummaryComponent from './PacketSummaryComponent'

export default {
  props: {
    packet: {
      type: Object,
      required: true,
    },
    columns: {
      type: Number,
      default: 16,
    },
  },
  data: function () {
    return {
      history: [],
      format: 'hex',
    }
  },
  watch: {
    packet: function (val) {
      this.history.push(val)
    },
  },
  computed: {
    hexBytes: function () {
      if (this.format === 'ascii') {
        return this.packet.raw.map((byte) =>
          String.fromCharCode(byte)
            .replace(/\n/, '\\n')
            .replace(/\r/, '\\r')
            .padStart(2, ' ')
        )
      } else {
        return this.packet.raw.map((byte) => byte.toString(16).padStart(2, '0'))
      }
    },
    hexLines: function () {
      return _.chunk(this.hexBytes, this.columns).map((chunk, index) => {
        const lineNumber = (index * this.columns).toString(16).padStart(8, '0')
        return `${lineNumber}: ${chunk.join(' ')}`
      })
    },
    hexText: function () {
      return this.hexLines.join('\n')
    },
  },
}
</script>

<style lang="scss" scoped>
.v-textarea {
  font-family: 'Courier New', Courier, monospace;
}
</style>
