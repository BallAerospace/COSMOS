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
    <app-nav :menus="menus" />
    <v-navigation-drawer
      absolute
      permanent
      expand-on-hover
      data-test="grapher-controls"
    >
      <v-list-item class="px-2">
        <v-list-item-avatar>
          <v-icon>mdi-chart-line</v-icon>
        </v-list-item-avatar>
        <v-list-item-title>Grapher Controls</v-list-item-title>
      </v-list-item>

      <v-divider></v-divider>

      <v-list dense>
        <v-list-item
          v-for="item in controls"
          :key="item.title"
          @click="item.action"
        >
          <v-list-item-icon>
            <v-icon>{{ item.icon }}</v-icon>
          </v-list-item-icon>

          <v-list-item-content>
            <v-list-item-title>{{ item.title }}</v-list-item-title>
          </v-list-item-content>
        </v-list-item>
      </v-list>

      <v-divider></v-divider>
      <v-list dense>
        <v-list-item v-for="item in settings" :key="item.title">
          <v-list-item-icon>
            <v-icon>{{ item.icon }}</v-icon>
          </v-list-item-icon>

          <v-list-item-content>
            <v-list-item-title>
              <v-text-field
                hide-details="auto"
                type="number"
                :hint="item.hint"
                :rules="item.rules"
                :label="item.title"
                v-model.number="item.value"
              ></v-text-field>
            </v-list-item-title>
          </v-list-item-content>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>
    <div class="c-tlmgrapher__contents">
      <TargetPacketItemChooser
        @click="addItem($event)"
        buttonText="Add Item"
        :chooseItem="true"
      ></TargetPacketItemChooser>
      <div class="grid">
        <div
          class="item"
          v-for="graph in graphs"
          :key="graph"
          :id="graphId(graph)"
          ref="gridItem"
        >
          <div class="item-content">
            <graph
              :ref="'graph' + graph"
              :id="graph"
              :state="state"
              :startTime="startTime"
              :selectedGraphId="selectedGraphId"
              :secondsGraphed="settings.secondsGraphed.value"
              :pointsSaved="settings.pointsSaved.value"
              :pointsGraphed="settings.pointsGraphed.value"
              @close-graph="closeGraph(graph)"
              @min-max-graph="minMaxGraph(graph)"
              @resize="resize(graph)"
              @click="graphSelected(graph)"
              @started="graphStarted($event)"
            />
          </div>
        </div>
      </div>
    </div>
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
import Graph from '@/components/Graph.vue'
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'
import OpenConfigDialog from '@/components/OpenConfigDialog'
import SaveConfigDialog from '@/components/SaveConfigDialog'
import { CosmosApi } from '@/services/cosmos-api'
import Muuri from 'muuri'

