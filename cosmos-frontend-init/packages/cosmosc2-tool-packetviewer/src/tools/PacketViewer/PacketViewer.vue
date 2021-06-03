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
    <top-bar :menus="menus" :title="title" />
    <v-container>
      <v-row no-gutters>
        <v-col>
          <target-packet-item-chooser
            :initialTargetName="this.$route.params.target"
            :initialPacketName="this.$route.params.packet"
            @on-set="packetChanged($event)"
          />
        </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col>
          <v-card>
            <v-card-title>
              Items
              <v-spacer />
              <v-text-field
                v-model="search"
                append-icon="$astro-search"
                label="Search"
                single-line
                hide-details
              />
            </v-card-title>
            <v-data-table
              :headers="headers"
              :items="rows"
              :search="search"
              calculate-widths
              disable-pagination
              hide-default-footer
              multi-sort
              dense
            >
              <template v-slot:item.index="{ item }">
                <span>
                  {{
                    rows
                      .map(function (x) {
                        return x.name
                      })
                      .indexOf(item.name)
                  }}
                </span>
              </template>
              <template v-slot:item.value="{ item }">
                <value-widget
                  :value="item.value"
                  :limitsState="item.limitsState"
                  :parameters="[targetName, packetName, item.name]"
                  :settings="['WIDTH', '50']"
                />
              </template>
            </v-data-table>
          </v-card>
        </v-col>
      </v-row>
    </v-container>

    <v-dialog
      v-model="optionsDialog"
      @keydown.esc="optionsDialog = false"
      max-width="300"
    >
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
        />
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import ValueWidget from '@cosmosc2/tool-common/src/components/widgets/ValueWidget'
import TargetPacketItemChooser from '@cosmosc2/tool-common/src/components/TargetPacketItemChooser'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'

export default {
  components: {
    TargetPacketItemChooser,
    ValueWidget,
    TopBar,
  },
  data() {
    return {
      title: 'Packet Viewer',
      search: '',
      data: [],
      headers: [
        { text: 'Index', value: 'index' },
        { text: 'Name', value: 'name' },
        { text: 'Value', value: 'value' },
      ],
      optionsDialog: false,
      hideIgnored: false,
      derivedLast: false,
      ignoredItems: [],
      derivedItems: [],
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
        {
          label: 'View',
          radioGroup: 'Formatted Items with Units', // Default radio selected
          items: [
            {
              label: 'Hide Ignored Items',
              checkbox: true,
              command: () => {
                this.hideIgnored = !this.hideIgnored
              },
            },
            {
              label: 'Display Derived Last',
              checkbox: true,
              command: () => {
                this.derivedLast = !this.derivedLast
              },
            },
            {
              divider: true,
            },
            {
              label: 'Formatted Items with Units',
              radio: true,
              command: () => {
                this.valueType = 'WITH_UNITS'
              },
            },
            {
              label: 'Formatted Items',
              radio: true,
              command: () => {
                this.valueType = 'FORMATTED'
              },
            },
            {
              label: 'Converted Items',
              radio: true,
              command: () => {
                this.valueType = 'CONVERTED'
              },
            },
            {
              label: 'Raw Items',
              radio: true,
              command: () => {
                this.valueType = 'RAW'
              },
            },
          ],
        },
      ],
      updater: null,
      targetName: '',
      packetName: '',
      valueType: 'WITH_UNITS',
      refreshInterval: 1000,
      rows: [],
      menuItems: [],
      api: null,
    }
  },
  watch: {
    // Create a watcher on refreshInterval so we can change the updater
    refreshInterval: function (newValue, oldValue) {
      this.changeUpdater(false)
    },
  },
  created() {
    this.api = new CosmosApi()
    // If we're passed in the route then manually call packetChanged to update
    if (this.$route.params.target) {
      this.packetChanged({
        targetName: this.$route.params.target,
        packetName: this.$route.params.packet,
      })
    }
  },
  // TODO: This doesn't seem to be called / covered when running cypress tests?
  beforeDestroy() {
    if (this.updater != null) {
      clearInterval(this.updater)
      this.updater = null
    }
  },

  methods: {
    packetChanged(event) {
      if (
        this.targetName === event.targetName &&
        this.packetName === event.packetName
      ) {
        return
      }
      this.api.get_target(event.targetName).then((target) => {
        this.ignoredItems = target.ignored_items
      })
      this.api
        .get_packet_derived_items(event.targetName, event.packetName)
        .then((derived) => {
          this.derivedItems = derived
        })

      this.targetName = event.targetName
      this.packetName = event.packetName
      if (
        this.$route.params.target !== event.targetName ||
        this.$route.params.packet !== event.packetName
      ) {
        this.$router.push({
          name: 'PackerViewer',
          params: {
            target: this.targetName,
            packet: this.packetName,
          },
        })
      }
      this.changeUpdater(true)
    },

    changeUpdater(clearExisting) {
      if (this.updater != null) {
        clearInterval(this.updater)
        this.updater = null
      }

      if (clearExisting) {
        this.rows = []
      }

      this.updater = setInterval(() => {
        this.api
          .get_tlm_packet(this.targetName, this.packetName, this.valueType)
          .then((data) => {
            let derived = []
            let other = []
            data.forEach((value) => {
              if (this.hideIgnored && this.ignoredItems.includes(value[0])) {
                return
              }
              if (this.derivedItems.includes(value[0])) {
                derived.push({
                  name: value[0],
                  value: value[1],
                  limitsState: value[2],
                })
              } else {
                other.push({
                  name: value[0],
                  value: value[1],
                  limitsState: value[2],
                })
              }
            })
            if (this.derivedLast) {
              this.rows = other.concat(derived)
            } else {
              this.rows = derived.concat(other)
            }
          })
      }, this.refreshInterval)
    },
  },
}
</script>

<style scoped>
.container {
  background-color: var(--v-tertiary-darken2);
}
</style>
