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
      </div>
      <v-tabs v-model="curTab" fixed-tabs>
        <v-tab v-for="(tab, index) in tabs" :key="index">{{ tab.name }}</v-tab>
      </v-tabs>
      <v-tabs-items v-model="curTab">
        <v-tab-item v-for="(tab, index) in tabs" :key="index">
          <v-card
            v-for="(packet, packetIndex) in tab.packets"
            :key="`${index}-${packetIndex}`"
            flat
          >
            <v-card-title>{{ packet.target }} {{ packet.packet }}</v-card-title>
            <dump-component
              v-if="packetData[packet.key]"
              :packet="packetData[packet.key]"
            />
            <v-card-text v-else>No data</v-card-text>
          </v-card>
        </v-tab-item>
      </v-tabs-items>
    </v-card>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import { ConfigParserService } from '@/services/config-parser'
import { CosmosApi } from '@/services/cosmos-api'
import * as ActionCable from 'actioncable'
import upperFirst from 'lodash/upperFirst'
import camelCase from 'lodash/camelCase'
import DumpComponent from './DumpComponent.vue'

export default {
  components: {
    AppNav,
    DumpComponent,
  },
  data() {
    return {
      api: null,
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel,
      configParser: null,
      curTab: null,
      tabs: [],
      packetData: {},
      updater: null,
      refreshInterval: 1000,
      optionsDialog: false,
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Reset',
              command: () => {
                this.$refs.component.forEach((child) => {
                  child.reset()
                })
              },
            },
          ],
        },
      ],
      warning: false,
      warningText: '',
      error: false,
      errorText: '',
    }
  },
  created() {
    this.api = new CosmosApi()
    this.config = `
COMPONENT "Health Status" dump_component.rb
  PACKET INST HEALTH_STATUS

COMPONENT "ADCS" data_viewer_component.rb
  PACKET INST ADCS

COMPONENT "Other Packets" data_viewer_component.rb
  PACKET INST PARAMS
  PACKET INST IMAGE

`
    // COMPONENT "Operators" text_component.rb "OPERATOR_NAME"
    //   PACKET SYSTEM META
    this.configParser = new ConfigParserService()
    this.configParser.parse_string(
      this.config,
      '',
      false,
      true,
      (keyword, parameters) => {
        if (keyword) {
          switch (keyword) {
            case 'COMPONENT':
              this.configParser.verify_num_parameters(
                2,
                null,
                `${keyword} <tab name> <component class> <component options ...>`
              )
              let componentName = parameters[1]
              if (componentName.includes('.rb')) {
                componentName = upperFirst(
                  camelCase(componentName.slice(0, -3))
                )
              }
              this.tabs.push({
                name: parameters[0],
                component: componentName,
                options: parameters.slice(2),
                packets: [],
              })
              break
            case 'PACKET':
              if (this.tabs.length === 0) throw 'Invalid configuration string'
              this.tabs[this.tabs.length - 1].packets.push({
                target: parameters[0],
                packet: parameters[1],
                key: `DEFAULT__TELEMETRY__${parameters[0]}__${parameters[1]}`,
              })
              break
          }
        }
      }
    )
    this.cable = ActionCable.createConsumer('ws://localhost:7777/cable') // TODO: handle failed connection? Seems to be a missing callback in ActionCable API
    this.subscribe()
  },
  destroyed: function () {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    subscribe: function () {
      this.subscription = this.cable.subscriptions.create(
        {
          channel: 'StreamingChannel',
          scope: 'DEFAULT',
        },
        {
          received: (data) => this.received(data),
          connected: () => {
            const packets = this.tabs.flatMap((tab) => {
              return tab.packets.map(
                (packet) => 'TLM__' + packet.target + '__' + packet.packet
              )
            })
            this.subscription.perform('add', {
              scope: 'DEFAULT',
              packets: packets,
              // start_time: 1609532973000000000, // use to hit the file cache
              start_time: Date.now() * 1000000 - 1000000000,
              end_time: Date.now() * 1000060,
              mode: 'RAW',
            })
          },
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
    received: function (json_data) {
      if (json_data['error']) {
        this.errorText = json_data['error']
        this.error = true
        return
      }
      JSON.parse(json_data).forEach((data) => {
        this.packetData[data.packet] = {
          buffer: atob(data.buffer)
            .split('')
            .map((c) => c.charCodeAt(0)),
          time: data.time,
        }
        // TODO: this causes every component to update instead of just the ones with a new packet
        // which is less than ideal, but it works for now
        this.packetData = { ...this.packetData }
      })
    },
  },
}
</script>

<style scoped></style>
