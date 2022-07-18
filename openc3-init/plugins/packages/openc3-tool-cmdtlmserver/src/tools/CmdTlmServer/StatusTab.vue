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
  <div>
    <!-- Use a container here so we can do cols="auto" to resize v-select -->
    <v-card flat>
      <v-container class="ma-0 pa-4">
        <v-row no-gutters>
          <v-col cols="auto">
            <!-- TODO: move to admin settings and delete this tab -->
            <v-select
              label="Limits Set"
              :items="limitsSets"
              v-model="currentLimitsSet"
              data-test="limits-set"
            />
          </v-col>
        </v-row>
      </v-container>
    </v-card>

    <!-- v-card flat>
      <v-card-title>API Status</v-card-title>
      <v-data-table
        :headers="apiHeaders"
        :items="apiStatus"
        calculate-widths
        disable-pagination
        hide-default-footer
      />
    </v-card>

    <v-card flat>
      <v-card-title>Background Tasks</v-card-title>
      <v-data-table
        :headers="backgroundHeaders"
        :items="backgroundTasks"
        calculate-widths
        disable-pagination
        hide-default-footer
      >
        <template v-slot:item.control="{ item }">
          <v-btn
            block
            color="primary"
            @click="taskControl(item.name, item.control)"
          >
            {{ item.control }}
          </v-btn>
        </template>
      </v-data-table>
    </v-card -->
  </div>
</template>

<script>
// import Updater from './Updater'
import { OpenC3Api } from '@openc3/tool-common/src/services/openc3-api'

export default {
  // mixins: [Updater],
  props: {
    tabId: Number,
    curTab: Number,
  },
  data() {
    return {
      api: new OpenC3Api(),
      apiStatus: [],
      apiHeaders: [
        { text: 'Port', value: 'port' },
        { text: 'Clients', value: 'clients' },
        { text: 'Requests', value: 'requests' },
        { text: 'Avg Request Time', value: 'avgTime' },
        { text: 'Server Threads', value: 'threads' },
      ],
      backgroundTasks: [],
      backgroundHeaders: [
        { text: 'Name', value: 'name' },
        { text: 'State', value: 'state' },
        { text: 'Status', value: 'status' },
        { text: 'Control', value: 'control' },
      ],
      limitsSets: [],
      currentLimitsSet: '',
      currentSetRefreshInterval: null,
    }
  },
  watch: {
    currentLimitsSet: function (newVal, oldVal) {
      !!oldVal && this.limitsChange(newVal)
    },
  },
  created() {
    this.api.get_limits_sets().then((sets) => {
      this.limitsSets = sets
    })
    this.getCurrentLimitsSet()
    this.currentSetRefreshInterval = setInterval(
      this.getCurrentLimitsSet,
      60 * 1000
    )
  },
  destroyed: function () {
    clearInterval(this.currentSetRefreshInterval)
  },
  methods: {
    // update() {
    //   if (this.tabId != this.curTab) return
    //   this.api.get_server_status().then((status) => {
    //     this.currentLimitsSet = status[0]
    //     this.apiStatus = [
    //       {
    //         port: status[1],
    //         clients: status[2],
    //         requests: status[3],
    //         avgTime: (Math.round(status[4] * 1000000) / 1000000).toFixed(6),
    //         threads: status[5],
    //       },
    //     ]
    //   })
    //   this.api.get_background_tasks().then((tasks) => {
    //     this.backgroundTasks = []
    //     for (let x of tasks) {
    //       var control = ''
    //       if (x[1] == 'no thread' || x[1] == 'complete') {
    //         control = 'Start'
    //       } else {
    //         control = 'Stop'
    //       }
    //       this.backgroundTasks.push({
    //         name: x[0],
    //         state: x[1],
    //         status: x[2],
    //         control: control,
    //       })
    //     }
    //   })
    // },
    getCurrentLimitsSet: function () {
      this.api.get_limits_set().then((result) => {
        this.currentLimitsSet = result
      })
    },
    limitsChange(value) {
      this.api.set_limits_set(value)
    },
    taskControl(name, state) {
      if (state == 'Start') {
        this.api.start_background_task(name)
      } else if (state == 'Stop') {
        this.api.stop_background_task(name)
      }
    },
  },
}
</script>

<style scoped>
.container,
.theme--dark.v-card,
.theme--dark.v-sheet {
  background-color: var(--v-tertiary-darken2);
}
</style>
