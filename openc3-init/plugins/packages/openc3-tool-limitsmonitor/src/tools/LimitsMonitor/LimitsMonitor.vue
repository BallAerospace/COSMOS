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
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <open-config-dialog
      v-if="openConfig"
      v-model="openConfig"
      :tool="toolName"
      @success="openConfiguration"
    />
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <save-config-dialog
      v-if="saveConfig"
      v-model="saveConfig"
      :tool="toolName"
      @success="saveConfiguration"
    />
  </div>
</template>

<script>
import LimitsControl from '@/tools/LimitsMonitor/LimitsControl'
import LimitsEvents from '@/tools/LimitsMonitor/LimitsEvents'
import TopBar from '@openc3/tool-common/src/components/TopBar'
import Cable from '@openc3/tool-common/src/services/cable.js'
import { OpenC3Api } from '@openc3/tool-common/src/services/openc3-api'
import OpenConfigDialog from '@openc3/tool-common/src/components/OpenConfigDialog'
import SaveConfigDialog from '@openc3/tool-common/src/components/SaveConfigDialog'

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
      api: new OpenC3Api(),
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
