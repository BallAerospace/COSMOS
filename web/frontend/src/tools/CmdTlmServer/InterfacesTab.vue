<template>
  <v-card>
    <v-card-title>
      Interfaces
      <v-spacer></v-spacer>
      <v-text-field
        v-model="search"
        append-icon="mdi-magnify"
        label="Search"
        single-line
        hide-details
      ></v-text-field>
    </v-card-title>
    <v-data-table
      :headers="headers"
      :items="data"
      :search="search"
      calculate-widths
      disable-pagination
      hide-default-footer
      multi-sort
      data-test="interfaces-table"
    >
      <template v-slot:item.connect="{ item }">
        <v-btn
          block
          color="primary"
          :disabled="buttonsDisabled"
          @click="connectDisconnect(item)"
        >{{ item.connect }}</v-btn>
      </template>
      <template v-slot:item.connected="{ item }">
        <span :style="{ color: item.connected_color }">{{ item.connected }}</span>
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
    curTab: Number
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
          filterable: false
        },
        { text: 'Connected', value: 'connected' },
        { text: 'Clients', value: 'clients' },
        { text: 'Tx Q Size', value: 'tx_q_size' },
        { text: 'Rx Q Size', value: 'rx_q_size' },
        { text: 'Tx Bytes', value: 'tx_bytes' },
        { text: 'Rx Bytes', value: 'rx_bytes' },
        { text: 'Cmd Pkts', value: 'cmd_pkts' },
        { text: 'Tlm Pkts', value: 'tlm_pkts' }
      ]
    }
  },
  methods: {
    connectDisconnect(item) {
      this.buttonsDisabled = true
      if (item.connected === 'DISCONNECTED') {
        this.api.connect_interface(item.name)
      } else {
        this.api.disconnect_interface(item.name)
      }
    },
    update() {
      if (this.tabId != this.curTab) return
      this.api.get_all_interface_info().then(info => {
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
            tlm_pkts: int[8]
          })
        }
        this.buttonsDisabled = false
      })
    }
  }
}
</script>

<style scoped></style>