const MURRI_REFRESH_TIME = 250
export default {
  components: {
    AppNav,
    OpenConfigDialog,
    SaveConfigDialog,
    TargetPacketItemChooser,
    Graph,
  },
  data() {
    return {
      toolName: 'telemetry-grapher',
      api: null,
      openConfig: false,
      saveConfig: false,
      state: 'stop', // Valid: stop, start, pause
      grid: null,
      startTime: null, // Start time in nanoseconds
      // Setup defaults to show an initial graph
      graphs: [1],
      selectedGraphId: 1,
      counter: 2,
      controls: {
        start: {
          title: 'Start',
          icon: 'mdi-play',
          action: () => {
            this.state = 'start'
          },
        },
        pause: {
          title: 'Pause',
          icon: 'mdi-pause',
          action: () => {
            if (this.controls.pause.title === 'Pause') {
              this.state = 'pause'
              this.controls.pause.title = 'Resume'
              this.controls.pause.icon = 'mdi-play-pause'
            } else {
              this.state = 'start'
              this.controls.pause.title = 'Pause'
              this.controls.pause.icon = 'mdi-pause'
            }
          },
        },
        stop: {
          title: 'Stop',
          icon: 'mdi-stop',
          action: () => {
            this.state = 'stop'
          },
        },
      },
      menus: [
        {
          label: 'File',
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
          ],
        },
        {
          label: 'Graph',
          items: [
            {
              label: 'Add Graph',
              command: () => {
                this.addGraph()
              },
            },
            {
              label: 'Edit Graph',
              command: () => {
                this.$refs['graph' + this.selectedGraphId][0].editGraph = true
              },
            },
          ],
        },
      ],
      settings: {
        secondsGraphed: {
          title: 'Seconds Graphed',
          icon: 'mdi-cog',
          value: 1000,
          rules: [(value) => !!value || 'Required'],
        },
        pointsSaved: {
          title: 'Points Saved',
          value: 1000000,
          hint: 'Increasing may cause issues',
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
  created() {
    this.api = new CosmosApi()
  },
  mounted() {
    this.grid = new Muuri('.grid', {
      dragEnabled: true,
      layoutOnResize: true,
      // Only allow drags starting from the v-system-bar title
      dragHandle: '.v-system-bar',
    })
  },
  methods: {
    addItem(item, startGraphing = true) {
      if (this.selectedGraphId === null) return
      this.$refs['graph' + this.selectedGraphId][0].addItem(item)
      if (startGraphing === true) {
        this.state = 'start'
      }
    },
    addGraph() {
      this.selectedGraphId = this.counter
      this.graphs.push(this.counter)
      this.counter += 1
      this.$nextTick(function () {
        var items = this.grid.add(
          this.$refs.gridItem[this.$refs.gridItem.length - 1],
          { active: false }
        )
        this.grid.show(items)
        setTimeout(() => {
          this.grid.refreshItems().layout()
        }, MURRI_REFRESH_TIME)
      })
    },
    graphId(id) {
      return 'tlmGrapherGraph' + id
    },
    closeGraph(id) {
      var items = this.grid.getItems([
        document.getElementById(this.graphId(id)),
      ])
      this.grid.remove(items)
      this.graphs.splice(this.graphs.indexOf(id), 1)
      this.selectedGraphId = null
    },
    closeAllGraphs() {
      // Make a copy of this.graphs to iterate on since closeGraph modifies in place
      for (let graph of [...this.graphs]) {
        this.closeGraph(graph)
      }
      this.counter = 1
    },
    minMaxGraph(id) {
      this.selectedGraphId = id
      setTimeout(() => {
        this.grid.refreshItems().layout()
      }, MURRI_REFRESH_TIME * 2) // Double the time since there is more animation
    },
    resize(id) {
      this.selectedGraphId = id
      setTimeout(() => {
        this.grid.refreshItems().layout()
      }, MURRI_REFRESH_TIME)
    },
    graphSelected(id) {
      this.selectedGraphId = id
    },
    graphStarted(time) {
      // Only set startTime once when notified by the first graph to start
      // This allows us to have a uniform start time on all graphs
      if (this.startTime === null) {
        this.startTime = time
      }
    },
    async openConfiguration(name) {
      this.closeAllGraphs()
      let config = await this.api.load_config(this.toolName, name)
      let graphs = JSON.parse(config)
      let graphId = 0
      for (let graph of graphs) {
        graphId += 1
        await this.addGraph()
        let vueGraph = this.$refs['graph' + graphId][0]
        vueGraph.title = graph.title
        vueGraph.fullWidth = graph.fullWidth
        vueGraph.fullHeight = graph.fullHeight
        vueGraph.graphMinX = graph.graphMinX
        vueGraph.graphMaxX = graph.graphMaxX
        vueGraph.resize()
        for (let item of graph.items) {
          this.addItem(
            {
              targetName: item.targetName,
              packetName: item.packetName,
              itemName: item.itemName,
            },
            false
          )
        }
      }
      this.state = 'start'
    },
    saveConfiguration(name) {
      let config = []
      for (let graphId of this.graphs) {
        const vueGraph = this.$refs['graph' + graphId][0]
        config.push({
          title: vueGraph.title,
          fullWidth: vueGraph.fullWidth,
          fullHeight: vueGraph.fullHeight,
          items: vueGraph.items,
          graphMinX: vueGraph.graphMinX,
          graphMaxX: vueGraph.graphMaxX,
        })
      }
      this.api.save_config(this.toolName, name, JSON.stringify(config))
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
.c-tlmgrapher__contents {
  position: relative;
  left: 56px;
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
</style>
