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
              <v-text-field v-model="startDate" label="Start Date" v-on="on" data-test="startDate"></v-text-field>
            </template>
            <v-date-picker v-model="startDate" :max="endDate" :show-current="false" no-title></v-date-picker>
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
              <v-text-field v-model="endDate" label="End Date" v-on="on" data-test="endDate"></v-text-field>
            </template>
            <v-date-picker v-model="endDate" :min="startDate" :show-current="false" no-title></v-date-picker>
          </v-menu>
        </v-col>
        <v-col>
          <v-menu
            :close-on-content-click="false"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="startTime" label="Start Time" v-on="on" data-test="startTime"></v-text-field>
            </template>
            <v-time-picker v-model="startTime" format="24hr" use-seconds :max="endTime" no-title></v-time-picker>
          </v-menu>
          <v-menu
            :close-on-content-click="false"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="endTime" label="End Time" v-on="on" data-test="endTime"></v-text-field>
            </template>
            <v-time-picker
              v-model="endTime"
              format="24hr"
              use-seconds
              :min="startTime"
              no-title
              @input="setTimestamps"
            ></v-time-picker>
          </v-menu>
        </v-col>
      </v-row>
      <v-row>
        <div class="c-tlmgrapher__contents">
          <TargetPacketItemChooser
            @click="addItem($event)"
            buttonText="Add Item"
            :chooseItem="true"
          ></TargetPacketItemChooser>
          <v-alert
            type="warning"
            v-if="duplicateWarning"
            dismissible
          >This item has already been added!</v-alert>
        </div>
      </v-row>
      <v-row>
        <v-col>
          <v-card scrollable>
            <v-progress-linear absolute top height="10" :value="progress" color="secondary"></v-progress-linear>
            <v-list data-test="itemList">
              <v-subheader class="mt-3">
                Items
                <v-spacer></v-spacer>
                <v-btn class="primary mr-4" @click="processItems">
                  {{
                  processButtonText
                  }}
                </v-btn>
                <v-tooltip bottom>
                  <template v-slot:activator="{ on, attrs }">
                    <v-icon
                      @click="clearItems"
                      v-bind="attrs"
                      v-on="on"
                      data-test="deleteAll"
                    >mdi-delete</v-icon>
                  </template>
                  <span>Delete All Items</span>
                </v-tooltip>
              </v-subheader>
              <v-list-item v-for="(item, i) in tlmItems" :key="i">
                <v-list-item-icon>
                  <v-tooltip bottom>
                    <template v-slot:activator="{ on, attrs }">
                      <v-icon @click.stop="item.edit = true" v-bind="attrs" v-on="on">mdi-pencil</v-icon>
                    </template>
                    <span>Edit Item</span>
                  </v-tooltip>
                  <v-dialog v-model="item.edit" max-width="700">
                    <v-card>
                      <v-card-title>Edit {{ item.label }}</v-card-title>
                      <v-card-text>
                        <v-col>
                          <v-select
                            :items="valueTypes"
                            label="Value Type:"
                            outlined
                            v-model="item.valueType"
                          ></v-select>
                        </v-col>
                        <v-col>
                          <v-select
                            :items="dataReductions"
                            label="Data Reduction:"
                            outlined
                            v-model="item.dataReduction"
                          ></v-select>
                        </v-col>
                        <v-col>
                          <v-select
                            :items="dataReducedTypes"
                            label="Data Reduction Type:"
                            outlined
                            v-model="item.dataReducedType"
                          ></v-select>
                        </v-col>
                        <v-col v-if="useUniqueOnly">
                          <v-select
                            :items="uniqueIgnoreOptions"
                            label="Add to Unique Ignore List?:"
                            outlined
                            v-model="item.uniqueIgnoreAdd"
                          ></v-select>
                        </v-col>
                      </v-card-text>
                      <v-card-actions>
                        <v-spacer></v-spacer>
                      </v-card-actions>
                    </v-card>
                  </v-dialog>
                </v-list-item-icon>
                <v-list-item-content>
                  <v-list-item-title v-text="getItemLabel(item)"></v-list-item-title>
                </v-list-item-content>
                <v-list-item-icon>
                  <v-tooltip bottom>
                    <template v-slot:activator="{ on, attrs }">
                      <v-icon @click="deleteItem(item)" v-bind="attrs" v-on="on">mdi-delete</v-icon>
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
    <LoadConfigDialog
      v-if="loadConfig"
      v-model="loadConfig"
      :tool="toolName"
      @success="loadConfiguration($event)"
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
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'
import LoadConfigDialog from '@/components/LoadConfigDialog'
import SaveConfigDialog from '@/components/SaveConfigDialog'
import * as ActionCable from 'actioncable'
import { format, getTime } from 'date-fns'
import { zonedTimeToUtc, utcToZonedTime } from 'date-fns-tz'

