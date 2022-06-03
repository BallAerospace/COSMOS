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
    <v-container>
      <v-row>
        <v-col> Oldest found log data: </v-col>
        <v-col>
          {{ oldestLogDate | dateTime(utcOrLocal) }}
        </v-col>
      </v-row>
      <v-row>
        <v-col>
          <v-text-field
            v-model="startDate"
            label="Start Date"
            type="date"
            :min="oldestLogDateStr"
            :max="todaysDate"
            :rules="[rules.required]"
            data-test="start-date"
          />
          <v-text-field
            v-model="endDate"
            label="End Date"
            type="date"
            :min="oldestLogDateStr"
            :max="todaysDate"
            :rules="[rules.required]"
            data-test="end-date"
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
          >
          </v-text-field>
          <v-text-field
            v-model="endTime"
            label="End Time"
            type="time"
            step="1"
            :rules="[rules.required]"
            data-test="end-time"
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
            <v-radio label="LST" value="loc" data-test="lst-radio" />
            <v-radio label="UTC" value="utc" data-test="utc-radio" />
          </v-radio-group>
        </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col>
          <v-radio-group v-model="reduced" row hide-details>
            <span class="mr-5">Data Reduction:</span>
            <v-radio label="None" value="DECOM" data-test="not-reduced" />
            <v-radio
              label="Minute"
              value="REDUCED_MINUTE"
              data-test="min-reduced"
            />
            <v-radio
              label="Hour"
              value="REDUCED_HOUR"
              data-test="hour-reduced"
            />
            <v-radio label="Day" value="REDUCED_DAY" data-test="day-reduced" />
          </v-radio-group>
        </v-col>
      </v-row>
      <v-row>
        <v-col>
          <target-packet-item-chooser
            @click="addItem($event)"
            button-text="Add Item"
            :mode="cmdOrTlm"
            :reduced="reduced"
            choose-item
            allow-all
          />
        </v-col>
      </v-row>
      <v-row no-gutters>
        <v-toolbar>
          <v-progress-circular :value="progress" />
          &nbsp; Received: {{ totalBytesReceived }} bytes
          <v-spacer />
          <v-toolbar-title> Items </v-toolbar-title>
          <v-spacer />
          <v-btn
            class="primary mr-4"
            @click="processItems"
            :disabled="items.length < 1"
            >{{ processButtonText }}</v-btn
          >
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-btn
                icon
                @click="editAll = true"
                v-bind="attrs"
                v-on="on"
                :disabled="items.length < 1"
                data-test="editAll"
              >
                <v-icon> mdi-pencil </v-icon>
              </v-btn>
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
                :disabled="items.length < 1"
                data-test="delete-all"
              >
                <v-icon>mdi-delete</v-icon>
              </v-btn>
            </template>
            <span>Delete All Items</span>
          </v-tooltip>
        </v-toolbar>
      </v-row>
      <v-row no-gutters>
        <v-list data-test="item-list" width="100%">
          <div v-for="(item, i) in items" :key="i">
            <v-list-item>
              <v-list-item-icon>
                <v-tooltip bottom>
                  <template v-slot:activator="{ on, attrs }">
                    <v-icon
                      @click.stop="item.edit = true"
                      v-bind="attrs"
                      v-on="on"
                    >
                      mdi-pencil
                    </v-icon>
                  </template>
                  <span>Edit Item</span>
                </v-tooltip>
                <v-dialog
                  v-model="item.edit"
                  @keydown.esc="item.edit = false"
                  max-width="600"
                >
                  <v-card>
                    <v-system-bar>
                      <v-spacer />
                      <span> DataExtractor: Edit Item Mode </span>
                      <v-spacer />
                    </v-system-bar>
                    <v-card-title>{{ getItemLabel(item) }}</v-card-title>
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
                      <v-btn color="primary" @click="item.edit = false">
                        Close
                      </v-btn>
                    </v-card-actions>
                  </v-card>
                </v-dialog>
              </v-list-item-icon>
              <v-list-item-content>
                <v-list-item-title>{{ getItemLabel(item) }}</v-list-item-title>
              </v-list-item-content>
              <v-list-item-icon>
                <v-tooltip bottom>
                  <template v-slot:activator="{ on, attrs }">
                    <v-icon @click="deleteItem(item)" v-bind="attrs" v-on="on">
                      mdi-delete
                    </v-icon>
                  </template>
                  <span>Delete Item</span>
                </v-tooltip>
              </v-list-item-icon>
            </v-list-item>
            <v-divider />
          </div>
        </v-list>
      </v-row>
    </v-container>
    <v-dialog v-model="editAll" @keydown.esc="cancelEditAll" max-width="600">
      <v-card>
        <v-system-bar>
          <v-spacer />
          <span> DataExtractor: Edit All Items</span>
          <v-spacer />
        </v-system-bar>
        <v-card-text class="mt-2">
          This will change all items to the following data type!
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
          <v-btn outlined class="mx-2" @click="editAll = !editAll">
            Cancel
          </v-btn>
          <v-btn
            :disabled="!allItemValueType"
            color="primary"
            class="mx-2"
            @click="editAllValueTypes()"
          >
            Ok
          </v-btn>
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
import { format, getTime } from 'date-fns'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'
import TimeFilters from '@/tools/DataExtractor/Filters/timeFilters.js'

