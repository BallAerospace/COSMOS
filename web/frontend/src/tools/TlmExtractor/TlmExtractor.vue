<template>
  <div>
    <app-nav :menus="menus" />
    <v-container>
      <v-row>
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
                :rules="[rules.required, rules.calendar]"
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
            v-model="startTime"
            label="Start Time"
            prepend-icon="mdi-clock"
            :rules="[rules.required, rules.time]"
            data-test="startTime"
          ></v-text-field>
          <v-text-field
            v-model="endTime"
            label="End Time"
            prepend-icon="mdi-clock"
            :rules="[rules.required, rules.time]"
            data-test="endTime"
          ></v-text-field>
        </v-col>
      </v-row>
      <v-row>
        <div class="c-tlmgrapher__contents">
          <TargetPacketItemChooser
            @click="addItem($event)"
            buttonText="Add Item"
            :chooseItem="true"
          ></TargetPacketItemChooser>
          <v-alert type="warning" v-model="warning" dismissible
            >{{ warningText }}
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
            ></v-progress-linear>
            <v-list data-test="itemList">
              <v-subheader class="mt-3">
                Items
                <v-spacer></v-spacer>
                <v-btn class="primary mr-4" @click="processItems">
                  {{ processButtonText }}
                </v-btn>
                <v-tooltip bottom>
                  <template v-slot:activator="{ on, attrs }">
                    <v-icon
                      @click="deleteAll"
                      v-bind="attrs"
                      v-on="on"
                      data-test="deleteAll"
                      >mdi-delete</v-icon
                    >
                  </template>
                  <span>Delete All Items</span>
                </v-tooltip>
              </v-subheader>
              <v-list-item v-for="(item, i) in tlmItems" :key="i">
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
                            :items="valueTypes"
                            label="Value Type"
                            outlined
                            v-model="item.valueType"
                          ></v-select>
                        </v-col>
                        <!-- v-col v-if="uniqueOnly">
                          <v-select
                            :items="uniqueIgnoreOptions"
                            label="Add to Unique Ignore List?:"
                            outlined
                            v-model="item.uniqueIgnoreAdd"
                          ></v-select>
                        </v-col -->
                      </v-card-text>
                    </v-card>
                  </v-dialog>
                </v-list-item-icon>
                <v-list-item-content>
                  <v-list-item-title
                    v-text="getItemLabel(item)"
                  ></v-list-item-title>
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
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <OpenConfigDialog
      v-if="openConfig"
      v-model="openConfig"
      :tool="toolName"
      @success="openConfiguration($event)"
    />
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
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
import { CosmosApi } from '@/services/cosmos-api'
import OpenConfigDialog from '@/components/OpenConfigDialog'
import SaveConfigDialog from '@/components/SaveConfigDialog'
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'
import * as ActionCable from 'actioncable'
import { format, getTime } from 'date-fns'

