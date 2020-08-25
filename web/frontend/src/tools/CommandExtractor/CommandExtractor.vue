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
            ref="startdatemenu"
            v-model="startdatemenu"
            :close-on-content-click="false"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="startdate" label="Start Date" v-on="on"></v-text-field>
            </template>
            <v-date-picker
              v-model="startdate"
              :max="enddate"
              :show-current="false"
              no-title
              @input="startdatemenu = false"
            ></v-date-picker>
          </v-menu>
          <v-menu
            ref="enddatemenu"
            v-model="enddatemenu"
            :close-on-content-click="false"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="enddate" label="End Date" v-on="on"></v-text-field>
            </template>
            <v-date-picker
              v-model="enddate"
              :min="startdate"
              :show-current="false"
              no-title
              @input="enddatemenu = false"
            ></v-date-picker>
          </v-menu>
        </v-col>
        <v-col>
          <v-menu
            ref="starttimemenu"
            v-model="starttimemenu"
            :close-on-content-click="false"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="starttime" label="Start Time" v-on="on"></v-text-field>
            </template>
            <v-time-picker
              v-model="starttime"
              format="24hr"
              use-seconds
              :max="endtime"
              no-title
              @input="starttimemenu = false"
            ></v-time-picker>
          </v-menu>
          <v-menu
            ref="endtimemenu"
            v-model="endtimemenu"
            :close-on-content-click="false"
            :nudge-right="40"
            transition="scale-transition"
            offset-y
            max-width="290px"
            min-width="290px"
          >
            <template v-slot:activator="{ on }">
              <v-text-field v-model="endtime" label="End Time" v-on="on"></v-text-field>
            </template>
            <v-time-picker
              v-model="endtime"
              format="24hr"
              use-seconds
              :min="starttime"
              no-title
              @input="endtimemenu = false"
            ></v-time-picker>
          </v-menu>
        </v-col>
      </v-row>
      <v-row>
        <v-col>
          <v-btn depressed small elevation="24">Process Data</v-btn>
        </v-col>
      </v-row>
      <v-row>
        <v-col cols="12" lg="12">
          <v-textarea solo name="results-1" label="Results"></v-textarea>
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import { CosmosApi } from '@/services/cosmos-api'

export default {
  components: {
    AppNav
  },
  data: vm => ({
    startdate: null,
    startdatemenu: false,
    enddatemenu: false,
    starttimemenu: false,
    endtimemenu: false,
    starttime: null,
    endtime: null,
    enddate: null,
    csvOutput: false,
    skipIgnored: false,
    includeRawData: false,
    rules: [
      value => !!value || 'Required.',
      value => (value && value.length >= 3) || 'Min 3 characters'
    ],
    menus: [
      {
        label: 'file',
        items: [
          {
            label: 'Skip Ignored Items',
            checkbox: true,
            command: () => {
              this.skipIgnored = !this.skipIgnored
            }
          },
          {
            label: 'CSV Output',
            checkbox: true,
            command: () => {
              this.csvOutput = !this.csvOutput
            }
          },
          {
            label: 'Include Raw Data',
            checkbox: true,
            command: () => {
              this.includeRawData = !this.includeRawData
            }
          }
        ]
      }
    ]
  }),
  created() {
    this.api = new CosmosApi()
    let cmds = this.api.get_cmd_list('INST')
    // console.log(cmds)
  },
  methods: {
    testGetCommands() {
      cmds = this.api.get_cmd_list('INST')
      // console.log(cmds)
    }
  }
}
</script>
