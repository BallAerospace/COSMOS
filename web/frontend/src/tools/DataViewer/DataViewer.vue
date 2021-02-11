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
    <app-nav app :menus="menus" />
    <v-card :key="renderKey">
      <div class="mb-1">
        <v-alert type="warning" v-model="warning" dismissible>
          {{ warningText }}
        </v-alert>
        <v-alert type="error" v-model="error" dismissible>
          {{ errorText }}
        </v-alert>
        <v-alert type="error" v-model="connectionFailure">
          COSMOS backend connection failed.
        </v-alert>
      </div>
      <v-tabs ref="tabs" v-model="curTab">
        <v-tab v-for="(tab, index) in config.tabs" :key="index">
          {{ tab.name }}
        </v-tab>
      </v-tabs>
      <v-tabs-items v-model="curTab">
        <v-tab-item v-for="(tab, index) in config.tabs" :key="index" eager>
          <v-card
            v-for="(packet, packetIndex) in tab.packets"
            :key="`${index}-${packetIndex}`"
            flat
          >
            <v-card-title>{{ packet.target }} {{ packet.packet }}</v-card-title>
            <dump-component
              v-show="receivedPackets[subscriptionKey(packet)]"
              :ref="`${subscriptionKey(packet)}-display`"
              :config="packet.config"
              v-on:config-change="(newConfig) => (packet.config = newConfig)"
            />
            <v-card-text v-if="!receivedPackets[subscriptionKey(packet)]">
              No data
            </v-card-text>
          </v-card>
        </v-tab-item>
      </v-tabs-items>
    </v-card>
    <OpenConfigDialog
      v-if="openConfig"
      v-model="openConfig"
      :tool="toolName"
      @success="openConfiguration($event)"
    />
    <SaveConfigDialog
      v-if="saveConfig"
      v-model="saveConfig"
      :tool="toolName"
      @success="saveConfiguration($event)"
    />
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import * as ActionCable from 'actioncable'
import { CosmosApi } from '@/services/cosmos-api'
import OpenConfigDialog from '@/components/OpenConfigDialog'
import SaveConfigDialog from '@/components/SaveConfigDialog'
import DumpComponent from './DumpComponent.vue'

export default {
  components: {
    AppNav,
    OpenConfigDialog,
    SaveConfigDialog,
    DumpComponent,
  },
  data() {
    return {
      toolName: 'data-viewer',
      openConfig: false,
      saveConfig: false,
      api: null,
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel,
      curTab: null,
      receivedPackets: {},
      menus: [
        {
          label: 'File',
          items: [
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
      warning: false,
      warningText: '',
      error: false,
      errorText: '',
      connectionFailure: false,
      renderKey: 0,
      config: {
        tabs: [
          {
            name: 'Health Status',
            packets: [
              {
                target: 'INST',
                packet: 'HEALTH_STATUS',
                component: 'DumpComponent',
                config: {
                  format: 'hex',
                  showLineAddress: false,
                  showTimestamp: false,
                  bytesPerLine: 17,
                  packetsToShow: 2,
                  newestAtTop: true,
                },
              },
            ],
          },
        ],
      },
    }
  },
  watch: {
    'config.tabs.length': function () {
      this.resizeTabs()
    },
    'cable.connection.disconnected': function (val) {
      this.connectionFailure = val
    },
  },
  created() {
    this.api = new CosmosApi()
    this.cable = ActionCable.createConsumer('ws://localhost:7777/cable')
    this.subscribe()
    setTimeout(() => {
      this.connectionFailure = this.cable.connection.disconnected
    }, 1000)
  },
  destroyed: function () {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    resizeTabs: function () {
      if (this.$refs.tabs) this.$refs.tabs.onResize()
    },
    subscribe: function () {
      this.subscription = this.cable.subscriptions.create(
        {
          channel: 'StreamingChannel',
          scope: 'DEFAULT',
        },
        {
          received: (data) => this.received(data),
          connected: () => this.addPacketsToSubscription(),
          disconnected: () => {
            this.warningText = 'COSMOS backend connection disconnected.'
            this.warning = true
          },
          rejected: () => {
            this.warningText = 'COSMOS backend connection rejected.'
            this.warning = true
          },
        }
      )
    },
    addPacketsToSubscription: function () {
      this.subscription.perform('add', {
        scope: 'DEFAULT',
        packets: this.subscriptionPackets,
        // start_time: 1609532973000000000, // use to hit the file cache
        start_time: Date.now() * 1000000,
        end_time: null,
        mode: 'RAW',
      })
    },
    removePacketsFromSubscription: function () {
      this.subscription.perform('remove', {
        scope: 'DEFAULT',
        packets: this.subscriptionPackets,
      })
    },
    received: function (json_data) {
      if (json_data['error']) {
        this.errorText = json_data['error']
        this.error = true
        return
      }
      const parsed = JSON.parse(json_data)
      const packetName = parsed[0].packet // everything in this message will be for the same packet
      this.$refs[`${packetName}-display`].forEach((component) => {
        component.receive(parsed)
      })
      this.receivedPackets[packetName] = true
      this.receivedPackets = { ...this.receivedPackets } // TODO: why is reactivity broken?
    },
    subscriptionKey: function (packet) {
      return `DEFAULT__TELEMETRY__${packet.target}__${packet.packet}`
    },
    async openConfiguration(name) {
      this.removePacketsFromSubscription()
      this.receivedPackets = {}
      let response = await this.api.load_config(this.toolName, name)
      this.config = JSON.parse(response)
      this.renderKey++ // Trigger re-render
      this.addPacketsToSubscription()
    },
    saveConfiguration(name) {
      this.api.save_config(this.toolName, name, JSON.stringify(this.config))
    },
  },
  computed: {
    subscriptionPackets: function () {
      return this.config.tabs.flatMap((tab) => {
        return tab.packets.map(
          (packet) => 'TLM__' + packet.target + '__' + packet.packet
        )
      })
    },
  },
}
</script>

<style scoped></style>
