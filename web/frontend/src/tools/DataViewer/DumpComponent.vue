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
        <v-radio-group v-model="format" label="Display format">
          <v-radio label="Hex" value="hex" />
          <v-radio label="ASCII" value="ascii" />
        </v-radio-group>
      </v-col>
      <v-col>
        <v-switch v-model="showLineAddress" label="Show line address" />
      </v-col>
      <v-col>
        <v-switch v-model="showTimestamp" label="Show timestamp" />
      </v-col>
      <v-col>
        <v-text-field
          v-model="bytesPerLine"
          label="Bytes per line"
          type="number"
        ></v-text-field>
      </v-col>
      <v-col>
        <v-text-field
          v-model="packetsToShow"
          label="Packets to show"
          type="number"
          :min="1"
          :max="this.history.length"
          v-on:change="validatePacketsToShow"
        ></v-text-field>
      </v-col>
      <v-col>
        <v-radio-group
          v-model="newestAtTop"
          label="Print newest packets to the"
        >
          <v-radio label="Top" :value="true" />
          <v-radio label="Bottom" :value="false" />
        </v-radio-group>
      </v-col>
    </v-row>
    <!-- <v-row>
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
    </v-row> -->
    <v-row>
      <v-col class="pl-0 pr-0">
        <div class="text-area-container">
          <v-textarea
            ref="textarea"
            :value="displayText"
            :auto-grow="receivedCount == 1"
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

const HISTORY_MAX_SIZE = 100

export default {
  components: {
    PacketSummaryComponent,
  },
  data: function () {
    return {
      history: new Array(HISTORY_MAX_SIZE),
      historyPointer: -1,
      receivedCount: 0,
      format: 'hex',
      showLineAddress: true,
      showTimestamp: true,
      bytesPerLine: 16,
      packetsToShow: 1,
      newestAtTop: false,
      paused: false,
      pausedAt: 0,
      playPosition: 0,
      textarea: null,
      displayText: null,
      packetSize: 0,
    }
  },
  watch: {
    paused: function (val) {
      if (val) {
        this.pausedAt = this.playPosition
      } else {
        this.playPosition = Math.min(this.receivedCount, HISTORY_MAX_SIZE)
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
        const decoded = {
          buffer: atob(packet.buffer),
          time: packet.time,
        }
        this.historyPointer = ++this.historyPointer % HISTORY_MAX_SIZE
        this.history[this.historyPointer] = decoded

        const packetText = this.calculatePacketText(decoded)
        if (!this.displayText) {
          this.displayText = packetText
        } else if (this.newestAtTop) {
          this.displayText = `${packetText}\n\n${this.displayText}`
        } else {
          this.displayText += `\n\n${packetText}`
        }
      })
      this.receivedCount += data.length
      this.trimDisplayText()
      if (!this.paused) {
        this.playPosition += data.length
        !this.newestAtTop && this.updateScrollPosition()
      }
    },
    trimDisplayText: function () {
      if (this.newestAtTop) {
        this.displayText = this.displayText.substring(
          0,
          this.packetSize * this.packetsToShow
        )
      } else {
        this.displayText = this.displayText.substring(
          this.displayText.length - (this.packetSize + 2) * this.packetsToShow + 2
        )
      }
    },
    updateScrollPosition: function () {
      // Alternatively, only set if it's at the bottom already?
      const currentScrollOffset =
        this.textarea.scrollTop - this.textarea.scrollHeight
      this.$nextTick(() => {
        this.textarea.scrollTop =
          this.textarea.scrollHeight + currentScrollOffset
      })
    },
    calculatePacketText: function (packet) {
      // Split its buffer into lines of the selected length
      let text = _.chunk(packet.buffer.split(''), this.bytesPerLine)
        .map((lineBytes, index) => {
          // Map each line into ASCII or hex values
          let mappedBytes = []
          if (this.format === 'ascii') {
            mappedBytes = lineBytes.map((byte) =>
              byte.replace(/\n/, '\\n').replace(/\r/, '\\r').padStart(2, ' ')
            )
          } else {
            mappedBytes = lineBytes.map((byte) =>
              byte.charCodeAt(0).toString(16).padStart(2, '0')
            )
          }
          let line = mappedBytes.join(' ')
          // Prepend the line address if needed
          if (this.showLineAddress) {
            const address = (index * this.bytesPerLine)
              .toString(16)
              .padStart(8, '0')
            line = `${address}: ${line}`
          }
          return line
        })
        .join('\n') // end of one line
      if (this.showTimestamp) {
        const milliseconds = packet.time / 1000000
        let timestamp = '********************************************\n'
        timestamp += `* Received seconds: ${(milliseconds / 1000).toFixed(7)}\n`
        timestamp += `* Received time: ${new Date(milliseconds).toISOString()}\n`
        timestamp += `* Received count: ${this.receivedCount}\n` // TODO: is this right?
        timestamp += '********************************************\n'
        text = `${timestamp}${text}`
      }
      this.packetSize = this.packetSize || text.length
      return text
    },
    validatePacketsToShow: function () {
      if (this.packetsToShow > HISTORY_MAX_SIZE) this.packetsToShow = HISTORY_MAX_SIZE
      else if (this.packetsToShow < 1) this.packetsToShow = 1
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
      return this.paused
        ? this.pausedAt
        : Math.min(this.receivedCount, HISTORY_MAX_SIZE)
    },
    latestPacket: function () {
      if (this.historyPointer < 0) return null
      return this.history[this.historyPointer]
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
