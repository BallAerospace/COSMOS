<template>
  <div>
    <app-nav :menus="menus" />
    <v-container grid-list-md pa-20>
      <v-row>
        <h1>Time Period:</h1>
      </v-row>
      <v-row justify="space-around" align="center" fluid>
        <v-col>
          <v-menu
            v-model="startdatemenu"
            :close-on-content-click="true"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="startdate" label="Start Date" v-on="on" data-test="startdate"></v-text-field>
            </template>
            <v-date-picker v-model="startdate" :max="enddate" :show-current="false" no-title></v-date-picker>
          </v-menu>
          <v-menu
            ref="enddatemenu"
            v-model="enddatemenu"
            :close-on-content-click="true"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="enddate" label="End Date" v-on="on" data-test="enddate"></v-text-field>
            </template>
            <v-date-picker v-model="enddate" :min="startdate" :show-current="false" no-title></v-date-picker>
          </v-menu>
        </v-col>
        <v-col>
          <v-menu
            ref="starttimemenu"
            :close-on-content-click="false"
            v-model="starttimemenu"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="starttime" label="Start Time" v-on="on" data-test="starttime"></v-text-field>
            </template>
            <v-time-picker v-model="starttime" format="24hr" use-seconds :max="endtime" no-title></v-time-picker>
          </v-menu>
          <v-menu
            ref="endtimemenu"
            :close-on-content-click="false"
            v-model="endtimemenu"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="endtime" label="End Time" v-on="on" data-test="endtime"></v-text-field>
            </template>
            <v-time-picker
              v-model="endtime"
              format="24hr"
              use-seconds
              :min="starttime"
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
    </v-container>

    <v-container>
      <v-row>
        <v-col>
          <v-switch v-model="useUtcTime" class="ma-2" label="Use UTC time"></v-switch>
        </v-col>
        <v-col>
          <v-btn depressed small elevation="24" @click="deleteItems">Delete Item(s)</v-btn>
        </v-col>
        <v-col>
          <v-btn depressed small elevation="24" @click="processItems">Process</v-btn>
        </v-col>
        <v-col>
          <v-btn depressed small elevation="24" @click="clearItems">Clear Items</v-btn>
        </v-col>
        <v-col>
          <v-btn
            ref="blobDownloadLink"
            v-bind:href="blobDownloadLinkUrl"
            :disabled="blobDownloadLinkReady"
            depressed
            small
            :download="startDateTimeFilename + downloadFileExtension"
            elevation="24"
          >Download File</v-btn>
        </v-col>
      </v-row>
    </v-container>
    <v-card class="mx-auto" max-width="800" scrollable>
      <v-card-text align="center">
        <v-container align="center">
          <v-row v-for="(item, i) in tlmItems" v-bind:key="i" no-gutters>
            <v-col>
              <v-checkbox :label="`${getItemLabel(item)}`" v-model="item.act"></v-checkbox>
            </v-col>
            <v-col>
              <v-dialog v-model="item[i]" max-width="700">
                <template v-slot:activator="{ on, attrs }">
                  <v-btn
                    class="text-center"
                    color="primary"
                    small
                    text
                    dark
                    v-bind="attrs"
                    v-on="on"
                  >Edit Item - {{ item.label }}</v-btn>
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
            </v-col>
            <v-btn color="green darken-1" text @click="logItems(item)">Check</v-btn>
          </v-row>
        </v-container>
      </v-card-text>
    </v-card>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import { CosmosApi } from '@/services/cosmos-api'
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'
import * as ActionCable from 'actioncable'
import bs from 'binary-search'

export default {
  components: {
    AppNav,
    TargetPacketItemChooser
  },
  data() {
    return {
      dialog: false,
      startdate: null,
      startdatemenu: false,
      enddatemenu: false,
      starttimemenu: false,
      endtimemenu: false,
      starttime: null,
      endtime: null,
      enddate: null,
      startDateTime: null,
      endDateTime: null,
      startDateTimeFilename: '',
      tlmItems: [],
      duplicateWarning: false,
      totalData: [],
      useMatlabHeader: false,
      useFullColumnNames: false,
      useUtcTime: false,
      useFillDown: false,
      useUniqueOnly: false,
      useBatchMode: false,
      blobDownloadLink: null,
      blobDownloadLinkReady: true,
      blobDownloadLinkUrl: null,
      downloadFileExtension: '',
      valueTypes: ['CONVERTED', 'RAW', 'FORMATTED', 'WITH_UNITS'],
      dataReductions: ['NONE', 'MINUTE', 'HOUR', 'DAY'],
      dataReducedTypes: ['AVG', 'MIN', 'MAX', 'STDDEV'],
      uniqueIgnoreOptions: ['NO', 'YES'],
      cable: ActionCable.Cable,
      subscriptionToStream: ActionCable.Channel,
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
    deleteItems() {
      this.tlmItems = this.tlmItems.filter(item => {
        if (item.act == false) {
          return item
        }
      })
    },
    clearItems() {
      this.tlmItems = []
      this.blobDownloadLinkReady = true
    },
    setTimestamps() {
      //console.log(this.startdate + ' ' + this.starttime)
      //console.log(this.enddate + ' ' + this.endtime)
      //console.log(this.useUtcTime)
      this.startDateTimeFilename = this.startdate + '_' + this.starttime
      // Replace the colons with underscore
      this.startDateTimeFilename = this.startDateTimeFilename.replace(
        /:\s*/g,
        '_'
      )
      //console.log(this.startDateTimeFilename)

      if (this.useUtcTime) {
        this.startDateTime =
          new Date(this.startdate + ' ' + this.starttime).getTime() -
          216000 * 1000000
        this.endDateTime =
          new Date(this.enddate + ' ' + this.endtime).getTime() -
          216000 * 1000000
      } else {
        this.startDateTime =
          new Date(this.startdate + ' ' + this.starttime).getTime() * 1000000
        this.endDateTime =
          new Date(this.enddate + ' ' + this.endtime).getTime() * 1000000
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
      this.setTimestamps()
      // Create a cable at initialization
      var cable = ActionCable.createConsumer('ws://localhost:7777/cable')

      this.subscription = cable.subscriptions.create('StreamingChannel', {
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
          // console.log(localItems)
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
          //console.log(data)
          let columnHeaders = ''
          if (this.useMatlabHeader) {
            // Matlab column headers get a leading percent, add the first one here
            columnHeaders = '%'
          }
          // use the keys of the first packet to get the column headers
          data.forEach((packet, index) => {
            const keys = Object.keys(packet)
            if (index < 1) {
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

          // Now that headers are done, go thru all the packets
          data.forEach((packet, packetindex) => {
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
                  if (this.useTsv) {
                    row += packet[key] + '\t'
                  } else {
                    row += packet[key] + ','
                  }
                })
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
                if (this.useTsv) {
                  row += packet[key] + '\t'
                } else {
                  row += packet[key] + ','
                }
              })
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
            //console.log(this.totalData)
            this.blobDownloadLinkReady = false
            // Make Excel link
            if (this.useTsv) {
              this.downloadFileExtension = '.txt'
            } else {
              this.downloadFileExtension = '.csv'
            }
            let blob = new Blob(this.totalData, {
              type: 'data:text/csv;charset=utf-8;'
            })
            this.blobDownloadLinkUrl = URL.createObjectURL(blob)
          }
        }
      })
    }
  }
}
</script>
