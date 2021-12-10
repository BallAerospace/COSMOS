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
    <div>
      <v-snackbar
        v-model="showAlert"
        top
        :type="alertType"
        :icon="alertType"
        :timeout="5000"
      >
        <v-icon> mdi-{{ alertType }} </v-icon>
        {{ alert }}
        <template v-slot:action="{ attrs }">
          <v-btn
            text
            v-bind="attrs"
            @click="
              () => {
                showAlert = false
              }
            "
          >
            Close
          </v-btn>
        </template>
      </v-snackbar>

      <div v-show="this.selectedGraphId === null">
        <v-row class="my-5">
          <v-spacer />
          <span>
            Add a graph from the menu bar or select an existing graph to
            continue
          </span>
          <v-spacer />
        </v-row>
      </div>

      <div v-show="this.selectedGraphId !== null" class="row">
        <div class="col-11">
          <target-packet-item-chooser
            @click="addItem"
            button-text="Add Item"
            choose-item
          />
        </div>
        <div class="col-1 text-right">
          <v-btn
            v-show="state === 'pause'"
            class="pulse"
            v-on:click="
              () => {
                state = 'start'
              }
            "
            color="primary"
            fab
          >
            <v-icon large>mdi-play</v-icon>
          </v-btn>
        </div>
      </div>

      <div class="grid">
        <div
          class="item"
          v-for="graph in graphs"
          :key="graph"
          :id="`gridItem${graph}`"
          :ref="`gridItem${graph}`"
        >
          <div class="item-content">
            <graph
              :ref="`graph${graph}`"
              :id="graph"
              :state="state"
              :start-time="startTime"
              :selected-graph-id="selectedGraphId"
              :seconds-graphed="settings.secondsGraphed.value"
              :points-saved="settings.pointsSaved.value"
              :points-graphed="settings.pointsGraphed.value"
              @close-graph="() => closeGraph(graph)"
              @min-max-graph="() => minMaxGraph(graph)"
              @resize="() => resize(graph)"
              @click="() => graphSelected(graph)"
              @mousedown="mousedown"
              @started="graphStarted"
            />
          </div>
        </div>
      </div>
    </div>
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <open-config-dialog
      v-if="showOpenConfig"
      v-model="showOpenConfig"
      :tool="toolName"
      @success="openConfiguration"
    />
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <save-config-dialog
      v-if="showSaveConfig"
      v-model="showSaveConfig"
      :tool="toolName"
      @success="saveConfiguration"
    />
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <settings-dialog
      v-show="showSettingsDialog"
      v-model="showSettingsDialog"
      :settings="settings"
    />
  </div>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import Graph from '@cosmosc2/tool-common/src/components/Graph.vue'
import OpenConfigDialog from '@cosmosc2/tool-common/src/components/OpenConfigDialog'
import SaveConfigDialog from '@cosmosc2/tool-common/src/components/SaveConfigDialog'
import TargetPacketItemChooser from '@cosmosc2/tool-common/src/components/TargetPacketItemChooser'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'
import Muuri from 'muuri'

import SettingsDialog from '@/tools/TlmGrapher/SettingsDialog'