export default {
  components: {
    AppNav,
    TargetPacketItemChooser,
    LoadConfigDialog,
    SaveConfigDialog
  },
  data() {
    return {
      toolName: 'telemetry-extractor',
      api: null,
      loadConfig: false,
      saveConfig: false,
      progress: 0,
      lastRow: '',
      processButtonText: 'Process',
      startDate: format(new Date(), 'yyyy-MM-dd'),
      startTime: format(new Date(), 'HH:mm:ss'),
      endTime: format(new Date(), 'HH:mm:ss'),
      endDate: format(new Date(), 'yyyy-MM-dd'),
      startDateTime: null,
      endDateTime: null,
      duration: null,
      startDateTimeFilename: '',
      tlmItems: [],
      duplicateWarning: false,
      totalData: [],
      useMatlabHeader: false,
      useFullColumnNames: false,
      columnHeadersSet: false,
      useUtcTime: false,
      useFillDown: false,
      useUniqueOnly: false,
      useBatchMode: false,
      valueTypes: ['CONVERTED', 'RAW', 'FORMATTED', 'WITH_UNITS'],
      dataReductions: ['NONE', 'MINUTE', 'HOUR', 'DAY'],
      dataReducedTypes: ['AVG', 'MIN', 'MAX', 'STDDEV'],
      uniqueIgnoreOptions: ['NO', 'YES'],
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel,
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Load Configuration',
              command: () => {
                this.loadConfig = true
              }
            },
            {
              label: 'Save Configuration',
              command: () => {
                this.saveConfig = true
              }
            }
          ]
        },
        {
          label: 'Mode',
          items: [
            {
              label: 'Tab Delimited File',
              checkbox: true,
              command: () => {
                this.useTsv = !this.useTsv
              }
            },
            {
              label: 'Use Full Column Names',
              checkbox: true,
              command: () => {
                this.useFullColumnNames = !this.useFullColumnNames
              }
            },
            {
              divider: true
            },
            {
              label: 'Fill Down',
              checkbox: true,
              command: () => {
                this.useFillDown = !this.useFillDown
              }
            },
            {
              label: 'Use Matlab Header',
              checkbox: true,
              command: () => {
                this.useMatlabHeader = !this.useMatlabHeader
              }
            },
            {
              label: 'Unique Only',
              checkbox: true,
              command: () => {
                this.useUniqueOnly = !this.useUniqueOnly
              }
            },
            {
              label: 'Batch Mode',
              checkbox: true,
              command: () => {
                this.useBatchMode = !this.useBatchMode
              }
            }
          ]
        }
      ],
      model: this.tlmItems
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
    async loadConfiguration(name) {
      const config = await this.api.load_config(this.toolName, name)
      this.tlmItems = JSON.parse(config)
    },
    saveConfiguration(name) {
      this.api.save_config(this.toolName, name, JSON.stringify(this.tlmItems))
    },
    addItem(item) {
      // Go thru all the existing items and make sure they are NOT the same target/packet/items as the one being added
      for (var i = 0; i < this.tlmItems.length; i++) {
        if (
          this.tlmItems[i].itemName === item.itemName &&
          this.tlmItems[i].packetName === item.packetName &&
          this.tlmItems[i].targetName === item.targetName
        ) {
          this.duplicateWarning = true
          return
        }
      }
      item.edit = false
      item.label = ''
      item.valueType = 'CONVERTED'
      item.dataReduction = 'NONE'
      item.dataReducedType = ''
      item.uniqueIgnoreAdd = 'NO'
      this.tlmItems.push(item)
    },
    deleteItem(item) {
      var index = this.tlmItems.indexOf(item)
      this.tlmItems.splice(index, 1)
    },
    clearItems(words) {
      this.tlmItems = []
    },
    setTimestamps() {
      this.startDateTimeFilename = this.startDate + '_' + this.startTime
      // Replace the colons and dashes with underscore
      this.startDateTimeFilename = this.startDateTimeFilename.replace(
        /(:|-)\s*/g,
        '_'
      )

      if (this.useUtcTime) {
        this.startDateTime =
          new Date(this.startDate + ' ' + this.startTime).getTime() -
          216000 * 1_000_000
        this.endDateTime =
          new Date(this.endDate + ' ' + this.endTime).getTime() -
          216000 * 1_000_000
      } else {
        this.startDateTime =
          new Date(this.startDate + ' ' + this.startTime).getTime() * 1_000_000
        this.endDateTime =
          new Date(this.endDate + ' ' + this.endTime).getTime() * 1_000_000
      }
    },
    getItemLabel(item) {
      item.label =
        item.targetName + '  -  ' + item.packetName + '  -  ' + item.itemName
      return item.label
    },
    rtrim(str, chr) {
      var rgxtrim = !chr ? new RegExp('\\s+$') : new RegExp(chr + '+$')
      return str.replace(rgxtrim, '')
    },
    processItems() {
      // Check for an empty list
      if (this.tlmItems.length === 0) {
        return
      }
      // Check for a process in progress
      if (this.processButtonText === 'Cancel') {
        this.subscription.unsubscribe()
        this.processButtonText = 'Process'
        return
      }

      this.progress = 0
      this.columnHeadersSet = false
      this.setTimestamps()
      this.processButtonText = 'Cancel'
      this.subscription = this.cable.subscriptions.create('StreamingChannel', {
        connected: () => {
          var localItems = []
          this.tlmItems.forEach(item => {
            if (item.valueType) {
              localItems.push(
                'TLM__' +
                  item.targetName +
                  '__' +
                  item.packetName +
                  '__' +
                  item.itemName +
                  '__' +
                  item.valueType
              )
            } else {
              localItems.push(
                'TLM__' +
                  item.targetName +
                  '__' +
                  item.packetName +
                  '__' +
                  item.itemName +
                  '__CONVERTED'
              )
            }
          })
          this.duration = this.endDateTime - this.startDateTime
          this.totalData = []
          this.subscription.perform('add', {
            scope: 'DEFAULT',
            items: localItems,
            start_time: this.startDateTime,
            end_time: this.endDateTime
          })
        },
        received: json_data => {
          // Process the items when they are received
          let data = JSON.parse(json_data)
          let columnHeaders = ''
          if (this.useMatlabHeader) {
            // Matlab column headers get a leading percent
            columnHeaders = '% '
          }
          if (!this.columnHeadersSet) {
            // use the keys of the first packet to get the column headers
            data.forEach((packet, index) => {
              const keys = Object.keys(packet)
              if (index < 1) {
                keys.forEach(key => {
                  if (this.useTsv) {
                    if (this.useFullColumnNames) {
                      columnHeaders += key + '\t'
                    } else {
                      let headerParts = key.split('__')
                      if (headerParts.length > 1) {
                        columnHeaders += headerParts[3] + '\t'
                        // } else {
                        //   // this should be the time column
                        //   columnHeaders += headerParts[0] + '\t'
                      }
                    }
                  } else {
                    if (this.useFullColumnNames) {
                      columnHeaders += key + ','
                    } else {
                      let headerParts = key.split('__')
                      if (headerParts.length > 1) {
                        let headerParts = key.split('__')
                        columnHeaders += headerParts[3] + ','
                        // } else {
                        //   // this should be the time column
                        //   columnHeaders += headerParts[0] + ','
                      }
                    }
                  }
                })
              }
            })
            columnHeaders = this.rtrim(columnHeaders, '%')
            columnHeaders = this.rtrim(columnHeaders, ',')
            columnHeaders = this.rtrim(columnHeaders, '\t')
            columnHeaders += '\n'
            this.totalData.push(columnHeaders)
            this.columnHeadersSet = true
            this.lastRow = ''
          }
          // Now that headers are done, go thru all the packets
          data.forEach((packet, packetindex) => {
            this.progress = Math.ceil(
              (100 * (packet['time'] - this.startDateTime)) / this.duration
            )
            // convert packet array to comma separated string for each row
            const keys = Object.keys(packet)
            let row = ''
            keys.forEach((key, index) => {
              if (key === 'time') return
              if (typeof packet[key] == 'object') {
                packet[key] = '"' + packet[key]['raw'] + '"'
              }
              if (this.useTsv) {
                row += packet[key] + '\t'
              } else {
                row += packet[key] + ','
              }
            })
            // trim trailing delimiter, not needed
            if (this.useTsv) {
              row = this.rtrim(row, '\t')
            } else {
              row = this.rtrim(row, ',')
            }
            row += '\n'
            if (!this.useUniqueOnly || row !== this.lastRow) {
              this.totalData.push(row)
            }
            this.lastRow = row
          })
          if (data.length == 0) {
            this.subscription.unsubscribe()
            this.processButtonText = 'Process'
            this.progress = 100
            let downloadFileExtension = '.csv'
            let type = 'text/csv'
            if (this.useTsv) {
              downloadFileExtension = '.txt'
              type = 'text/tab-separated-values'
            }
            const blob = new Blob(this.totalData, {
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
          }
        }
      })
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
