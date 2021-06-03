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
      <v-row>
        <v-col>
          <v-text-field
            v-model="startDate"
            label="Start Date"
            type="date"
            :rules="[rules.required]"
            data-test="startDate"
          />
          <v-text-field
            v-model="endDate"
            label="End Date"
            type="date"
            :rules="[rules.required]"
            data-test="endDate"
          />
        </v-col>
        <v-col>
          <v-text-field
            v-model="startTime"
            label="Start Time"
            type="time"
            :rules="[rules.required]"
            data-test="startTime"
          >
          </v-text-field>
          <v-text-field
            v-model="endTime"
            label="End Time"
            type="time"
            :rules="[rules.required]"
            data-test="endTime"
          >
          </v-text-field>
        </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col>
          <v-radio-group v-model="cmdOrTlm" row hide-details class="mt-0">
            <v-radio label="Command" value="cmd" data-test="cmd-radio" />
            <v-radio label="Telemetry" value="tlm" data-test="tlm-radio" />
          </v-radio-group>
        </v-col>
        <v-col>
          <v-radio-group v-model="utcOrLocal" row hide-details class="mt-0">
            <v-radio label="Local" value="loc" data-test="local-radio" />
            <v-radio label="UTC" value="utc" data-test="utc-radio" />
          </v-radio-group>
        </v-col>
      </v-row>
      <v-row>
        <div class="c-tlmgrapher__contents">
          <target-packet-item-chooser
            @click="addItem($event)"
            buttonText="Add Item"
            :mode="cmdOrTlm"
            :chooseItem="true"
            :allowAll="true"
          />
          <v-alert type="warning" v-model="warning" dismissible
            >{{ warningText }}
          </v-alert>
          <v-alert type="error" v-model="error" dismissible
            >{{ errorText }}
          </v-alert>
        </div>
      </v-row>
      <v-row>
        <v-col>
          <v-card scrollable>
            <v-progress-linear
              absolute
              top
              height="10"
              :value="progress"
              color="secondary"
            />
            <v-list data-test="itemList">
              <v-subheader class="mt-3">
                Items
                <v-spacer />
                <v-btn class="primary mr-4" @click="processItems">
                  {{ processButtonText }}
                </v-btn>
                <v-tooltip bottom>
                  <template v-slot:activator="{ on, attrs }">
                    <v-btn
                      icon
                      @click="editAll = true"
                      v-bind="attrs"
                      v-on="on"
                      data-test="editAll"
                      ><v-icon>mdi-pencil</v-icon></v-btn
                    >
                  </template>
                  <span>Edit All Items</span>
                </v-tooltip>
                <v-tooltip bottom>
                  <template v-slot:activator="{ on, attrs }">
                    <v-btn
                      icon
                      @click="deleteAll"
                      v-bind="attrs"
                      v-on="on"
                      data-test="deleteAll"
                      ><v-icon>mdi-delete</v-icon></v-btn
                    >
                  </template>
                  <span>Delete All Items</span>
                </v-tooltip>
              </v-subheader>
              <v-list-item v-for="(item, i) in items" :key="i">
                <v-list-item-icon>
                  <v-tooltip bottom>
                    <template v-slot:activator="{ on, attrs }">
                      <v-icon
                        @click.stop="item.edit = true"
                        v-bind="attrs"
                        v-on="on"
                        >mdi-pencil</v-icon
                      >
                    </template>
                    <span>Edit Item</span>
                  </v-tooltip>
                  <v-dialog
                    v-model="item.edit"
                    @keydown.esc="item.edit = false"
                    max-width="700"
                  >
                    <v-card>
                      <v-card-title>Edit {{ getItemLabel(item) }}</v-card-title>
                      <v-card-text>
                        <v-col>
                          <v-select
                            hide-details
                            :items="valueTypes"
                            label="Value Type"
                            outlined
                            v-model="item.valueType"
                          />
                        </v-col>
                        <!-- v-col v-if="uniqueOnly">
                          <v-select
                            :items="uniqueIgnoreOptions"
                            label="Add to Unique Ignore List?:"
                            outlined
                            v-model="item.uniqueIgnoreAdd"
                          />
                        </v-col -->
                      </v-card-text>
                      <v-card-actions>
                        <v-spacer />
                        <v-btn color="primary" text @click="item.edit = false">
                          Ok
                        </v-btn>
                      </v-card-actions>
                    </v-card>
                  </v-dialog>
                </v-list-item-icon>
                <v-list-item-content>
                  <v-list-item-title v-text="getItemLabel(item)" />
                </v-list-item-content>
                <v-list-item-icon>
                  <v-tooltip bottom>
                    <template v-slot:activator="{ on, attrs }">
                      <v-icon @click="deleteItem(item)" v-bind="attrs" v-on="on"
                        >mdi-delete</v-icon
                      >
                    </template>
                    <span>Delete Item</span>
                  </v-tooltip>
                </v-list-item-icon>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>
    </v-container>
    <v-dialog v-model="editAll" @keydown.esc="editAll = false" max-width="700">
      <v-card>
        <v-card-title>Edit All Items</v-card-title>
        <v-card-text
          >This will change all items to the following data type!
          <v-col>
            <v-select
              hide-details
              :items="valueTypes"
              label="Value Type"
              outlined
              v-model="allItemValueType"
            />
          </v-col>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn color="primary" text @click="editAllValueTypes()"> Ok </v-btn>
          <v-btn color="primary" text @click="editAll = false"> Cancel </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <open-config-dialog
      v-if="openConfig"
      v-model="openConfig"
      :tool="toolName"
      @success="openConfiguration($event)"
    />
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <save-config-dialog
      v-if="saveConfig"
      v-model="saveConfig"
      :tool="toolName"
      @success="saveConfiguration($event)"
    />
  </div>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import OpenConfigDialog from '@cosmosc2/tool-common/src/components/OpenConfigDialog'
