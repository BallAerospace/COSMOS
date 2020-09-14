<template>
  <div>
    <app-nav :menus="menus" />
    <v-container>
      <v-row>
        <h1>Time Period:</h1>
      </v-row>
      <v-row justify="space-around" align="center" fluid>
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
        <v-progress-linear rounded height="10" :value="progress"></v-progress-linear>
      </v-row>
      <v-row>
        <v-col>
          <v-switch v-model="useUtcTime" label="Use UTC time" class="mt-0" dense hide-details></v-switch>
        </v-col>
        <v-col>
          <v-btn block class="primary" @click="processItems">
            {{
            processButtonText
            }}
          </v-btn>
        </v-col>
      </v-row>
      <v-row>
        <v-col>
          <v-card scrollable>
            <v-list>
              <v-subheader inset>
                Items
                <v-spacer></v-spacer>
                <v-btn class="primary" @click="clearItems">Delete All</v-btn>
              </v-subheader>
              <v-list-item v-for="(item, i) in tlmItems" :key="i">
                <v-list-item-icon>
                  <v-dialog v-model="item[i]" max-width="700">
                    <template v-slot:activator="{ on, attrs }">
                      <v-icon v-bind="attrs" v-on="on">mdi-pencil</v-icon>
                    </template>
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
                  <v-icon @click="deleteItem(item)">mdi-delete</v-icon>
                </v-list-item-icon>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import { CosmosApi } from '@/services/cosmos-api'
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'
import * as ActionCable from 'actioncable'
import { format, getTime } from 'date-fns'

export default {
  components: {
    AppNav,
    TargetPacketItemChooser
  },
  data() {
    return {
      progress: 0,
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
            }
          ]
        },
        {
          label: 'Mode',
          items: [
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
  },
  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    logItems(item) {
      //console.log(item)
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
      // it's ok to add the item now, act(active checkbox) is if it's checked to be deleted
      item.act = false
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
      if (this.subscription) {
        this.subscription.unsubscribe()
      }
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
            // Matlab column headers get a leading percent, add the first one here
            columnHeaders = '%'
          }
          if (!this.columnHeadersSet) {
            // use the keys of the first packet to get the column headers
            data.forEach((packet, index) => {
              const keys = Object.keys(packet)
              if (index < 1 && !this.columnHeadersSet) {
                keys.forEach(key => {
                  //console.log(key)

                  //console.log(shortHeader[3])
                  if (this.useTsv) {
                    if (this.useMatlabHeader) {
                      columnHeaders += key + '\t%'
                    } else if (this.useFullColumnNames) {
                      columnHeaders += key + '\t'
                    } else {
                      let headerParts = key.split('__')
                      if (headerParts.length > 1) {
                        columnHeaders += headerParts[3] + '\t'
                      } else {
                        // this should be the time column
                        columnHeaders += headerParts[0] + '\t'
                      }
                    }
                  } else {
                    if (this.useMatlabHeader) {
                      columnHeaders += key + ',%'
                    } else if (this.useFullColumnNames) {
                      columnHeaders += key + ','
                    } else {
                      let headerParts = key.split('__')
                      if (headerParts.length > 1) {
                        let headerParts = key.split('__')
                        columnHeaders += headerParts[3] + ','
                      } else {
                        // this should be the time column
                        columnHeaders += headerParts[0] + ','
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
          }
          // Now that headers are done, go thru all the packets
          data.forEach((packet, packetindex) => {
            this.progress = Math.ceil(
              (100 * (packet['time'] - this.startDateTime)) / this.duration
            )
            // convert packet array to comma separated string for each row
            const keys = Object.keys(packet)
            let row = ''
            if (this.useUniqueOnly) {
              let a = JSON.stringify(data[packetindex])
              let b = JSON.stringify(data[packetindex - 1])
              if (a == b) {
                // only add a row if current packet is not equal to previous packet
              } else {
                keys.forEach((key, index) => {
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
                this.totalData.push(row)
              }
            } else {
              keys.forEach((key, index) => {
                if (typeof packet[key] == 'object') {
                  packet[key] = '"' + packet[key]['raw'] + '"'
                }
                if (this.useTsv) {
                  row += packet[key] + '\t'
                } else {
                  row += packet[key] + ','
                }
              })
              // trim trailing delimiter
              if (this.useTsv) {
                row = this.rtrim(row, '\t')
              } else {
                row = this.rtrim(row, ',')
              }
              row += '\n'
              this.totalData.push(row)
            }
          })
          if (data.length == 0) {
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

<style lang="sass">
.v-progress-linear__determinate
  transition: none !important
</style>
