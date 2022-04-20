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
    <v-row dense>
      <v-col>
        <v-text-field
          v-model="startDate"
          label="Start Date"
          type="date"
          :rules="[rules.required]"
          data-test="start-date"
        />
      </v-col>
      <v-col>
        <v-text-field
          v-model="startTime"
          label="Start Time"
          type="time"
          step="1"
          :rules="[rules.required]"
          data-test="start-time"
        />
      </v-col>
      <v-col>
        <v-text-field
          v-model="endDate"
          label="End Date"
          type="date"
          :rules="endTime ? [rules.required] : []"
          data-test="end-date"
        />
      </v-col>
      <v-col>
        <v-text-field
          v-model="endTime"
          label="End Time"
          type="time"
          step="1"
          :rules="endDate ? [rules.required] : []"
          data-test="end-time"
        />
      </v-col>
      <v-col cols="auto" class="pt-4">
        <v-btn
          v-if="running"
          color="red"
          width="100"
          data-test="stop-button"
          @click="stop"
        >
          Stop
        </v-btn>
        <v-btn
          v-else
          :disabled="!canStart"
          color="green"
          width="100"
          data-test="start-button"
          @click="start"
        >
          Start
        </v-btn>
      </v-col>
    </v-row>
    <div class="mb-3" v-show="warning || error || connectionFailure">
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
    <v-card>
      <v-tabs ref="tabs" v-model="curTab">
        <v-tab
          v-for="(tab, index) in config.tabs"
          :key="index"
          @contextmenu="(event) => tabMenu(event, index)"
          data-test="tab"
        >
          {{ tab.name }}
        </v-tab>
        <v-btn class="mt-2 ml-2" @click="addTab" icon data-test="new-tab">
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
            <v-divider />
            <v-card-title class="pa-3">
              <span v-text="packetTitle(packet)" />
              <v-spacer />
              <v-btn
                @click="() => deleteComponent(index, packetIndex)"
                icon
                data-test="delete-packet"
              >
                <v-icon color="red">mdi-delete</v-icon>
              </v-btn>
            </v-card-title>
            <dump-component
              v-if="packet.component === 'DumpComponent'"
              v-show="receivedPackets[topicKey(packet)]"
              :ref="`${topicKey(packet)}-display`"
              :config="packet.config"
              @config-change="(newConfig) => (packet.config = newConfig)"
            />
            <v-card-text v-else>
              <v-alert type="error">
                Component missing:
                <span class="text-component-missing-name">
                  {{ packet.component }}
                </span>
              </v-alert>
            </v-card-text>
            <v-card-text v-if="!receivedPackets[topicKey(packet)]">
              No data! Make sure to hit the START button!
            </v-card-text>
          </v-card>
          <v-card v-if="!tab.packets.length">
            <v-card-title> This tab is empty </v-card-title>
            <v-card-text>
              Click the button below to add packets. Right click on the tab name
              above to rename or delete this tab.
            </v-card-text>
          </v-card>
          <v-btn
            block
            @click="() => openComponentDialog(index)"
            data-test="new-packet"
          >
            <v-icon class="mr-2">$astro-add-large</v-icon>
            Click here to add a packet
          </v-btn>
        </v-tab-item>
      </v-tabs-items>
      <v-card v-if="!config.tabs.length">
        <v-card-title>You're not viewing any packets</v-card-title>
        <v-card-text>Click the new tab icon to start.</v-card-text>
      </v-card>
    </v-card>
    <!-- Dialogs for opening and saving configs -->
    <open-config-dialog
      v-if="openConfig"
      v-model="openConfig"
      :tool="toolName"
      @success="openConfiguration($event)"
    />
    <save-config-dialog
      v-if="saveConfig"
      v-model="saveConfig"
      :tool="toolName"
      @success="saveConfiguration($event)"
    />
    <!-- Dialog for renaming a new tab -->
    <v-dialog v-model="tabNameDialog" width="600">
      <v-card>
        <v-system-bar>
          <v-spacer />
          <span> DataViewer: Rename Tab</span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <v-text-field
            v-model="newTabName"
            label="Tab name"
            data-test="rename-tab-input"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn
            outlined
            class="mx-2"
            data-test="cancel-rename"
            @click="cancelTabRename"
          >
            Cancel
          </v-btn>
          <v-btn
            color="primary"
            class="mx-2"
            data-test="rename"
            :disabled="!newTabName"
            @click="renameTab"
          >
            Rename
          </v-btn>
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
        <v-list-item data-test="context-menu-rename">
          <v-list-item-title style="cursor: pointer" @click="openTabNameDialog">
            Rename
          </v-list-item-title>
        </v-list-item>
        <v-list-item data-test="context-menu-delete">
          <v-list-item-title style="cursor: pointer" @click="deleteTab">
            Delete
          </v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>
    <!-- Dialog for adding a new component to a tab -->
    <add-component-dialog
      v-model="showAddComponentDialog"
      @add="addComponent"
      @cancel="cancelAddComponent"
    />
  </div>
