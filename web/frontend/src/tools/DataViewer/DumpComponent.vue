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
    <v-row>
      <v-col>
        <packet-summary-component
          v-if="latestPacket"
          :key="latestPacket.time"
          :packet="latestPacket"
          :received-count="receivedCount"
        />
      </v-col>
    </v-row>
    <v-row>
      <v-col>
        <v-radio-group v-model="format" row hide-details>
          <v-radio label="Hex" value="hex" />
          <v-radio label="ASCII" value="ascii" />
        </v-radio-group>
      </v-col>
      <v-col>
        <v-switch v-model="showLineAddress" label="Show line address" />
      </v-col>
      <v-col>
        <v-text-field
          v-model="bytesPerLine"
          label="Bytes per line"
          type="number"
        ></v-text-field>
      </v-col>
      <v-col>
        <v-radio-group v-model="showAllPackets" label="Packets to show">
          <v-radio label="All" :value="true" />
          <v-radio :value="false">
            <template v-slot:label>
              <v-text-field
                v-model="packetsToShow"
                type="number"
                dense
              ></v-text-field>
            </template>
          </v-radio>
        </v-radio-group>
      </v-col>
    </v-row>
    <v-row>
      <v-col>
        <v-slider
          v-model="playPosition"
          v-on:mousedown="pause"
          @click:prepend="stepBackward"
          @click:append="stepForward"
          prepend-icon="mdi-step-backward"
          append-icon="mdi-step-forward"
          :min="0"
          :max="historyMax"
        />
      </v-col>
    </v-row>
    <v-row>
      <v-col class="pl-0 pr-0">
        <div class="text-area-container">
          <v-textarea
            ref="textarea"
            :value="displayText"
            :auto-grow="(!showAllPackets && packetsToShow == 1) || history.length == 1"
            readonly
            solo
            flat
          />
          <v-btn
            class="play-control"
            :class="{ pulse: paused }"
            v-on:click="togglePlayPause"
            color="primary"
            fab
          >
            <v-icon large v-if="paused">mdi-play</v-icon>
            <v-icon large v-else>mdi-pause</v-icon>
          </v-btn>
        </div>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import _ from 'lodash'
import PacketSummaryComponent from './PacketSummaryComponent'

export default {
  components: {
    PacketSummaryComponent,
  },
  data: function () {
    return {
      history: [],
      receivedCount: 0,
      format: 'hex',
      showLineAddress: true,
      bytesPerLine: 16,
      showAllPackets: true,
      packetsToShow: 1,
      paused: false,
      pausedAt: 0,
      playPosition: 0,
      textarea: null,
    }
  },
  watch: {
    paused: function (val) {
      if (val) {
        this.pausedAt = this.playPosition
      } else {
        this.playPosition = this.history.length - 1
      }
    },
  },
  mounted: function () {
    this.textarea = this.$refs.textarea.$el.querySelectorAll('textarea')[0]
  },
  methods: {
    receive: function (data) {
      // This is called by the parent to feed this component data. A function is used instead
      // of a prop to ensure each message gets handled, regardless of how fast they come in
      data.forEach((packet) => {
        this.history.push({
          buffer: atob(packet.buffer)
            .split('')
            .map((c) => c.charCodeAt(0)),
          time: packet.time,
        })
      })
      this.receivedCount += data.length
      // Future enhancement: use a ring buffer instead
      if (this.history.length > 1000) {
        this.history = this.history.slice(-1000)
      }
      if (!this.paused) {
        this.playPosition = this.history.length - 1
        this.updateScrollPosition()
      }
    },
    updateScrollPosition: function () {
      // Alternatively, only set if it's at the bottom already?
      const currentScrollOffset = this.textarea.scrollTop - this.textarea.scrollHeight
      this.$nextTick(() => {
        this.textarea.scrollTop = this.textarea.scrollHeight + currentScrollOffset
      })
    },
    pause: function () {
      this.paused = true
    },
    togglePlayPause: function () {
      this.paused = !this.paused
    },
    stepBackward: function () {
      this.pause()
      this.playPosition--
    },
    stepForward: function () {
      this.pause()
      this.playPosition++
    },
  },
  computed: {
    historyMax: function () {
      return this.paused ? this.pausedAt : this.history.length - 1
    },
    latestPacket: function () {
      if (this.history.length) {
        return this.history[this.history.length - 1]
      }
      return null
    },
    currentSlice: function () {
      // The packets to be shown in the text area based on playPosition and "packets to show" selection (array of objects)
      if (this.history.length == 0) return []
      const start = this.showAllPackets
        ? 0
        : this.playPosition - this.packetsToShow + 1
      return this.history.slice(start, this.playPosition + 1).reverse()
    },
    currentBuffers: function () {
      // currentSlice's data converted to either ASCII or hex codes (array of strings)
      return this.currentSlice.map((packet) => {
        if (this.format === 'ascii') {
          return packet.buffer.map((byte) =>
            String.fromCharCode(byte)
              .replace(/\n/, '\\n')
              .replace(/\r/, '\\r')
              .padStart(2, ' ')
          )
        } else {
          return packet.buffer.map((byte) => byte.toString(16).padStart(2, '0'))
        }
      })
    },
    currentLineGroups: function () {
      // currentBuffers but each one is broken up into lines (2D array)
      return this.currentBuffers.map((buffer) =>
        _.chunk(buffer, this.bytesPerLine)
      )
    },
    displayText: function () {
      return this.currentLineGroups
        .map(
          // For each buffer
          (buffer) =>
            buffer
              // For each line in this buffer
              .map((lineBytes, index) => {
                // Combine the line's bytes into a string
                let line = lineBytes.join(' ')
                if (this.showLineAddress) {
                  // with the line address if needed
                  const address = (index * this.bytesPerLine)
                    .toString(16)
                    .padStart(8, '0')
                  line = `${address}: ${line}`
                }
                return line
              })
              .join('\n') // end of one line
        )
        .join('\n\n') // end of one buffer
    },
  },
}
</script>

<style lang="scss" scoped>
.text-area-container {
  position: relative;

  .v-textarea {
    font-family: 'Courier New', Courier, monospace;
  }

  .play-control {
    position: absolute;
    top: 12px;
    right: 24px;

    &.pulse {
      animation: pulse 1s infinite;
    }
  }
}

@keyframes pulse {
  0% {
    opacity: 1;
  }

  50% {
    opacity: 0.5;
  }
}
</style>