import SaveConfigDialog from '@cosmosc2/tool-common/src/components/SaveConfigDialog'
import TargetPacketItemChooser from '@cosmosc2/tool-common/src/components/TargetPacketItemChooser'
import Cable from '@cosmosc2/tool-common/src/services/cable.js'
import { isValid, parse, format, getTime } from 'date-fns'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'

export default {
  components: {
    OpenConfigDialog,
    SaveConfigDialog,
    TargetPacketItemChooser,
    TopBar,
  },
  data() {
    return {
      title: 'Data Extractor',
      toolName: 'data-exporter',
      api: null,
      openConfig: false,
      saveConfig: false,
      progress: 0,
      processButtonText: 'Process',
      startDate: format(new Date(), 'yyyy-MM-dd'),
      startTime: format(new Date(), 'HH:mm:ss'),
      endTime: format(new Date(), 'HH:mm:ss'),
      endDate: format(new Date(), 'yyyy-MM-dd'),
      startDateTime: null,
      endDateTime: null,
      startDateTimeFilename: '',
      rules: {
        required: (value) => !!value || 'Required',
      },
      cmdOrTlm: 'tlm',
      utcOrLocal: 'loc',
      warning: false,
      warningText: '',
      error: false,
      errorText: '',
      items: [],
      rawData: [],
      outputFile: [],
      columnMap: {},
      delimiter: ',',
      columnMode: 'normal',
      matlabHeader: false,
      skipIgnored: true,
      fillDown: false,
      uniqueOnly: false,
      valueTypes: ['CONVERTED', 'RAW', 'FORMATTED', 'WITH_UNITS'],
      editAll: false,
      allItemValueType: null,
      // uniqueIgnoreOptions: ['NO', 'YES'],
      cable: new Cable(),
      subscription: null,
      menus: [
        {
          label: 'File',
          radioGroup: 'Comma Delimited', // Default radio selected
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
            {
              divider: true,
            },
            {
              label: 'Comma Delimited',
              radio: true,
              command: () => {
                this.delimiter = ','
              },
            },
            {
              label: 'Tab Delimited',
              radio: true,
              command: () => {
                this.delimiter = '\t'
              },
            },
          ],
        },
        {
          label: 'Mode',
          radioGroup: 'Normal Columns', // Default radio selected
          items: [
            {
              label: 'Skip Ignored on Add',
              checkbox: true,
              checked: true, // Skip Ignored is the default
              command: () => {
                this.skipIgnored = !this.skipIgnored
              },
            },
            {
              divider: true,
            },
            {
              label: 'Fill Down',
              checkbox: true,
              command: () => {
                this.fillDown = !this.fillDown
              },
            },
            {
              label: 'Matlab Header',
              checkbox: true,
              command: () => {
                this.matlabHeader = !this.matlabHeader
              },
            },
            {
              label: 'Unique Only',
              checkbox: true,
              command: () => {
                this.uniqueOnly = !this.uniqueOnly
              },
            },
            {
              divider: true,
            },
            {
              label: 'Normal Columns',
              radio: true,
              command: () => {
                this.columnMode = 'normal'
              },
            },
            {
              label: 'Full Column Names',
              radio: true,
              command: () => {
                this.columnMode = 'full'
              },
            },
          ],
        },
      ],
    }
  },
  created() {
    this.api = new CosmosApi()
  },
  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    async openConfiguration(name) {
      const config = await this.api.load_config(this.toolName, name)
      this.items = JSON.parse(config)
    },
    saveConfiguration(name) {
      this.api.save_config(this.toolName, name, JSON.stringify(this.items))
    },
    addItem(item) {
      // Traditional for loop so we can return if we find a match
      for (var i = 0; i < this.items.length; i++) {
        if (
          this.items[i].itemName === item.itemName &&
          this.items[i].packetName === item.packetName &&
          this.items[i].targetName === item.targetName
        ) {
          this.warningText = 'This item has already been added!'
          this.warning = true
          return
        }
      }
      item.cmdOrTlm = this.cmdOrTlm.toUpperCase()
      item.edit = false
      item.valueType = 'CONVERTED'
      item.uniqueIgnoreAdd = 'NO'
      this.items.push(item)
    },
    deleteItem(item) {
      var index = this.items.indexOf(item)
      this.items.splice(index, 1)
    },
    deleteAll() {
      this.items = []
    },
    editAllValueTypes() {
      this.editAll = false
      for (let item of this.items) {
        item.valueType = this.allItemValueType
      }
    },
    getItemLabel(item) {
      var type = ''
      if (item.valueType !== 'CONVERTED') {
        type = ' (' + item.valueType + ')'
      }
      return (
        item.targetName + ' - ' + item.packetName + ' - ' + item.itemName + type
      )
    },
    setTimestamps() {
      this.startDateTimeFilename = this.startDate + '_' + this.startTime
      // Replace the colons and dashes with underscores in the filename
      this.startDateTimeFilename = this.startDateTimeFilename.replace(
        /(:|-)\s*/g,
        '_'
      )
      let startTemp
      let endTemp
      try {
        if (this.utcOrLocal === 'utc') {
          startTemp = new Date(this.startDate + ' ' + this.startTime + 'Z')
          endTemp = new Date(this.endDate + ' ' + this.endTime + 'Z')
        } else {
          startTemp = new Date(this.startDate + ' ' + this.startTime)
          endTemp = new Date(this.endDate + ' ' + this.endTime)
        }
      } catch (e) {
        return
      }
      this.startDateTime = startTemp.getTime() * 1_000_000
      this.endDateTime = endTemp.getTime() * 1_000_000
    },
    processItems() {
      // Check for an empty list
      if (this.items.length === 0) {
        this.warningText = 'No items to process!'
        this.warning = true
        return
      }
      // Check for a process in progress
      if (this.processButtonText === 'Cancel') {
        this.processReceived()
        return
      }
      // Check for an empty time period
      this.setTimestamps()
      if (!this.startDateTime || !this.endDateTime) {
        this.warningText = 'Invalid date/time selected!'
        this.warning = true
        return
      }
      if (this.startDateTime === this.endDateTime) {
        this.warningText = 'Start date/time is equal to end date/time!'
        this.warning = true
        return
      }
      if (this.endDateTime - this.startDateTime < 0) {
        this.warningText = 'Start date/time is greater then end date/time!'
        this.warning = true
        return
      }
      // Check for a future End Time
      if (new Date(this.endDateTime / 1_000_000) > Date.now()) {
        this.warningText =
          'Note: End date/time is greater than current date/time. Data will continue to stream in real-time until ' +
          new Date(this.endDateTime / 1_000_000).toISOString() +
          ' is reached.'
        this.warning = true
      }

      this.progress = 0
      this.processButtonText = 'Cancel'
      this.cable
        .createSubscription('StreamingChannel', localStorage.scope, {
          received: (data) => this.received(data),
          connected: () => this.onConnected(),
          disconnected: () => {
            this.warningText = 'COSMOS backend connection disconnected.'
            this.warning = true
          },
          rejected: () => {
            this.warningText = 'COSMOS backend connection rejected.'
            this.warning = true
          },
        })
        .then((subscription) => {
          this.subscription = subscription
        })
    },
    onConnected() {
      this.foundKeys = []
      this.columnHeaders = []
      this.columnMap = {}
      this.outputFile = []
      this.rawData = []
      var items = []
      this.items.forEach((item, index) => {
        items.push(
          item.cmdOrTlm +
            '__' +
            item.targetName +
            '__' +
            item.packetName +
            '__' +
            item.itemName +
            '__' +
            item.valueType
        )
      })
      CosmosAuth.updateToken(CosmosAuth.defaultMinValidity).then(() => {
        this.subscription.perform('add', {
          scope: localStorage.scope,
          mode: 'DECOM',
          token: localStorage.token,
          items: items,
          start_time: this.startDateTime,
          end_time: this.endDateTime,
        })
      })
    },
    buildHeaders(itemKeys) {
      if (
        this.foundKeys.includes(itemKeys[0]) &&
        this.foundKeys.includes(itemKeys[1])
      ) {
        return
      }
      this.foundKeys = this.foundKeys.concat(itemKeys)

      // Normal column mode has the target and packet listed for each item
      if (this.columnHeaders.length === 0 && this.columnMode === 'normal') {
        this.columnHeaders.push('TARGET')
        this.columnHeaders.push('PACKET')
      }
      itemKeys.forEach((item) => {
        if (item === 'time') return
        this.columnMap[item] = Object.keys(this.columnMap).length
        const [
          cmdTlm,
          targetName,
          packetName,
          itemName,
          valueType,
        ] = item.split('__')
        if (this.columnMode === 'full') {
          this.columnHeaders.push(
            targetName + ' ' + packetName + ' ' + itemName
          )
        } else {
          if (valueType && valueType !== 'CONVERTED') {
            this.columnHeaders.push(itemName + ' (' + valueType + ')')
          } else {
            this.columnHeaders.push(itemName)
          }
        }
      })
    },
    received(json_data) {
      if (json_data['error']) {
        this.errorText = json_data['error']
        this.error = true
        return
      }
      const data = JSON.parse(json_data)
      // Initially we just build up the list of data
      if (data.length > 0) {
        this.buildHeaders(Object.keys(data[0]))
        this.rawData = this.rawData.concat(data)
        this.progress = Math.ceil(
          (100 * (data[0]['time'] - this.startDateTime)) /
            (this.endDateTime - this.startDateTime)
        )
      } else {
        this.processReceived()
      }
    },
    processReceived() {
      this.progress = 95 // Indicate we're almost done
      this.subscription.unsubscribe()

      if (this.rawData.length === 0) {
        let start = new Date(this.startDateTime / 1_000_000).toISOString()
        let end = new Date(this.endDateTime / 1_000_000).toISOString()
        this.warningText = `No data found for the items in the requested time range of ${start} to ${end}`
        this.warning = true
      } else {
        // Output the headers
        this.warning = false
        let headers = ''
        if (this.matlabHeader) {
          headers += '% '
        }
        headers += this.columnHeaders.join(this.delimiter)
        this.outputFile.push(headers)

        // Sort everything by time so we can output in order
        this.rawData.sort((a, b) => a.time - b.time)
        var currentValues = []
        var row = []
        var previousRow = null
        this.rawData.forEach((packet) => {
          var changed = false
          if (this.fillDown && previousRow) {
            row = [...previousRow] // Copy the previous
          } else {
            row = []
          }
          // This pulls out the attributes we requested
          const keys = Object.keys(packet)
          keys.forEach((key) => {
            if (key === 'time') return // Skip time field
            // Get the value and put it into the correct column
            if (typeof packet[key] === 'object') {
              row[this.columnMap[key]] = '"' + packet[key]['raw'] + '"'
            } else {
              row[this.columnMap[key]] = packet[key]
            }
            if (
              this.uniqueOnly &&
              currentValues[this.columnMap[key]] !== row[this.columnMap[key]]
            ) {
              changed = true
            }
            currentValues[this.columnMap[key]] = row[this.columnMap[key]]
          })
          // Copy row before pushing on target / packet names
          previousRow = [...row]

          if (!this.uniqueOnly || changed) {
            // Normal column mode means each row has target / packet name
            if (this.columnMode === 'normal') {
              var [, tgt, pkt] = keys[0].split('__')
              row.unshift(pkt)
              row.unshift(tgt)
            }
            this.outputFile.push(row.join(this.delimiter))
          }
        })

        let downloadFileExtension = '.csv'
        let type = 'text/csv'
        if (this.delimiter === '\t') {
          downloadFileExtension = '.txt'
          type = 'text/tab-separated-values'
        }
        const blob = new Blob([this.outputFile.join('\n')], {
          type: type,
        })
        // Make a link and then 'click' on it to start the download
        const link = document.createElement('a')
        link.href = URL.createObjectURL(blob)
        link.setAttribute(
          'download',
          this.startDateTimeFilename + downloadFileExtension
        )
        link.click()
      }
      this.progress = 100
      this.processButtonText = 'Process'
    },
  },
}
</script>

<style lang="scss" scoped>
// Disable transition animations to allow bar to grow faster
.v-progress-linear__determinate {
  transition: none !important;
}
</style>
