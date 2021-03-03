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
      Command Packets
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
      class="data-table"
      calculate-widths
      disable-pagination
      hide-default-footer
      multi-sort
      data-test="cmd-packets-table"
    >
      <template v-slot:item.view_raw="{ item }">
        <v-btn
          block
          color="primary"
          @click="openViewRaw(item.target_name, item.packet_name)"
          >View Raw</v-btn
        >
      </template>
      <template v-slot:item.view_in_cmd_sender="{ item }">
        <span v-if="item.target_name === 'UNKNOWN'">N/A</span>
        <v-btn
          v-if="item.target_name != 'UNKNOWN'"
          block
          color="primary"
          @click="openCmdSender(item.target_name, item.packet_name)"
          >View In Command Sender</v-btn
        >
      </template>
    </v-data-table>
    <RawDialog
      type="Command"
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
        { text: 'View In Command Sender', value: 'view_in_cmd_sender' },
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
    openCmdSender(target_name, packet_name) {
      let routeData = this.$router.resolve({
        name: 'CommandSender',
        params: {
          target: target_name,
          packet: packet_name,
        },
      })
      window.open(routeData.href, '_blank')
    },
    update() {
      if (this.tabId != this.curTab) return
      this.api.get_all_cmd_info().then((info) => {
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
