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
    <!-- <v-row no-gutters>
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
    </v-row> -->
    <v-row>
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
    </v-row>
  </v-container>
</template>

<script>
import _ from 'lodash'
import { format } from 'date-fns'
import ValueWidget from '@/components/widgets/ValueWidget'

const HISTORY_MAX_SIZE = 100 // TODO: put in config

// NOTE FOR MAKING ANOTHER DATA VIEWER COMPONENT:
// Things that must be here for DataViewer.vue to work properly:
//  - props: config
//  - methods: receive
//  - emit: 'config-change'
export default {
  components: {
    ValueWidget,
  },
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
      headers: [
        { text: 'Index', value: 'index' },
        { text: 'Name', value: 'name' },
        { text: 'Value', value: 'value' },
      ],
      targetName: '',
      packetName: '',
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
      if (!this.targetName) {
        const split = data[0].packet.split('__')
        this.targetName = split[2]
        this.packetName = split[3]
      }
      data.forEach((packet) => {
        delete packet.time
        delete packet.packet
        this.historyPointer = ++this.historyPointer % this.history.length
        this.history[this.historyPointer] = packet
      })
    },
  },
  computed: {
    rows: function () {
      if (this.historyPointer === -1) return []
      const packet = this.history[this.historyPointer]
      return Object.keys(packet).map((key, index) => {
        return {
          index: index,
          name: key,
          value: packet[key],
        }
      })
      // return this.history
      //   .slice(this.historyPointer + 1)
      //   .concat(this.history.slice(0, this.historyPointer + 1))
      //   .filter((packet) => packet)
      //   .reverse()
      //   .flatMap((packet) =>
      //     Object.keys(packet).map((key, index) => {
      //       return {
      //         index: index,
      //         name: key,
      //         value: packet[key],
      //       }
      //     })
      //   )
    },
  },
}
</script>