const MURRI_REFRESH_TIME = 250
export default {
  components: {
    Graph,
    OpenConfigDialog,
    SaveConfigDialog,
    SettingsDialog,
    TargetPacketItemChooser,
    TopBar,
  },
  data() {
    return {
      alert: '',
      alertType: 'success',
      showAlert: false,
      title: 'Telemetry Grapher',
      toolName: 'telemetry-grapher',
      showOpenConfig: false,
      showSaveConfig: false,
      showSettingsDialog: false,
      grid: null,
      state: 'stop', // Valid: stop, start, pause
      startTime: null, // Start time in nanoseconds
      // Setup defaults to show an initial graph
      graphs: [0],
      selectedGraphId: 0,
      counter: 1,
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Open Configuration',
              icon: 'mdi-folder-open',
              command: () => {
                this.showOpenConfig = true
              },
            },
            {
              label: 'Save Configuration',
              icon: 'mdi-content-save',
              command: () => {
                this.showSaveConfig = true
              },
            },
          ],
        },
        {
          label: 'Graph',
          items: [
            {
              label: 'Add Graph',
              icon: 'mdi-plus',
              command: () => {
                this.addGraph()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Start',
              icon: 'mdi-play',
              command: () => {
                this.state = 'start'
              },
            },
            {
              label: 'Pause',
              icon: 'mdi-pause',
              command: () => {
                this.state = 'pause'
              },
            },
            {
              label: 'Resume',
              icon: 'mdi-play-pause',
              command: () => {
                this.state = 'start'
              },
            },
            {
              label: 'Stop',
              icon: 'mdi-stop',
              command: () => {
                this.state = 'stop'
              },
            },
            {
              divider: true,
            },
            {
              label: 'Settings',
              icon: 'mdi-cog',
              command: () => {
                this.showSettingsDialog = true
              },
            },
          ],
        },
      ],
      settings: {
        secondsGraphed: {
          title: 'Seconds Graphed',
          value: 1000,
          rules: [(value) => !!value || 'Required'],
        },
        pointsSaved: {
          title: 'Points Saved',
          value: 1000000,
          rules: [(value) => !!value || 'Required'],
        },
        pointsGraphed: {
          title: 'Points Graphed',
          value: 1000,
          rules: [(value) => !!value || 'Required'],
        },
      },
    }
  },
  mounted: function () {
    this.grid = new Muuri('.grid', {
      dragEnabled: true,
      layoutOnResize: true,
      // Only allow drags starting from the v-system-bar title
      dragHandle: '.v-system-bar',
    })
    const previousConfig = this.getLocalStorageConfig()
    if (previousConfig) {
      this.openConfiguration(previousConfig)
    }
  },
  methods: {
    mousedown: function ($event) {
      // Only respond to left button mousedown events
      if ($event.button === 0 || $event.which === 1) {
        this.state = 'pause'
      }
    },
    alertHandler: function (event) {
      this.alert = event.text
      this.alertType = event.type
      this.showAlert = true
    },
    setLocalStorageConfig: function (value) {
      localStorage['lastconfig__telemetry_grapher'] = value
    },
    getLocalStorageConfig: function () {
      return localStorage['lastconfig__telemetry_grapher']
    },
    graphSelected: function (id) {
      this.selectedGraphId = id
    },
    addItem: function (item, startGraphing = true) {
      this.$refs[`graph${this.selectedGraphId}`][0].addItems([item])
      if (startGraphing === true) {
        this.state = 'start'
      }
    },
    addGraph: function () {
      const id = this.counter
      this.graphs.push(id)
      this.counter += 1
      this.$nextTick(function () {
        var items = this.grid.add(this.$refs[`gridItem${id}`], {
          active: false,
        })
        this.grid.show(items)
        this.selectedGraphId = id
        setTimeout(() => {
          this.grid.refreshItems().layout()
        }, MURRI_REFRESH_TIME)
      })
    },
    closeGraph: function (id) {
      var items = this.grid.getItems([document.getElementById(`gridItem${id}`)])
      this.grid.remove(items)
      this.graphs.splice(this.graphs.indexOf(id), 1)
      this.selectedGraphId = null
    },
    closeAllGraphs: function () {
      // Make a copy of this.graphs to iterate on since closeGraph modifies in place
      for (let graph of [...this.graphs]) {
        this.closeGraph(graph)
      }
      this.counter = 0
    },
    minMaxGraph: function (id) {
      this.selectedGraphId = id
      setTimeout(
        () => {
          this.grid.refreshItems().layout()
        },
        MURRI_REFRESH_TIME * 2 // Double the time since there is more animation
      )
    },
    resize: function (id) {
      this.selectedGraphId = id
      setTimeout(
        () => {
          this.grid.refreshItems().layout()
        },
        MURRI_REFRESH_TIME * 2 // Double the time since there is more animation
      )
    },
    graphStarted: function (time) {
      // Only set startTime once when notified by the first graph to start
      // This allows us to have a uniform start time on all graphs
      if (this.startTime === null) {
        this.startTime = time
      }
    },
    saveConfiguration: function (name) {
      const config = this.graphs.map((graphId) => {
        const vueGraph = this.$refs[`graph${graphId}`][0]
        return {
          items: vueGraph.items,
          title: vueGraph.title,
          fullWidth: vueGraph.fullWidth,
          fullHeight: vueGraph.fullHeight,
          graphMinX: vueGraph.graphMinX,
          graphMaxX: vueGraph.graphMaxX,
        }
      })
      new CosmosApi()
        .save_config(this.toolName, name, JSON.stringify(config))
        .then((response) => {
          this.setLocalStorageConfig(name)
          this.alertHandler({
            text: `Saved configuartion: ${name}`,
            type: 'success',
          })
        })
        .catch((error) => {
          if (error) {
            this.alertHandler({
              text: `Failed to save configuration: ${name}. ${error}`,
              type: 'error',
            })
          }
        })
    },
    openConfiguration: function (name) {
      this.setLocalStorageConfig(name)
      new CosmosApi()
        .load_config(this.toolName, name)
        .then((response) => {
          if (response) {
            this.loadConfiguration(response)
          }
        })
        .catch((error) => {
          if (error) {
            this.alertHandler({
              text: `Failed to load configuration: ${name}. ${error}`,
              type: 'error',
            })
            this.setLocalStorageConfig(null)
          }
        })
    },
    async loadConfiguration(configStr) {
      this.closeAllGraphs()
      await this.$nextTick()
      const config = JSON.parse(configStr)
      for (let graph of config) {
        this.addGraph()
      }
      await this.$nextTick()
      const that = this
      config.forEach(function (graph, i) {
        let vueGraph = that.$refs[`graph${i}`][0]
        vueGraph.title = graph.title
        vueGraph.fullWidth = graph.fullWidth
        vueGraph.fullHeight = graph.fullHeight
        vueGraph.graphMinX = graph.graphMinX
        vueGraph.graphMaxX = graph.graphMaxX
        vueGraph.resize()
        vueGraph.addItems([...graph.items])
      })
      this.state = 'start'
    },
  },
}
</script>

<style lang="scss" scoped>
.v-navigation-drawer {
  z-index: 2;
}
.theme--dark.v-navigation-drawer {
  background-color: var(--v-primary-darken2);
}
.grid {
  position: relative;
}
.item {
  position: absolute;
  z-index: 1;
}
.item.muuri-item-dragging {
  z-index: 3;
}
.item.muuri-item-releasing {
  z-index: 2;
}
.item.muuri-item-hidden {
  z-index: 0;
}
.item-content {
  position: relative;
  cursor: pointer;
  border-radius: 6px;
  margin: 5px;
}

.pulse {
  animation: pulse 1s infinite;
}

@keyframes pulse {
  0% {
    opacity: 1;
  }

  50% {
    opacity: 0.5;
  }
}
</style>
