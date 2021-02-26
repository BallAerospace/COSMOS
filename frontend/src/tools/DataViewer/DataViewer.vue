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
    <v-row dense>
      <v-col>
        <v-menu
          :close-on-content-click="true"
          :nudge-right="40"
          transition="scale-transition"
          offset-y
          max-width="290px"
          min-width="290px"
        >
          <template v-slot:activator="{ on }">
            <v-text-field
              v-model="startDate"
              label="Start Date"
              v-on="on"
              prepend-icon="mdi-calendar"
              :rules="[rules.required, rules.calendar]"
              data-test="startDate"
            ></v-text-field>
          </template>
          <v-date-picker
            v-model="startDate"
            :max="endDate"
            :show-current="false"
            no-title
          ></v-date-picker>
        </v-menu>
      </v-col>
      <v-col>
        <v-text-field
          v-model="startTime"
          label="Start Time"
          prepend-icon="mdi-clock"
          :rules="[rules.required, rules.time]"
          data-test="startTime"
        ></v-text-field>
      </v-col>
      <v-col>
        <v-menu
          ref="endDatemenu"
          :close-on-content-click="true"
          :nudge-right="40"
          transition="scale-transition"
          offset-y
          max-width="290px"
          min-width="290px"
        >
          <template v-slot:activator="{ on }">
            <v-text-field
              v-model="endDate"
              label="End Date"
              v-on="on"
              prepend-icon="mdi-calendar"
              :rules="
                endTime ? [rules.required, rules.calendar] : [rules.calendar]
              "
              data-test="endDate"
            ></v-text-field>
          </template>
          <v-date-picker
            v-model="endDate"
            :min="startDate"
            :show-current="false"
            no-title
          ></v-date-picker>
        </v-menu>
      </v-col>
      <v-col>
        <v-text-field
          v-model="endTime"
          label="End Time"
          prepend-icon="mdi-clock"
          :rules="endDate ? [rules.required, rules.time] : [rules.time]"
          data-test="endTime"
        ></v-text-field>
      </v-col>
      <v-col cols="auto" class="pt-4">
        <v-btn v-if="running" color="red" width="86" @click="stop">
          Stop
        </v-btn>
        <v-btn
          v-else
          color="green"
          width="86"
          :disabled="!canStart"
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
            <v-divider />
            <v-card-title class="pa-3">
              {{ packet.target }} {{ packet.packet }}
              <v-spacer />
              <v-btn @click="() => deleteComponent(index, packetIndex)" icon>
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
    <v-dialog v-model="addComponentDialog" width="900">
      <v-card>
        <v-card-title> Add a packet </v-card-title>
        <v-card-text>
          <v-row>
            <v-col>
              <TargetPacketItemChooser @on-set="packetSelected($event)" />
            </v-col>
            <v-col>
              <v-row>
                <v-col>
                  <v-radio-group v-model="newPacketMode" row>
                    <v-radio label="Raw" value="RAW" />
                    <v-radio label="Decom" value="DECOM" />
                  </v-radio-group>
                </v-col>
                <v-col>
                  <v-select
                    v-if="newPacketMode === 'DECOM'"
                    hide-details
                    :items="valueTypes"
                    label="Value Type"
                    v-model="newPacketValueType"
                  ></v-select>
                </v-col>
              </v-row>
            </v-col>
          </v-row>
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
import { format, isValid, parse } from 'date-fns'
import AppNav from '@/AppNav'
import * as ActionCable from 'actioncable'
import { CosmosApi } from '@/services/cosmos-api'
import OpenConfigDialog from '@/components/OpenConfigDialog'
import SaveConfigDialog from '@/components/SaveConfigDialog'
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'
import DumpComponent from './DumpComponent'

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
      startDate: format(new Date(), 'yyyy-MM-dd'),
      startTime: format(new Date(), 'HH:mm:ss'),
      endDate: '',
      endTime: '',
      rules: {
        required: (value) => !!value || 'Required',
        calendar: (value) => {
          try {
            return (
              value === '' ||
              isValid(parse(value, 'yyyy-MM-dd', new Date())) ||
              'Invalid date (YYYY-MM-DD)'
            )
          } catch (e) {
            return 'Invalid date (YYYY-MM-DD)'
          }
        },
        time: (value) => {
          try {
            return (
              value === '' ||
              isValid(parse(value, 'HH:mm:ss', new Date())) ||
              'Invalid time (HH:MM:SS)'
            )
          } catch (e) {
            return 'Invalid time (HH:MM:SS)'
          }
        },
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
      newPacketMode: 'RAW',
      valueTypes: ['CONVERTED', 'RAW', 'FORMATTED', 'WITH_UNITS'],
      newPacketValueType: 'WITH_UNITS',
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
      this.subscription = this.cable.subscriptions.create(
        {
          channel: 'StreamingChannel',
          scope: 'DEFAULT',
        },
        {
          received: (data) => this.received(data),
          connected: () => {
            this.canStart = true
          },
          disconnected: () => {
            this.stop()
            this.canStart = false
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
      Object.keys(modeGroups).forEach((mode) => {
        this.subscription.perform('add', {
          scope: 'DEFAULT',
          packets: modeGroups[mode].map(this.subscriptionKey),
          mode: mode,
          ...this.startEndTime,
        })
      })
    },
    removePacketsFromSubscription: function (packets) {
      packets = packets || this.allPackets
      this.subscription.perform('remove', {
        scope: 'DEFAULT',
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
      key += packet.mode === 'DECOM' ? 'DECOM' : 'TELEMETRY'
      key += `__${packet.target}__${packet.packet}`
      if (packet.mode === 'DECOM') key += `__${packet.valueType}`
      return key
    },
    subscriptionKey: function (packet) {
      let key = `TLM__${packet.target}__${packet.packet}`
      if (packet.mode === 'DECOM') key += `__${packet.valueType}`
      return key
    },
    openConfiguration: async function (name) {
      localStorage.lastDataViewerConfig = name
      this.removePacketsFromSubscription()
      this.receivedPackets = {}
      let response = await this.api.load_config(this.toolName, name)
      if (response) {
        this.config = JSON.parse(response)
      }
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
      let packet = {
        ...this.newPacket,
        mode: this.newPacketMode,
        component: 'DumpComponent',
        config: {},
      }
      if (this.newPacketMode !== 'RAW') {
        packet.valueType = this.newPacketValueType
      }
      this.config.tabs[this.activeTab].packets.push(packet)
      if (this.running) {
        this.addPacketsToSubscription([packet])
      }
      this.cancelAddComponent()
    },
    cancelAddComponent: function () {
      this.addComponentDialog = false
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
