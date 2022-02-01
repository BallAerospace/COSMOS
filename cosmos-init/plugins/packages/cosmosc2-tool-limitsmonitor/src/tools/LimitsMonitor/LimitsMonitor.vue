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
  <div>
    <top-bar :menus="menus" :title="title" />
    <v-card>
      <v-tabs v-model="curTab" fixed-tabs>
        <v-tab v-for="(tab, index) in tabs" :key="index">{{ tab }}</v-tab>
      </v-tabs>
      <v-tabs-items v-model="curTab">
        <v-tab-item eager>
          <keep-alive>
            <limits-control ref="control" v-model="ignored" :key="renderKey" />
          </keep-alive>
        </v-tab-item>
        <v-tab-item eager>
          <keep-alive>
            <limits-events ref="events" />
          </keep-alive>
        </v-tab-item>
      </v-tabs-items>
    </v-card>
    <open-config-dialog
      v-model="openConfig"
      :tool="toolName"
      @success="openConfiguration"
    />
    <save-config-dialog
      v-model="saveConfig"
      :tool="toolName"
      @success="saveConfiguration"
    />
  </div>
</template>

<script>
import LimitsControl from '@/tools/LimitsMonitor/LimitsControl'
import LimitsEvents from '@/tools/LimitsMonitor/LimitsEvents'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'
import Cable from '@cosmosc2/tool-common/src/services/cable.js'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import OpenConfigDialog from '@cosmosc2/tool-common/src/components/OpenConfigDialog'
import SaveConfigDialog from '@cosmosc2/tool-common/src/components/SaveConfigDialog'

export default {
  components: {
    LimitsControl,
    LimitsEvents,
    TopBar,
    OpenConfigDialog,
    SaveConfigDialog,
  },
  data() {
    return {
      title: 'Limits Monitor',
      toolName: 'limits-monitor',
      curTab: null,
      tabs: ['Limits', 'Log'],
      api: new CosmosApi(),
      cable: new Cable(),
      subscription: null,
      renderKey: 0,
      ignored: [],
      openConfig: false,
      saveConfig: false,
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Show Ignored',
              command: () => {
                this.$refs.control.showIgnored()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Open Configuration',
              command: () => {
                this.openConfig = true
              },
            },
            {
              label: 'Save Configuration',
              command: () => {
                this.saveConfig = true
              },
            },
          ],
        },
      ],
    }
  },
  created() {
    this.cable
      .createSubscription(
        'LimitsEventsChannel',
        localStorage.scope,
        {
          received: (data) => {
            const parsed = JSON.parse(data)
            this.$refs.control.handleMessages(parsed)
            this.$refs.events.handleMessages(parsed)
          },
        },
        {
          history_count: 1000,
        }
      )
      .then((subscription) => {
        this.subscription = subscription
      })
  },
  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    async openConfiguration(name) {
      const response = await this.api.load_config(this.toolName, name)
      this.ignored = JSON.parse(response)
      this.renderKey++ // Trigger re-render
    },
    saveConfiguration(name) {
      this.api.save_config(this.toolName, name, JSON.stringify(this.ignored))
    },
  },
}
</script>
