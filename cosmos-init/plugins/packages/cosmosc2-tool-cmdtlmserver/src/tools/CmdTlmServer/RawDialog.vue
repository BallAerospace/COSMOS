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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <v-dialog v-model="isVisible" @keydown.esc="isVisible = false" width="790px">
    <v-card>
      <v-system-bar>
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-icon data-test="copy-icon" @click="copyRawData">
                mdi-content-copy
              </v-icon>
            </div>
          </template>
          <span> Copy </span>
        </v-tooltip>
        <v-spacer />
        <span> {{ type }} </span>
        <v-spacer />
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-icon data-test="download" @click="downloadRawData">
                mdi-download
              </v-icon>
            </div>
          </template>
          <span> Download </span>
        </v-tooltip>
      </v-system-bar>
      <v-card-title>
        <span> {{ header }} </span>
        <v-spacer />
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-btn icon data-test="pause" @click="pause">
                <v-icon> {{ buttonIcon }} </v-icon>
              </v-btn>
            </div>
          </template>
          <span> {{ buttonLabel }} </span>
        </v-tooltip>
      </v-card-title>
      <v-card-text>
        <v-row dense>
          <v-col cols="4">
            <span> Received Time: </span>
          </v-col>
          <v-col class="text-right">
            <span> {{ receivedTime }} </span>
          </v-col>
        </v-row>
        <v-row dense>
          <v-col cols="4">
            <span> Count: </span>
          </v-col>
          <v-col class="text-right">
            <span> {{ receivedCount }} </span>
          </v-col>
        </v-row>
        <v-textarea v-model="rawData" class="pa-0 ma-0" auto-grow readonly />
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script>
import { format } from 'date-fns'

import Updater from './Updater'

export default {
  mixins: [Updater],
  props: {
    type: String,
    visible: Boolean,
    targetName: String,
    packetName: String,
  },
  data() {
    return {
      header: '',
      receivedTime: '',
      rawData: '',
      paused: false,
      receivedCount: '',
    }
  },
  computed: {
    buttonLabel: function () {
      if (this.paused) {
        return 'Resume'
      } else {
        return 'Pause'
      }
    },
    buttonIcon: function () {
      if (this.paused) {
        return 'mdi-play'
      } else {
        return 'mdi-pause'
      }
    },
    isVisible: {
      get: function () {
        return this.visible
      },
      // Reset all the data to defaults
      set: function (bool) {
        this.header = ''
        this.receivedTime = ''
        this.rawData = ''
        this.receivedCount = ''
        this.paused = false
        this.buttonLabel = 'Pause'
        this.$emit('display', bool)
      },
    },
  },
  methods: {
    copyRawData: function () {
      navigator.clipboard.writeText(this.rawData)
    },
    downloadRawData: function () {
      const blob = new Blob([this.rawData], {
        type: 'plain/text',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      const dt = format(Date.now(), 'yyyy_MM_dd_HH_mm_ss')
      link.setAttribute(
        'download',
        `${dt}_${this.targetName}_${this.packetName}.txt`
      )
      link.click()
    },
    pause: function () {
      this.paused = !this.paused
    },
    update: function () {
      if (!this.isVisible || this.paused) return
      this.header = `Raw ${this.type} Packet: ${this.targetName} ${this.packetName}`

      if (this.type === 'Telemetry') {
        this.updateTelemetry()
      } else {
        this.updateCommand()
      }
    },
    updateTelemetry: function () {
      this.api
        .get_tlm_buffer(this.targetName, this.packetName)
        .then((result) => {
          this.receivedTime = new Date(result.time / 1000000)
          this.receivedCount = result.received_count
          this.rawData =
            'Address   Data                                             Ascii\n' +
            '---------------------------------------------------------------------------\n' +
            this.formatBuffer(result.buffer.raw)
        })
    },
    updateCommand: function () {
      this.api
        .get_cmd_buffer(this.targetName, this.packetName)
        .then((result) => {
          this.receivedTime = new Date(result.time / 1000000)
          this.receivedCount = result.received_count
          this.rawData =
            'Address   Data                                             Ascii\n' +
            '---------------------------------------------------------------------------\n' +
            this.formatBuffer(result.buffer.raw)
        })
    },
    // TODO: Perhaps move this to a utility library
    formatBuffer: function (buffer) {
      var string = ''
      var index = 0
      var ascii = ''
      buffer.forEach((byte) => {
        if (index % 16 === 0) {
          string += this.numHex(index, 8) + ': '
        }
        string += this.numHex(byte)

        // Create the ASCII representation if printable
        if (byte >= 32 && byte <= 126) {
          ascii += String.fromCharCode(byte)
        } else {
          ascii += ' '
        }

        index++

        if (index % 16 === 0) {
          string += '  ' + ascii + '\n'
          ascii = ''
        } else {
          string += ' '
        }
      })

      // We're done printing all the bytes. Now check to see if we ended in the
      // middle of a line. If so we have to print out the final ASCII if
      // requested.
      if (index % 16 != 0) {
        var existing_length = (index % 16) - 1 + (index % 16) * 2
        // 47 is (16 * 2) + 15 separator spaces
        var filler = ' '.repeat(47 - existing_length)
        var ascii_filler = ' '.repeat(16 - ascii.length)
        string += filler + '  ' + ascii + ascii_filler
      }
      return string
    },
    numHex(num, width = 2) {
      var hex = num.toString(16)
      return '0'.repeat(width - hex.length) + hex
    },
  },
}
</script>
<style scoped>
.v-textarea >>> textarea {
  margin-top: 10px;
  font-family: 'Courier New', Courier, monospace;
}
</style>