</template>

<script>
import { format, isValid, parse } from 'date-fns'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import OpenConfigDialog from '@cosmosc2/tool-common/src/components/OpenConfigDialog'
import SaveConfigDialog from '@cosmosc2/tool-common/src/components/SaveConfigDialog'
import TargetPacketItemChooser from '@cosmosc2/tool-common/src/components/TargetPacketItemChooser'
import Cable from '@cosmosc2/tool-common/src/services/cable.js'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'

import DumpComponent from '@/tools/DataViewer/DumpComponent'
import AddComponentDialog from '@/tools/DataViewer/AddComponentDialog'

export default {
  components: {
    AddComponentDialog,
    OpenConfigDialog,
    SaveConfigDialog,
    DumpComponent,
    TopBar,
  },
  data() {
    return {
      title: 'Data Viewer',
      toolName: 'data-viewer',
      openConfig: false,
      saveConfig: false,
      api: null,
      cable: new Cable(),
      subscription: null,
      startDate: format(new Date(), 'yyyy-MM-dd'),
      startTime: format(new Date(), 'HH:mm:ss'),
      endDate: '',
      endTime: '',
      rules: {
        required: (value) => !!value || 'Required',
      },
      canStart: false,
      running: false,
      curTab: null,
      receivedPackets: {},
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Open Configuration',
              icon: 'mdi-folder-open',
              command: () => {
                this.openConfig = true
              },
            },
            {
              label: 'Save Configuration',
              icon: 'mdi-content-save',
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
      tabNameDialog: false,
      newTabName: '',
      showTabMenu: false,
      tabMenuX: 0,
      tabMenuY: 0,
      activeTab: 0,
      showAddComponentDialog: false,
    }
  },
  computed: {
    startEndTime: function () {
      return {
        start_time:
          new Date(this.startDate + ' ' + this.startTime).getTime() * 1_000_000,
        end_time: this.endDate
          ? new Date(this.endDate + ' ' + this.endTime).getTime() * 1_000_000
          : null,
      }
    },
    allPackets: function () {
      return this.config.tabs.flatMap((tab) => {
        return tab.packets
      })
    },
  },
  watch: {
    'config.tabs.length': function () {
      this.resizeTabs()
    },
  },
  created() {
    this.api = new CosmosApi()
    this.subscribe()
  },
  mounted: function () {
    const previousConfig = localStorage['lastconfig__data_viewer']
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
    packetTitle: function (packet) {
      return `${packet.target} ${packet.packet} [ ${packet.mode} ]`
    },
    resizeTabs: function () {
      if (this.$refs.tabs) this.$refs.tabs.onResize()
    },
    start: function () {
      // Check for a future start time
      if (new Date(this.startDate + ' ' + this.startTime) > Date.now()) {
        this.warningText = 'Start date/time is in the future!'
        this.warning = true
        return
      }
      // Check for an empty time period
      if (this.startEndTime.start_time === this.startEndTime.end_time) {
        this.warningText = 'Start date/time is equal to end date/time!'
        this.warning = true
        return
      }
      // Check for a future End Time
      if (new Date(this.endDate + ' ' + this.endTime) > Date.now()) {
        this.warningText =
          'Note: End date/time is greater than current date/time. Data will continue to stream in real-time until ' +
          this.endDate +
          ' ' +
          this.endTime +
          ' is reached.'
        this.warning = true
      }
      this.running = true
      this.addPacketsToSubscription()
    },
    stop: function () {
      this.running = false
      this.removePacketsFromSubscription()
    },
    subscribe: function () {
      this.cable
        .createSubscription('StreamingChannel', localStorage.scope, {
          received: (data) => this.received(data),
          connected: () => {
            this.canStart = true
            this.connectionFailure = false
          },
          disconnected: () => {
            this.stop()
            this.canStart = false
            this.warningText = 'COSMOS backend connection disconnected.'
            this.warning = true
            this.connectionFailure = true
          },
          rejected: () => {
            this.warningText = 'COSMOS backend connection rejected.'
            this.warning = true
          },
        })
        .then((subscription) => {
          this.subscription = subscription
          if (this.running) this.addPacketsToSubscription()
        })
    },
    addPacketsToSubscription: function (packets) {
      packets = packets || this.allPackets
      // Group by mode
      const modeGroups = packets.reduce((groups, packet) => {
        if (groups[packet.mode]) {
          groups[packet.mode].push(packet)
        } else {
          groups[packet.mode] = [packet]
        }
        return groups
      }, {})
      CosmosAuth.updateToken(CosmosAuth.defaultMinValidity).then(() => {
        Object.keys(modeGroups).forEach((mode) => {
          this.subscription.perform('add', {
            scope: localStorage.scope,
            token: localStorage.cosmosToken,
            packets: modeGroups[mode].map(this.subscriptionKey),
            mode: mode,
            ...this.startEndTime,
          })
        })
      })
    },
    removePacketsFromSubscription: function (packets) {
      packets = packets || this.allPackets
      this.subscription.perform('remove', {
        scope: localStorage.scope,
        packets: packets.map(this.subscriptionKey),
      })
    },
    received: function (json_data) {
      if (json_data['error']) {
        this.errorText = json_data['error']
        this.error = true
        return
      }
      const parsed = JSON.parse(json_data)
      if (!parsed.length) {
        this.stop()
        return
      }
      const groupedPackets = parsed.reduce((groups, packet) => {
        if (groups[packet.packet]) {
          groups[packet.packet].push(packet)
        } else {
          groups[packet.packet] = [packet]
        }
        return groups
      }, {})
      Object.keys(groupedPackets).forEach((packetName) => {
        this.$refs[`${packetName}-display`].forEach((component) => {
          component.receive(groupedPackets[packetName])
        })
        this.receivedPackets[packetName] = true
      })
      this.receivedPackets = { ...this.receivedPackets }
    },
    topicKey: function (packet) {
      let key = 'DEFAULT__'
      if (packet.cmdOrTlm === 'tlm') {
        key += packet.mode === 'DECOM' ? 'DECOM' : 'TELEMETRY'
      } else {
        key += packet.mode === 'DECOM' ? 'DECOMCMD' : 'COMMAND'
      }
      key += `__${packet.target}__${packet.packet}`
      if (packet.mode === 'DECOM') key += `__${packet.valueType}`
      return key
    },
    subscriptionKey: function (packet) {
      const cmdOrTlm = packet.cmdOrTlm.toUpperCase()
      let key = `${cmdOrTlm}__${packet.target}__${packet.packet}`
      if (packet.mode === 'DECOM') key += `__${packet.valueType}`
      return key
    },
    openConfiguration: async function (name) {
      localStorage['lastconfig__data_viewer'] = name
      if (this.subscription) this.removePacketsFromSubscription()
      this.receivedPackets = {}
      let response = await this.api.load_config(this.toolName, name)
      if (response) {
        this.config = JSON.parse(response)
      }
      if (this.subscription && this.running) this.addPacketsToSubscription()
    },
    saveConfiguration: function (name) {
      localStorage['lastconfig__data_viewer'] = name
      this.api.save_config(this.toolName, name, JSON.stringify(this.config))
    },
    addTab: function () {
      this.config.tabs.push({
        // name: this.newTabName,
        name: 'New Tab',
        packets: [],
      })
      this.cancelTabRename()
    },
    cancelTabRename: function () {
      this.tabNameDialog = false
      this.newTabName = ''
    },
    tabMenu: function (event, index) {
      this.activeTab = index
      event.preventDefault()
      this.showTabMenu = false
      this.tabMenuX = event.clientX
      this.tabMenuY = event.clientY
      this.$nextTick(() => {
        this.showTabMenu = true
      })
    },
    openTabNameDialog: function () {
      this.newTabName = this.config.tabs[this.activeTab].name
      this.tabNameDialog = true
    },
    renameTab: function () {
      this.config.tabs[this.activeTab].name = this.newTabName
      this.tabNameDialog = false
    },
    deleteTab: function () {
      this.config.tabs.splice(this.activeTab, 1)
    },
    openComponentDialog: function (index) {
      this.activeTab = index
      this.showAddComponentDialog = true
    },
    packetSelected: function (event) {
      this.newPacket = {
        target: event.targetName,
        packet: event.packetName,
        cmdOrTlm: this.newPacketCmdOrTlm,
      }
    },
    addComponent: function (event) {
      this.config.tabs[this.activeTab].packets.push(event)
      if (this.running) {
        this.addPacketsToSubscription([event])
      }
      this.cancelAddComponent()
    },
    cancelAddComponent: function (event) {
      this.showAddComponentDialog = false
    },
    deleteComponent: function (tabIndex, packetIndex) {
      const packet = this.config.tabs[tabIndex].packets[packetIndex]
      this.config.tabs[tabIndex].packets.splice(packetIndex, 1)
      this.removePacketsFromSubscription([packet])
    },
  },
}
</script>

<style scoped>
.text-component-missing-name {
  font-family: 'Courier New', Courier, monospace;
}

.v-tabs-items {
  overflow: visible;
}
</style>
