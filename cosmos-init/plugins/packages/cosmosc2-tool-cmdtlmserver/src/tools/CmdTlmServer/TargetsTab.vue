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
      Targets
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
      calculate-widths
      disable-pagination
      hide-default-footer
      multi-sort
      data-test="targets-table"
    />
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
      headers: [
        { text: 'Target Name', value: 'name' },
        { text: 'Interface', value: 'interface' },
        { text: 'Command Count', value: 'cmd_count' },
        { text: 'Telemetry Count', value: 'tlm_count' },
      ],
    }
  },
  methods: {
    update() {
      if (this.tabId != this.curTab) return
      this.api.get_all_target_info().then((info) => {
        this.data = []
        for (let x of info) {
          this.data.push({
            name: x[0],
            interface: x[1],
            cmd_count: x[2],
            tlm_count: x[3],
          })
        }
      })
    },
  },
}
</script>