export default {
  components: {
    AppNav,
    OpenConfigDialog,
    SaveConfigDialog,
    TargetPacketItemChooser
  },
  data() {
    return {
      toolName: 'telemetry-extractor',
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
        required: value => !!value || 'Required',
        calendar: value => {
          const pattern = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/
          return pattern.test(value) || 'Invalid date (YYYY-MM-DD)'
        },
        time: value => {
          const pattern = /^[0-9]{2}:[0-9]{2}:[0-9]{2}$/
          return pattern.test(value) || 'Invalid time (HH:MM:SS)'
        }
      },
      warning: false,
      warningText: '',
      tlmItems: [],
      rawData: [],
      outputFile: [],
      columnMap: {},
      delimiter: ',',
      columnMode: 'normal',
      matlabHeader: false,
      fillDown: false,
      uniqueOnly: false,
      valueTypes: ['CONVERTED', 'RAW', 'FORMATTED', 'WITH_UNITS'],
      // uniqueIgnoreOptions: ['NO', 'YES'],
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel,
      menus: [
        {
          label: 'File',
          radioGroup: 'Comma Delimited', // Default radio selected
          items: [
            {
              label: 'Open Configuration',
              command: () => {
                this.openConfig = true
              }
            },
            {
              label: 'Save Configuration',
              command: () => {
                this.saveConfig = true
              }
            },
            {
              divider: true
            },
            {
              label: 'Comma Delimited',
              radio: true,
              command: () => {
                this.delimiter = ','
              }
            },
            {
              label: 'Tab Delimited',
              radio: true,
              command: () => {
                this.delimiter = '\t'
              }
            }
          ]
        },
        {
          label: 'Mode',
          radioGroup: 'Normal Columns', // Default radio selected
          items: [
            {
              label: 'Fill Down',
              checkbox: true,
              command: () => {
                this.fillDown = !this.fillDown
              }
            },
            {
              label: 'Matlab Header',
              checkbox: true,
              command: () => {
                this.matlabHeader = !this.matlabHeader
              }
            },
            {
              label: 'Unique Only',
              checkbox: true,
              command: () => {
                this.uniqueOnly = !this.uniqueOnly
              }
            },
            {
              divider: true
            },
            {
              label: 'Normal Columns',
              radio: true,
              command: () => {
                this.columnMode = 'normal'
              }
            },
            {
              label: 'Full Column Names',
              radio: true,
              command: () => {
                this.columnMode = 'full'
              }
            }
          ]
        }
      ]
    }
  },
  created() {
    // Creating the cable can be done once, subscriptions come and go
    this.cable = ActionCable.createConsumer('ws://localhost:7777/cable')
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
      this.tlmItems = JSON.parse(config)
    },
    saveConfiguration(name) {
      this.api.save_config(this.toolName, name, JSON.stringify(this.tlmItems))
    },
    addItem(item) {
      // Traditional for loop so we can return if we find a match
      for (var i = 0; i < this.tlmItems.length; i++) {
        if (
          this.tlmItems[i].itemName === item.itemName &&
          this.tlmItems[i].packetName === item.packetName &&
          this.tlmItems[i].targetName === item.targetName
        ) {
          this.warningText = 'This item has already been added!'
          this.warning = true
          return
        }
      }
      item.edit = false
      item.valueType = 'CONVERTED'
      item.uniqueIgnoreAdd = 'NO'
      this.tlmItems.push(item)
    },
    deleteItem(item) {
      var index = this.tlmItems.indexOf(item)
      this.tlmItems.splice(index, 1)
    },
    deleteAll() {
      this.tlmItems = []
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
      this.startDateTime =
        new Date(this.startDate + ' ' + this.startTime).getTime() * 1_000_000
      this.endDateTime =
        new Date(this.endDate + ' ' + this.endTime).getTime() * 1_000_000
    },
    processItems() {
      // Check for an empty list
      if (this.tlmItems.length === 0) {
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
      if (this.startDateTime === this.endDateTime) {
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

      this.progress = 0
      this.processButtonText = 'Cancel'
      this.subscription = this.cable.subscriptions.create('StreamingChannel', {
        received: data => this.received(data),
        connected: () => {
          this.intializeOutput()
          var items = []
          this.tlmItems.forEach((item, index) => {
            items.push(
              'TLM__' +
                item.targetName +
                '__' +
                item.packetName +
                '__' +
                item.itemName +
                '__' +
                item.valueType
            )
            this.columnMap[items[items.length - 1]] = index
          })
          this.subscription.perform('add', {
            scope: 'DEFAULT',
            items: items,
            start_time: this.startDateTime,
            end_time: this.endDateTime
          })
        }
      })
    },
    intializeOutput() {
      this.outputFile = []
      this.rawData = []

      let columnHeaders = []
      // Normal column mode has the target and packet listed for each item
      if (this.columnMode === 'normal') {
        columnHeaders.push('TARGET')
        columnHeaders.push('PACKET')
      }
      this.tlmItems.forEach(item => {
        if (this.columnMode === 'full') {
          columnHeaders.push(
            item.targetName + ' ' + item.packetName + ' ' + item.itemName
          )
        } else {
          if (item.valueType && item.valueType !== 'CONVERTED') {
            columnHeaders.push(item.itemName + ' (' + item.valueType + ')')
          } else {
            columnHeaders.push(item.itemName)
          }
        }
      })
      let headers = ''
      if (this.matlabHeader) {
        headers += '% '
      }
      headers += columnHeaders.join(this.delimiter)
      this.outputFile.push(headers)
    },
    received(json_data) {
      const data = JSON.parse(json_data)
      // Initially we just build up the list of data
      if (data.length > 0) {
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
      // Sort everything by time so we can output in order
      this.rawData.sort((a, b) => a.time - b.time)
      var currentValues = []
      var row = []
      var previousRow = null
      this.rawData.forEach(packet => {
        var changed = false
        if (this.fillDown && previousRow) {
          row = [...previousRow] // Copy the previous
        } else {
          row = []
        }
        // This pulls out the attributes we requested
        const keys = Object.keys(packet)
        keys.forEach(key => {
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
        type: type
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        this.startDateTimeFilename + downloadFileExtension
      )
      link.click()

      this.progress = 100
      this.processButtonText = 'Process'
    }
  }
}
</script>

<style lang="scss" scoped>
// Disable transition animations to allow bar to grow faster
.v-progress-linear__determinate {
  transition: none !important;
}
</style>
