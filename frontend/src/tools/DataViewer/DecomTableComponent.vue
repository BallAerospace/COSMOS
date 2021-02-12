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
    <v-row no-gutters>
      <v-col>
        <v-expansion-panels>
          <v-expansion-panel>
            <v-expansion-panel-header>
              Display Settings
            </v-expansion-panel-header>
            <v-expansion-panel-content>
              <v-container>
                <v-row no-gutters>
                  <v-col>
                    no settings
                  </v-col>
                </v-row>
              </v-container>
            </v-expansion-panel-content>
          </v-expansion-panel>
        </v-expansion-panels>
      </v-col>
    </v-row>
    
    <!-- <v-row>
      <v-col>
        <v-text-field
          v-model="filterText"
          label="Search"
          append-icon="mdi-magnify"
          single-line
          hide-details
        ></v-text-field>
      </v-col>
    </v-row>
    <v-row no-gutters>
      <v-col class="pl-0 pr-0">
        <v-data-table
          :headers="headers"
          :items="rows"
          :search="filterText"
          calculate-widths
          disable-pagination
          hide-default-footer
          multi-sort
          dense
        >
          <template v-slot:item.index="{ item }">
            <span>
              {{
                rows
                  .map(function (x) {
                    return x.name
                  })
                  .indexOf(item.name)
              }}
            </span>
          </template>
          <template v-slot:item.value="{ item }">
            <ValueWidget
              :value="item.value"
              :limitsState="item.limitsState"
              :parameters="[targetName, packetName, item.name]"
              :settings="['WIDTH', '50']"
            ></ValueWidget>
          </template>
        </v-data-table>
      </v-col>
    </v-row> -->
  </v-container>
</template>

<script>
import _ from 'lodash'
import { format } from 'date-fns'

const HISTORY_MAX_SIZE = 100 // TODO: put in config

// NOTE FOR MAKING ANOTHER DATA VIEWER COMPONENT:
// Things that must be here for DataViewer.vue to work properly:
//  - props: config
//  - methods: receive
//  - emit: 'config-change'
export default {
  props: {
    config: {
      type: Object,
    },
  },
  data: function () {
    return {
      currentConfig: {
        // These are just defaults
      },
      history: new Array(HISTORY_MAX_SIZE),
      historyPointer: -1, // index of the newest packet in history
      receivedCount: 0,
      filterText: '',
    }
  },
  watch: {
    currentConfig: {
      deep: true,
      handler: function (val) {
        this.$emit('config-change', val)
      },
    },
  },
  created: function () {
    if (this.config) {
      this.currentConfig = {
        ...this.currentConfig, // In case anything isn't defined in this.config
        ...this.config,
      }
    }
  },
  methods: {
    receive: function (data) {
      // This is called by the parent to feed this component data. A function is used instead
      // of a prop to ensure each message gets handled, regardless of how fast they come in
      data.forEach((packet) => {
        console.log('receive', packet)
        // const decoded = {
        //   buffer: atob(packet.buffer),
        //   time: packet.time,
        //   receivedCount: ++this.receivedCount,
        // }
        // this.historyPointer = ++this.historyPointer % this.history.length
        // this.history[this.historyPointer] = decoded
        // if (!this.paused) {
        //   const packetText = this.calculatePacketText(decoded)
        //   if (this.matchesSearch(packetText)) {
        //     if (!this.displayText) {
        //       this.displayText = packetText
        //     } else if (this.currentConfig.newestAtTop) {
        //       this.displayText = `${packetText}\n\n${this.displayText}`
        //     } else {
        //       this.displayText += `\n\n${packetText}`
        //     }
        //   }
        // }
      })
    },
    matchesSearch: function (text) {
      return text.toLowerCase().includes(this.filterText.toLowerCase())
    },
  },
}
</script>
