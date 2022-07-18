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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
-->

<template>
  <v-card>
    <v-card-title>
      {{ data.length }} Targets
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
      :footer-props="{ itemsPerPageOptions: [10, 20, -1] }"
      calculate-widths
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
