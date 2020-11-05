<template>
  <v-card>
    <v-card-title>
      Telemetry Packets
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
      data-test="tlm-packets-table"
    >
      <template v-slot:item.view_raw="{ item }">
        <v-btn
          block
          color="primary"
          @click="openViewRaw(item.target_name, item.packet_name)"
          >View Raw</v-btn
        >
      </template>
      <template v-slot:item.view_in_pkt_viewer="{ item }">
        <span v-if="item.target_name === 'UNKNOWN'">N/A</span>
        <v-btn
          v-if="item.target_name != 'UNKNOWN'"
          block
          color="primary"
          @click="openPktViewer(item.target_name, item.packet_name)"
          >View In Packet Viewer</v-btn
        >
      </template>
    </v-data-table>
    <RawDialog
      type="Telemetry"
      :targetName="target_name"
      :packetName="packet_name"
      :visible="viewRaw"
      @display="rawDisplayCallback"
    />
  </v-card>
</template>

<script>
import Updater from './Updater'
import RawDialog from './RawDialog'

export default {
  components: {
    RawDialog,
  },
  mixins: [Updater],
  props: {
    tabId: Number,
    curTab: Number,
  },
  data() {
    return {
      search: '',
      data: [],
      headers: [
        { text: 'Target Name', value: 'target_name' },
        { text: 'Packet Name', value: 'packet_name' },
        { text: 'Packet Count', value: 'count' },
        { text: 'View Raw', value: 'view_raw' },
        { text: 'View In Packet Viewer', value: 'view_in_pkt_viewer' },
      ],
      viewRaw: false,
      target_name: null,
      packet_name: null,
    }
  },
  methods: {
    // This method is hooked to the RawDialog as a callback to
    // keep track of whether the dialog is displayed
    rawDisplayCallback(bool) {
      this.viewRaw = bool
    },
    openViewRaw(target_name, packet_name) {
      this.target_name = target_name
      this.packet_name = packet_name
      this.viewRaw = true
    },
    openPktViewer(target_name, packet_name) {
      let routeData = this.$router.resolve({
        name: 'PackerViewer',
        params: {
          target: target_name,
          packet: packet_name,
        },
      })
      window.open(routeData.href, '_blank')
    },
    update() {
      if (this.tabId != this.curTab) return
      this.api.get_all_tlm_info().then((info) => {
        this.data = []
        for (let x of info) {
          this.data.push({
            target_name: x[0],
            packet_name: x[1],
            count: x[2],
          })
        }
      })
    },
  },
}
</script>

<style scoped></style>
