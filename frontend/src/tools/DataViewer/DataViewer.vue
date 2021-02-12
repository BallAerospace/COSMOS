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
    <v-card>
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
        <v-tab
          v-for="(tab, index) in config.tabs"
          :key="index"
          @contextmenu="(event) => tabMenu(event, index)"
        >
          {{ tab.name }}
        </v-tab>
        <v-btn class="mt-2 ml-2" @click="openTabDialog" icon>
          <v-icon>mdi-tab-plus</v-icon>
        </v-btn>
      </v-tabs>
      <v-tabs-items v-model="curTab">
        <v-tab-item v-for="(tab, index) in config.tabs" :key="index" eager>
          <v-card
            v-for="(packet, packetIndex) in tab.packets"
            :key="`${index}-${packetIndex}`"
            flat
          >
            <v-card-title>
              {{ packet.target }} {{ packet.packet }}
              <v-spacer />
              <v-btn @click="() => deleteComponent(index, packetIndex)" icon>
                <v-icon color="red">mdi-delete</v-icon>
              </v-btn>
            </v-card-title>
            <dump-component
              v-show="receivedPackets[topicKey(packet)]"
              :ref="`${topicKey(packet)}-display`"
              :config="packet.config"
              @config-change="(newConfig) => (packet.config = newConfig)"
            />
            <v-card-text v-if="!receivedPackets[topicKey(packet)]">
              No data
            </v-card-text>
          </v-card>
          <v-btn block @click="() => openComponentDialog(index)">
            <v-icon class="mr-2">mdi-plus-circle</v-icon>
            Click here to add a packet
          </v-btn>
        </v-tab-item>
      </v-tabs-items>
      <v-card v-if="!config.tabs.length">
        <v-card-title>You're not viewing any packets</v-card-title>
        <v-card-text>Click the new tab icon to start</v-card-text>
      </v-card>
    </v-card>
    <!-- Dialogs for opening and saving configs -->
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
    <!-- Dialog for adding a new tab -->
    <v-dialog v-model="addTabDialog" width="500">
      <v-card>
        <v-card-title> Add a tab </v-card-title>
        <v-card-text>
          <v-text-field v-model="newTabName" label="Tab name" />
        </v-card-text>
        <v-divider></v-divider>
        <v-card-actions>
          <v-btn color="primary" text @click="addTab"> Add </v-btn>
          <v-btn color="primary" text @click="cancelAddTab"> Cancel </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <!-- Menu for right clicking on a tab -->
    <v-menu
      v-model="showTabMenu"
      :position-x="tabMenuX"
      :position-y="tabMenuY"
      absolute
      offset-y
    >
      <v-list>
        <v-list-item>
          <v-list-item-title style="cursor: pointer" @click="deleteTab">
            Close tab
          </v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>
    <!-- Dialog for adding a new component to a tab -->
    <v-dialog v-model="addComponentDialog">
      <v-card>
        <v-card-title> Add a packet </v-card-title>
        <v-card-text>
          <TargetPacketItemChooser @on-set="packetSelected($event)" />
        </v-card-text>
        <v-divider></v-divider>
        <v-card-actions>
          <v-btn color="primary" text @click="addComponent"> Add </v-btn>
          <v-btn color="primary" text @click="cancelAddComponent">
            Cancel
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import * as ActionCable from 'actioncable'
import { CosmosApi } from '@/services/cosmos-api'
import OpenConfigDialog from '@/components/OpenConfigDialog'
import SaveConfigDialog from '@/components/SaveConfigDialog'
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'
import DumpComponent from './DumpComponent.vue'

export default {
  components: {
    AppNav,
    OpenConfigDialog,
    SaveConfigDialog,
    TargetPacketItemChooser,
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
      config: {
        tabs: [],
      },
      addTabDialog: false,
      newTabName: '',
      showTabMenu: false,
      tabMenuX: 0,
      tabMenuY: 0,
      adtiveTab: 0,
      addComponentDialog: false,
      newPacket: null,
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
  mounted: function () {
    const previousConfig = localStorage.lastDataViewerConfig // TODO: Do we want to use localStorage for this?
    if (previousConfig) {
      this.openConfiguration(previousConfig)
    }
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
    addPacketsToSubscription: function (packets) {
      this.subscription.perform('add', {
        scope: 'DEFAULT',
        packets: packets || this.allPacketSubscriptionKeys,
        // start_time: 1609532973000000000, // use to hit the file cache
        start_time: Date.now() * 1000000,
        end_time: null,
        mode: 'RAW',
      })
    },
    removePacketsFromSubscription: function (packets) {
      this.subscription.perform('remove', {
        scope: 'DEFAULT',
        packets: packets || this.allPacketSubscriptionKeys,
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
    topicKey: function (packet) {
      return `DEFAULT__TELEMETRY__${packet.target}__${packet.packet}`
    },
    subscriptionKey: function (packet) {
      return `TLM__${packet.target}__${packet.packet}`
    },
    openConfiguration: async function (name) {
      localStorage.lastDataViewerConfig = name
      this.removePacketsFromSubscription()
      this.receivedPackets = {}
      let response = await this.api.load_config(this.toolName, name)
      this.config = JSON.parse(response)
      this.addPacketsToSubscription()
    },
    saveConfiguration: function (name) {
      localStorage.lastDataViewerConfig = name
      this.api.save_config(this.toolName, name, JSON.stringify(this.config))
    },
    openTabDialog: function () {
      this.addTabDialog = true
    },
    addTab: function () {
      this.config.tabs.push({
        name: this.newTabName,
        packets: [],
      })
      this.cancelAddTab()
    },
    cancelAddTab: function () {
      this.addTabDialog = false
      this.newTabName = ''
    },
    tabMenu: function (event, index) {
      this.adtiveTab = index
      event.preventDefault()
      this.showTabMenu = false
      this.tabMenuX = event.clientX
      this.tabMenuY = event.clientY
      this.$nextTick(() => {
        this.showTabMenu = true
      })
    },
    deleteTab: function () {
      this.config.tabs.splice(this.adtiveTab, 1)
    },
    openComponentDialog: function (index) {
      this.activeTab = index
      this.addComponentDialog = true
    },
    packetSelected: function (event) {
      this.newPacket = {
        target: event.targetName,
        packet: event.packetName,
      }
    },
    addComponent: function () {
      const packet = {
        ...this.newPacket,
        component: 'DumpComponent',
        config: {},
      }
      this.config.tabs[this.activeTab].packets.push(packet)
      this.addPacketsToSubscription([this.subscriptionKey(packet)])
      this.cancelAddComponent()
    },
    cancelAddComponent: function () {
      this.addComponentDialog = false
      this.newPacket = null
    },
    deleteComponent: function (tabIndex, packetIndex) {
      const packet = this.config.tabs[tabIndex].packets[packetIndex]
      this.config.tabs[tabIndex].packets.splice(packetIndex, 1)
      this.removePacketsFromSubscription([this.subscriptionKey(packet)])
    },
  },
  computed: {
    allPacketSubscriptionKeys: function () {
      return this.config.tabs.flatMap((tab) => {
        return tab.packets.map(this.subscriptionKey)
      })
    },
  },
}
</script>

<style scoped></style>
