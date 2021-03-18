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
  <div>
    <TopBar :menus="menus" :title="title"/>
    <v-card>
      <v-tabs v-model="curTab" fixed-tabs>
        <v-tab v-for="(tab, index) in tabs" :key="index" :to="tab.url">{{
          tab.name
        }}</v-tab>
      </v-tabs>
      <router-view :refreshInterval="refreshInterval" />
      <v-dialog v-model="optionsDialog" max-width="300">
        <v-card class="pa-3">
          <v-card-title class="headline">Options</v-card-title>
          <v-text-field
            min="0"
            max="10000"
            step="100"
            type="number"
            label="Refresh Interval (ms)"
            :value="refreshInterval"
            @change="refreshInterval = $event"
          ></v-text-field>
        </v-card>
      </v-dialog>
    </v-card>
    <div style="height: 20px" />
    <LogMessages />
  </div>
</template>

<script>
import LogMessages from '@cosmosc2/tool-common/src/components/LogMessages'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'
export default {
  components: {
    LogMessages,
    TopBar
  },
  data() {
    return {
      title: 'CmdTlmServer',
      curTab: null,
      tabs: [
        {
          name: 'Interfaces',
          url: '/interfaces',
        },
        {
          name: 'Targets',
          url: '/targets',
        },
        {
          name: 'Cmd Packets',
          url: '/cmd-packets',
        },
        {
          name: 'Tlm Packets',
          url: '/tlm-packets',
        },
        {
          name: 'Routers',
          url: '/routers',
        },
        // TODO: Remove these until they work
        // { name: 'Routers', component: 'RoutersTab' },
        // { name: 'Logging', component: 'LoggingTab' },
        {
          name: 'Status',
          url: '/status',
        },
      ],
      updater: null,
      refreshInterval: 1000,
      optionsDialog: false,
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Options',
              command: () => {
                this.optionsDialog = true
              },
            },
          ],
        },
      ],
    }
  },
}
</script>

<style scoped>
.v-list >>> .v-label {
  margin-left: 5px;
}
.v-list-item__icon {
  /* For some reason the default margin-right is huge */
  margin-right: 15px !important;
}
.v-list-item__title {
  color: white;
}
</style>
