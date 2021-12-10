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
  <v-container class="pt-0">
    <v-row dense>
      <v-col>
        <v-text-field
          v-model="filterText"
          class="pt-0 mt-0"
          label="Search"
          append-icon="$astro-search"
          single-line
          hide-details
        />
      </v-col>
    </v-row>
    <v-row>
      <v-col>
        <v-slider
          v-model="pauseOffset"
          v-on:mousedown="pause"
          @click:prepend="stepBackward"
          @click:append="stepForward"
          prepend-icon="mdi-step-backward"
          append-icon="mdi-step-forward"
          :min="1 - history.length"
          :max="0"
          hide-details
        />
      </v-col>
    </v-row>
    <v-row dense no-gutters>
      <v-col>
        <div class="text-area-container">
          <v-textarea
            ref="textarea"
            :value="displayText"
            :auto-grow="receivedCount === 1"
            readonly
            solo
            flat
            hide-details
            data-test="dump-component-text-area"
          />
          <div class="floating-buttons">
            <v-menu
              :close-on-content-click="false"
              :min-width="900"
              :nudge-left="910"
            >
              <template v-slot:activator="{ on, attrs }">
                <v-btn
                  class="ml-2"
                  color="secondary"
                  v-bind="attrs"
                  v-on="on"
                  fab
                  small
                  data-test="dump-component-open-settings"
                >
                  <v-icon>$astro-settings</v-icon>
                </v-btn>
              </template>
              <v-card>
                <v-card-title data-test="display-settings-card">
                  Display settings
                </v-card-title>
                <v-card-text>
                  <v-row no-gutters>
                    <v-col v-if="mode === 'RAW'">
                      <v-radio-group
                        v-model="currentConfig.format"
                        label="Display format"
                      >
                        <v-radio
                          label="Hex"
                          value="hex"
                          data-test="dump-component-settings-format-hex"
                        />
                        <v-radio
                          label="ASCII"
                          value="ascii"
                          data-test="dump-component-settings-format-ascii"
                        />
                      </v-radio-group>
                    </v-col>
                    <v-col>
                      <v-radio-group
                        v-model="currentConfig.newestAtTop"
                        label="Print newest packets to the"
                      >
                        <v-radio
                          label="Top"
                          value
                          data-test="dump-component-settings-newest-top"
                        />
                        <v-radio
                          label="Bottom"
                          :value="false"
                          data-test="dump-component-settings-newest-bottom"
                        />
                      </v-radio-group>
                    </v-col>
                    <v-col>
                      <v-switch
                        v-if="mode === 'RAW'"
                        v-model="currentConfig.showLineAddress"
                        label="Show line address"
                        data-test="dump-component-settings-show-address"
                      />
                      <v-switch
                        v-model="currentConfig.showTimestamp"
                        label="Show timestamp"
                        data-test="dump-component-settings-show-timestamp"
                      />
                    </v-col>
                    <v-col>
                      <v-text-field
                        v-if="mode === 'RAW'"
                        v-model="currentConfig.bytesPerLine"
                        label="Bytes per line"
                        type="number"
                        min="1"
                        v-on:change="validateBytesPerLine"
                        data-test="dump-component-settings-num-bytes"
                      />
                      <v-text-field
                        v-model="currentConfig.packetsToShow"
                        label="Packets to show"
                        type="number"
                        :hint="`Maximum: ${this.history.length}`"
                        persistent-hint
                        :min="1"
                        :max="this.history.length"
                        v-on:change="validatePacketsToShow"
                        data-test="dump-component-settings-num-packets"
                      />
                    </v-col>
                  </v-row>
                </v-card-text>
              </v-card>
            </v-menu>
            <v-btn
              class="ml-2"
              v-on:click="download"
              color="secondary"
              fab
              small
              data-test="dump-component-download"
            >
              <v-icon>mdi-file-download</v-icon>
            </v-btn>
            <v-btn
              class="ml-2"
              :class="{ pulse: paused }"
              v-on:click="togglePlayPause"
              color="primary"
              fab
              data-test="dump-component-play-pause"
            >
              <v-icon large v-if="paused">mdi-play</v-icon>
              <v-icon large v-else>mdi-pause</v-icon>
            </v-btn>
          </div>
        </div>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import _ from 'lodash'
