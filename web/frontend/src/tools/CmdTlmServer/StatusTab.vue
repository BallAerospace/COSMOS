<template>
  <div>
    <!-- Use a container here so we can do cols="auto" to resize v-select -->
    <v-card flat>
      <v-container class="ma-0 pa-4">
        <v-row no-gutters>
          <v-col cols="auto">
            <v-select
              label="Limits Set"
              :items="limitsSets"
              @change="limitsChange"
              v-model="currentLimitsSet"
            ></v-select>
          </v-col>
        </v-row>
      </v-container>
    </v-card>

    <v-card flat>
      <v-card-title>API Status</v-card-title>
      <v-data-table
        :headers="apiHeaders"
        :items="apiStatus"
        calculate-widths
        disable-pagination
        hide-default-footer
      ></v-data-table>
    </v-card>

    <v-card flat>
      <v-card-title>Background Tasks</v-card-title>
      <v-data-table
        :headers="backgroundHeaders"
        :items="backgroundTasks"
        calculate-widths
        disable-pagination
        hide-default-footer
      >
        <template v-slot:item.control="{ item }">
          <v-btn
            block
            color="primary"
            @click="taskControl(item.name, item.control)"
            >{{ item.control }}</v-btn
          >
        </template>
      </v-data-table>
    </v-card>
  </div>
</template>

<script>
import Updater from './Updater'

export default {
  mixins: [Updater],
  props: {
    tabId: Number,
    curTab: Number
  },
  data() {
    return {
      apiStatus: [],
      apiHeaders: [
        { text: 'Port', value: 'port' },
        { text: 'Clients', value: 'clients' },
        { text: 'Requests', value: 'requests' },
        { text: 'Avg Request Time', value: 'avgTime' },
        { text: 'Server Threads', value: 'threads' }
      ],
      backgroundTasks: [],
      backgroundHeaders: [
        { text: 'Name', value: 'name' },
        { text: 'State', value: 'state' },
        { text: 'Status', value: 'status' },
        { text: 'Control', value: 'control' }
      ],
      limitsSets: [],
      currentLimitsSet: ''
    }
  },
  created() {
    this.api.get_limits_sets().then(sets => {
      this.limitsSets = sets
    })
  },
  methods: {
    update() {
      if (this.tabId != this.curTab) return
      this.api.get_server_status().then(status => {
        this.currentLimitsSet = status[0]
        this.apiStatus = [
          {
            port: status[1],
            clients: status[2],
            requests: status[3],
            avgTime: (Math.round(status[4] * 1000000) / 1000000).toFixed(6),
            threads: status[5]
          }
        ]
      })
      this.api.get_background_tasks().then(tasks => {
        this.backgroundTasks = []
        for (let x of tasks) {
          var control = ''
          if (x[1] == 'no thread' || x[1] == 'complete') {
            control = 'Start'
          } else {
            control = 'Stop'
          }
          this.backgroundTasks.push({
            name: x[0],
            state: x[1],
            status: x[2],
            control: control
          })
        }
      })
    },
    limitsChange(value) {
      this.api.set_limits_set(value)
    },
    taskControl(name, state) {
      if (state == 'Start') {
        this.api.start_background_task(name)
      } else if (state == 'Stop') {
        this.api.stop_background_task(name)
      }
    }
  }
}
</script>

<style scoped>
.container,
.theme--dark.v-card,
.theme--dark.v-sheet {
  background-color: var(--v-tertiary-darken2);
}
</style>
