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
  <v-card>
    <v-card-title>
      {{ data.length }} Telemetry Packets
      <v-spacer />
      <v-text-field
        v-model="search"
        append-icon="mdi-magnify"
        label="Search"
        single-line
        hide-details
      />
    </v-card-title>
    <v-data-table
      :headers="headers"
      :items="data"
      :search="search"
      :items-per-page="10"
      :footer-props="{ itemsPerPageOptions: [10, 20, 50, 100] }"
      sort-by="target_name"
      @pagination="pagination"
      calculate-widths
      multi-sort
      data-test="tlm-packets-table"
    >
      <template v-slot:item.view_raw="{ item }">
        <v-btn
          block
          color="primary"
          :disabled="item.count < 1"
          @click="openViewRaw(item.target_name, item.packet_name)"
        >
          View Raw
        </v-btn>
      </template>
      <template v-slot:item.view_in_pkt_viewer="{ item }">
        <span v-if="item.target_name === 'UNKNOWN'">N/A</span>
        <v-btn
          v-if="item.target_name != 'UNKNOWN'"
          block
          color="primary"
          @click="openPktViewer(item.target_name, item.packet_name)"
        >
          View In Packet Viewer
          <v-icon right> mdi-open-in-new </v-icon>
        </v-btn>
      </template>
    </v-data-table>
    <raw-dialog
      type="Telemetry"
      :target-name="target_name"
      :packet-name="packet_name"
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
      paginationEvent: null,
    }
  },
  created() {
    this.api.get_target_list().then((targets) => {
      targets.map((target) => {
        this.api.get_all_telemetry_names(target).then((names) => {
          this.data = this.data.concat(
            names.map((packet) => {
              return { target_name: target, packet_name: packet, count: 0 }
            })
          )
        })
      })
    })
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
      window.open(`/tools/packetviewer/${target_name}/${packet_name}`, '_blank')
    },
    pagination(event) {
      this.paginationEvent = event
    },
    update() {
      if (this.tabId != this.curTab) return
      if (this.paginationEvent === null) return
      let visible = this.data
        .slice(this.paginationEvent.pageStart, this.paginationEvent.pageStop)
        .map((value) => {
          return [value.target_name, value.packet_name]
        })
      this.api.get_tlm_cnts(visible).then((counts) => {
        let countIndex = 0
        for (
          let i = this.paginationEvent.pageStart;
          i < this.paginationEvent.pageStart + counts.length;
          i++
        ) {
          this.data[i].count = counts[countIndex]
          countIndex++
        }
      })
    },
  },
}
</script>