export default {
  components: {
    OpenConfigDialog,
    SaveConfigDialog,
    TargetPacketItemChooser,
    TopBar,
  },
  mixins: [TimeFilters],
  data() {
    return {
      api: null,
      title: 'Data Extractor',
      toolName: 'data-exporter',
      openConfig: false,
      saveConfig: false,
      progress: 0,
      bytesReceived: 0,
      totalBytesReceived: 0,
      processButtonText: 'Process',
      oldestLogDate: new Date(),
      todaysDate: format(new Date(), 'yyyy-MM-dd'),
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
      reduced: 'DECOM',
      items: [],
      rawData: [],
      columnMap: {},
      delimiter: ',',
      columnMode: 'normal',
      fileCount: 0,
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
            // TODO: Currently unimplemented
            // {
            //   label: 'Skip Ignored on Add',
            //   checkbox: true,
            //   checked: true, // Skip Ignored is the default
            //   command: () => {
            //     this.skipIgnored = !this.skipIgnored
            //   },
            // },
            // {
            //   divider: true,
            // },
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
  computed: {
    oldestLogDateStr: function () {
      // Set the start date / time to the earliest data found
      return format(this.oldestLogDate, 'yyyy-MM-dd')
    },
  },
  created: function () {
    this.api = new CosmosApi()
    this.api
      .get_oldest_logfile({ params: { scope: localStorage.scope } })
      .then((response) => {
        // Server returns time as UTC so create date with 'Z'
        this.oldestLogDate = new Date(response + 'Z')
      })
  },
  mounted: function () {
    const previousConfig = localStorage['lastconfig__data_exporter']
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
    openConfiguration: function (name) {
      localStorage['lastconfig__data_exporter'] = name
      this.api
        .load_config(this.toolName, name)
        .then((response) => {
          if (response) {
            this.items = JSON.parse(response)
            this.$notify.normal({
              title: 'Loading configuartion',
              body: name,
            })
          }
        })
        .catch((error) => {
          if (error) {
            this.$notify.serious({
              title: `Failed to open configuration ${name}`,
              body: error,
            })
            localStorage['lastconfig__data_exporter'] = null
          }
        })
    },
    saveConfiguration: function (name) {
      localStorage['lastconfig__data_exporter'] = name
      this.api
        .save_config(this.toolName, name, JSON.stringify(this.items))
        .then((response) => {
          this.$notify.normal({
            title: 'Saved configuration',
            body: name,
          })
        })
        .catch((error) => {
          if (error) {
            this.$notify.serious({
              title: `Failed to save configuration: ${name}`,
              body: error,
            })
          }
        })
    },
    addItem: function (item) {
      // Traditional for loop so we can return if we find a match
      for (const listItem of this.items) {
        if (
          listItem.itemName === item.itemName &&
          listItem.packetName === item.packetName &&
          listItem.targetName === item.targetName &&
          listItem.valueType === 'CONVERTED'
        ) {
          this.$notify.caution({
            body: 'This item has already been added!',
          })
          return
        }
      }
      item.cmdOrTlm = this.cmdOrTlm.toUpperCase()
      item.edit = false
      item.valueType = 'CONVERTED'
      // item.uniqueIgnoreAdd = 'NO'
      this.items.push(item)
    },
    deleteItem: function (item) {
      var index = this.items.indexOf(item)
      this.items.splice(index, 1)
    },
    deleteAll: function () {
      this.items = []
    },
    editAllValueTypes: function () {
      this.editAll = false
      for (let item of this.items) {
        item.valueType = this.allItemValueType
      }
    },
    getItemLabel: function (item) {
      let label = [`${item.targetName} - ${item.packetName} - ${item.itemName}`]
      if (item.valueType !== 'CONVERTED') {
        label.push(`+ ( ${item.valueType} )`)
      }
      if (item.reduced !== 'DECOM') {
        label.push(`[ ${item.reduced} ]`)
      }
      return label.join(' ')
    },
    setTimestamps: function () {
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
    processItems: function () {
      // Check for a process in progress
      if (this.processButtonText === 'Cancel') {
        this.finished()
        return
      }
      // Check for an empty time period
      this.setTimestamps()
      if (!this.startDateTime || !this.endDateTime) {
        this.$notify.caution({
          body: 'Invalid date/time selected!',
        })
        return
      }
      if (this.startDateTime === this.endDateTime) {
        this.$notify.caution({
          body: 'Start date/time is equal to end date/time!',
        })
        return
      }
      if (this.endDateTime - this.startDateTime < 0) {
        this.$notify.caution({
          body: 'Start date/time is greater then end date/time!',
        })
        return
      }
      // Check for a future End Time
      if (new Date(this.endDateTime / 1_000_000) > Date.now()) {
        this.$notify.caution({
          title: 'Note',
          body: `End date/time is greater than current date/time. Data will
            continue to stream in real-time until
            ${new Date(
              this.endDateTime / 1_000_000
            ).toISOString()} is reached.`,
        })
      }

      this.progress = 0
      this.processButtonText = 'Cancel'
      this.cable
        .createSubscription('StreamingChannel', localStorage.scope, {
          received: (data) => this.received(data),
          connected: () => this.onConnected(),
          disconnected: () => {
            this.$notify.caution({
              body: 'COSMOS backend connection disconnected.',
            })
          },
          rejected: () => {
            this.$notify.caution({
              body: 'COSMOS backend connection rejected.',
            })
          },
        })
        .then((subscription) => {
          this.subscription = subscription
        })
    },
    resetVars: function () {
      this.foundKeys = []
      this.columnHeaders = []
      this.columnMap = {}
      this.rawData = []
      this.bytesReceived = 0
    },
    onConnected: function () {
      this.fileCount = 0
      this.totalBytesReceived = 0
      this.resetVars()
      var items = []
      this.items.forEach((item, index) => {
        items.push(
          `${item.cmdOrTlm}__${item.targetName}__${item.packetName}__${item.itemName}__${item.valueType}`
        )
      })
      CosmosAuth.updateToken(CosmosAuth.defaultMinValidity).then(() => {
        this.subscription.perform('add', {
          scope: localStorage.scope,
          mode: this.reduced,
          token: localStorage.cosmosToken,
          items: items,
          start_time: this.startDateTime,
          end_time: this.endDateTime,
        })
      })
    },
    buildHeaders: function (itemKeys) {
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
        const [cmdTlm, targetName, packetName, itemName, valueType] =
          item.split('__')
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
    received: function (json_data) {
      if (json_data.error) {
        this.$notify.serious({
          body: json_data.error,
        })
        return
      }
      this.bytesReceived += json_data.length
      this.totalBytesReceived += json_data.length
      const data = JSON.parse(json_data)
      // Initially we just build up the list of data
      if (data.length > 0) {
        // Get all the items present in the data to pass to buildHeaders
        let keys = new Set()
        for (var item of data) {
          Object.keys(item).forEach(keys.add, keys)
        }
        this.buildHeaders([...keys])
        this.rawData = this.rawData.concat(data)
        this.progress = Math.ceil(
          (100 * (data[0]['time'] - this.startDateTime)) /
            (this.endDateTime - this.startDateTime)
        )

        if (this.bytesReceived > 200000000) {
          this.bytesReceived = 0
          this.createFile()
        }
      } else {
        this.finished()
      }
    },
    createFile: function () {
      let rawData = this.rawData
      let foundKeys = this.foundKeys
      let columnHeaders = this.columnHeaders
      let columnMap = this.columnMap
      let outputFile = []
      this.resetVars()

      let headers = ''
      if (this.matlabHeader) {
        headers += '% '
      }
      headers += columnHeaders.join(this.delimiter)
      outputFile.push(headers)

      // Sort everything by time so we can output in order
      rawData.sort((a, b) => a.time - b.time)
      var currentValues = []
      var row = []
      var previousRow = null
      rawData.forEach((packet) => {
        var changed = false
        if (this.fillDown && previousRow) {
          row = [...previousRow] // Copy the previous
        } else {
          row = []
        }
        // This pulls out the attributes we requested
        const keys = Object.keys(packet)
        keys.forEach((key) => {
          if (key === 'time' || key === 'packet') return // Skip time and packet fields
          // Get the value and put it into the correct column
          if (typeof packet[key] === 'object') {
            row[columnMap[key]] = '"' + packet[key]['raw'] + '"'
          } else {
            row[columnMap[key]] = packet[key]
          }
          if (
            this.uniqueOnly &&
            currentValues[columnMap[key]] !== row[columnMap[key]]
          ) {
            changed = true
          }
          currentValues[columnMap[key]] = row[columnMap[key]]
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
          outputFile.push(row.join(this.delimiter))
        }
      })

      let downloadFileExtension = '.csv'
      let type = 'text/csv'
      if (this.delimiter === '\t') {
        downloadFileExtension = '.txt'
        type = 'text/tab-separated-values'
      }
      const blob = new Blob([outputFile.join('\n')], {
        type: type,
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        this.startDateTimeFilename +
          '.' +
          this.fileCount +
          downloadFileExtension
      )
      link.click()

      this.fileCount += 1
    },
    finished: function () {
      this.progress = 95 // Indicate we're almost done
      this.subscription.unsubscribe()

      if (this.rawData.length !== 0) {
        this.createFile()
      } else if (this.fileCount === 0) {
        let start = new Date(this.startDateTime / 1_000_000).toISOString()
        let end = new Date(this.endDateTime / 1_000_000).toISOString()
        this.$notify.caution({
          body: `No data found for the items in the requested time range of ${start} to ${end}`,
        })
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
