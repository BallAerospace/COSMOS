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
  <v-card>
    <v-card-title>
      Routers
      <v-spacer />
      <v-text-field
        v-model="search"
        append-icon="$astro-search"
        label="Search"
        single-line
        hide-details
      />
    </v-card-title>
    <v-data-table
      :headers="headers"
      :items="data"
      :search="search"
      :custom-sort="sortTable"
      calculate-widths
      disable-pagination
      hide-default-footer
      multi-sort
      data-test="routers-table"
    >
      <template v-slot:item.connect="{ item }">
        <v-btn
          block
          color="primary"
          :disabled="buttonsDisabled"
          @click="connectDisconnect(item)"
          >{{ item.connect }}</v-btn
        >
      </template>
      <template v-slot:item.connected="{ item }">
        <span :style="{ color: item.connected_color }">{{
          item.connected
        }}</span>
      </template>
    </v-data-table>
  </v-card>
</template>

<script>
import Updater from './Updater'

export default {
  mixins: [Updater],
  props: {
    tabId: Number,
    curTab: Number,
  },
  data() {
    return {
      search: '',
      data: [],
      buttonsDisabled: false,
      headers: [
        { text: 'Name', value: 'name' },
        {
          text: 'Connect / Disconnect',
          value: 'connect',
          sortable: false,
          filterable: false,
        },
        { text: 'Connected', value: 'connected' },
        { text: 'Clients', value: 'clients' },
        { text: 'Tx Q Size', value: 'tx_q_size' },
        { text: 'Rx Q Size', value: 'rx_q_size' },
        { text: 'Tx Bytes', value: 'tx_bytes' },
        { text: 'Rx Bytes', value: 'rx_bytes' },
        { text: 'Cmd Pkts', value: 'cmd_pkts' },
        { text: 'Tlm Pkts', value: 'tlm_pkts' },
      ],
    }
  },
  methods: {
    // Custom sort algorithm to allow the connected column to be sorted by CONNECTED first
    sortTable(items, index, isDesc) {
      items.sort((a, b) => {
        for (let i = 0; i < index.length; i++) {
          let column = index[i]
          let desc = isDesc[i]

          if (column === 'connected') {
            // Items are the same so continue to let subsequent column sorts apply
            if (a[column] === b[column]) {
              continue
            }
            if (!desc) {
              if (a[column] === 'CONNECTED') {
                return -1
              } else {
                return 1
              }
            } else {
              if (a[column] === 'CONNECTED') {
                return 1
              } else {
                return -1
              }
            }
          } else if (column === 'name') {
            // Items are the same so continue to let subsequent column sorts apply
            if (a[column] === b[column]) {
              continue
            }
            if (!desc) {
              // Strings so use localeCompare to sort
              return a[column].localeCompare(b[column])
            } else {
              return b[column].localeCompare(a[column])
            }
          } else {
            // Items are the same so continue to let subsequent column sorts apply
            if (a[column] === b[column]) {
              continue
            }
            if (!desc) {
              // The rest of the columns are numbers so just subtract to sort
              return a[column] - b[column]
            } else {
              return b[column] - a[column]
            }
          }
        }
      })
      return items
    },
    connectDisconnect(item) {
      this.buttonsDisabled = true
      if (item.connected === 'DISCONNECTED') {
        this.api.connect_router(item.name)
      } else {
        this.api.disconnect_router(item.name)
      }
    },
    update() {
      if (this.tabId != this.curTab) return
      this.api.get_all_router_info().then((info) => {
        this.data = [] // Clear the old data
        for (let int of info) {
          let connect = null
          let connected_color = null
          if (int[1] == 'DISCONNECTED') {
            connect = 'Connect'
            connected_color = 'white'
          } else if (int[1] == 'CONNECTED') {
            connect = 'Disconnect'
            connected_color = 'green'
          } else {
            connect = 'Cancel'
            connected_color = 'red'
          }
          this.data.push({
            name: int[0],
            connect: connect,
            connected_color: connected_color,
            connected: int[1],
            clients: int[2],
            tx_q_size: int[3],
            rx_q_size: int[4],
            tx_bytes: int[5],
            rx_bytes: int[6],
            cmd_pkts: int[7],
            tlm_pkts: int[8],
          })
        }
        this.buttonsDisabled = false
      })
    },
  },
}
</script>

<style scoped></style>