import { format } from 'date-fns'
import Component from './Component'

const HISTORY_MAX_SIZE = 100 // TODO: put in config, or make the component learn it based on packet size, or something?

export default {
  mixins: [Component],
  data: function () {
    return {
      history: new Array(HISTORY_MAX_SIZE),
      historyPointer: -1, // index of the newest packet in history
      receivedCount: 0,
      filterText: '',
      paused: false,
      pausedAt: 0,
      pauseOffset: 0,
      pausedHistory: [],
      textarea: null,
      displayText: null,
      packetSize: 0,
    }
  },
  computed: {
    // These are just here to trigger their respective watch functions above
    // There's a better solution to this in Vue 3 v3.vuejs.org/api/computed-watch-api.html#watching-multiple-sources
    allInstantSettings: function () {
      return `${this.currentConfig.format}|${this.currentConfig.showLineAddress}|${this.currentConfig.showTimestamp}|${this.currentConfig.newestAtTop}|${this.pauseOffset}`
    },
    allDebouncedSettings: function () {
      return `${this.currentConfig.bytesPerLine}|${this.currentConfig.packetsToShow}|${this.filterText}`
    },
  },
  watch: {
    lastReceived: function (data) {
      data.forEach((packet) => {
        delete packet.packet
        let decoded = {
          ...packet,
          receivedCount: ++this.receivedCount,
        }
        if ('buffer' in packet) {
          decoded.buffer = atob(packet.buffer)
        }
        this.historyPointer = ++this.historyPointer % this.history.length
        this.history[this.historyPointer] = decoded
        if (!this.paused) {
          const packetText = this.calculatePacketText(decoded)
          if (this.matchesSearch(packetText)) {
            if (!this.displayText) {
              this.displayText = packetText
            } else if (this.currentConfig.newestAtTop) {
              this.displayText = `${packetText}\n\n${this.displayText}`
            } else {
              this.displayText += `\n\n${packetText}`
            }
          }
        }
      })
      this.trimDisplayText()
      if (!this.paused && !this.currentConfig.newestAtTop) {
        this.updateScrollPosition()
      }
    },
    paused: function (val) {
      if (val) {
        this.pausedAt = this.historyPointer
        this.pausedHistory = this.history.slice()
      } else {
        this.pauseOffset = 0
        this.rebuildDisplayText()
      }
    },
    allInstantSettings: function () {
      this.rebuildDisplayText()
    },
    allDebouncedSettings: _.debounce(function () {
      this.rebuildDisplayText()
    }, 300),
  },
  created: function () {
    const defaultConfig = {
      format: 'hex',
      showLineAddress: true,
      showTimestamp: true,
      bytesPerLine: 16,
      packetsToShow: 1,
      newestAtTop: false,
    }
    this.currentConfig = {
      ...defaultConfig, // In case anything isn't defined in this.config
      ...this.currentConfig,
    }
  },
  mounted: function () {
    this.textarea = this.$refs.textarea.$el.querySelectorAll('textarea')[0]
  },
  methods: {
    trimDisplayText: function () {
      // Could make this more robust by counting lines instead, but that's slower
      if (this.currentConfig.newestAtTop) {
        this.displayText = this.displayText.substring(
          0,
          this.packetSize * this.currentConfig.packetsToShow
        )
      } else {
        this.displayText = this.displayText.substring(
          this.displayText.length -
            (this.packetSize + 2) * this.currentConfig.packetsToShow +
            2
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
    rebuildDisplayText: function () {
      let packets = this.paused ? this.pausedHistory : this.history
      // Order packets chronologically and filter out the ones that aren't needed
      const breakpoint = this.paused ? this.pausedAt : this.historyPointer
      packets = packets
        .filter((packet) => packet) // in case history hasn't been filled yet
        .slice(breakpoint + 1)
        .concat(packets.slice(0, breakpoint + 1))
        .map(this.calculatePacketText) // convert to display text
        .filter(this.matchesSearch)
      if (this.paused) {
        // Remove any that are after the slider (offset)
        const sliderPosition = Math.max(packets.length + this.pauseOffset, 1) // Always show at least one
        packets = packets.slice(0, sliderPosition)
      }
      // Take however many are supposed to be shown
      const end = Math.max(this.currentConfig.packetsToShow, 1) // Always show at least one
      packets = packets.slice(-end)
      if (this.currentConfig.newestAtTop) {
        packets = packets.reverse()
      }
      this.displayText = packets.join('\n\n')
    },
    matchesSearch: function (text) {
      return text.toLowerCase().includes(this.filterText.toLowerCase())
    },
    calculatePacketText: function (packet) {
      let text = ''
      if (this.currentConfig.showTimestamp) {
        const milliseconds = packet.time / 1000000
        const receivedSeconds = (milliseconds / 1000).toFixed(7)
        const receivedDate = new Date(milliseconds).toISOString()
        // const receivedCt = packet.receivedCount.toString().padEnd(20, ' ') // Padding fixes issue where opening asterisks would get deleted by trimDisplayText
        let timestamp = '********************************************\n'
        timestamp += `* Received seconds: ${receivedSeconds}\n`
        timestamp += `* Received time: ${receivedDate}\n`
        // timestamp += `* Received count: ${receivedCt}\n`
        timestamp += '********************************************\n'
        text = `${timestamp}${text}`
      }
      if ('buffer' in packet) {
        // Split its buffer into lines of the selected length
        text += _.chunk([...packet.buffer], this.currentConfig.bytesPerLine)
          .map((lineBytes, index) => {
            // Map each line into ASCII or hex values
            let mappedBytes = []
            if (this.currentConfig.format === 'ascii') {
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
            if (this.currentConfig.showLineAddress) {
              const address = (index * this.currentConfig.bytesPerLine)
                .toString(16)
                .padStart(8, '0')
              line = `${address}: ${line}`
            }
            return line
          })
          .join('\n') // end of one line
      } else {
        text += Object.keys(packet)
          .filter((item) => item != 'time')
          .map((item) => `${item}: ${packet[item]}`)
          .join('\n')
      }
      this.packetSize = text.length // Set this every time in case it changes with rebuildDisplayText
      return text
    },
    validateBytesPerLine: function () {
      if (this.currentConfig.bytesPerLine < 1) {
        this.currentConfig.bytesPerLine = 1
      }
    },
    validatePacketsToShow: function () {
      if (this.currentConfig.packetsToShow > this.history.length) {
        this.currentConfig.packetsToShow = this.history.length
      } else if (this.currentConfig.packetsToShow < 1) {
        this.currentConfig.packetsToShow = 1
      }
    },
    download: function () {
      const blob = new Blob([this.displayText], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      let url = URL.createObjectURL(blob)
      link.href = url
      link.setAttribute(
        'download',
        `${format(new Date(), 'yyyy_MM_dd_HH_mm_ss')}.txt`
      )
      link.click()
      window.URL.revokeObjectURL(url)
    },
    pause: function () {
      this.paused = true
    },
    togglePlayPause: function () {
      this.paused = !this.paused
    },
    stepBackward: function () {
      this.pause()
      this.pauseOffset--
    },
    stepForward: function () {
      this.pause()
      this.pauseOffset++
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

  .floating-buttons {
    position: absolute;
    top: 12px;
    right: 24px;
  }
}

.pulse {
  animation: pulse 1s infinite;
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
