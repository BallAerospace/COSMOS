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
          v-for="plot in plots"
          :key="plot"
          :id="plotId(plot)"
          ref="gridItem"
        >
          <div class="item-content">
            <CosmosChartuPlot
              :ref="'plot' + plot"
              :id="plot"
              :state="state"
              :selectedPlotId="selectedPlotId"
              :secondsPlotted="settings.secondsPlotted.value"
              :pointsSaved="settings.pointsSaved.value"
              :pointsPlotted="settings.pointsPlotted.value"
              :refreshRate="settings.refreshRate.value"
              @closePlot="closePlot(plot)"
              @minMaxPlot="minMaxPlot(plot)"
              @resize="resize(plot)"
              @click="plotSelected(plot)"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import CosmosChartuPlot from '@/components/CosmosChartuPlot.vue'
// import CosmosChartJS from '@/components/CosmosChartJS.vue'
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'
import { CosmosApi } from '@/services/cosmos-api'
import * as Muuri from 'muuri'
import pull from 'lodash/pull'

export default {
  components: {
    AppNav,
    TargetPacketItemChooser,
    CosmosChartuPlot
    // CosmosChartJS
  },
  data() {
    return {
      api: null,
      state: 'stop', // Valid: stop, start, pause
      grid: null,
      // Setup defaults to show an initial plot
      plots: [1],
      selectedPlotId: 1,
      counter: 2,
      controls: {
        start: {
          title: 'Start',
          icon: 'mdi-play',
          action: () => {
            this.state = 'start'
          }
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
          }
        },
        stop: {
          title: 'Stop',
          icon: 'mdi-stop',
          action: () => {
            this.state = 'stop'
          }
        }
      },
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Load Configuration',
              command: () => {
                this.loadConfiguration()
              }
            },
            {
              label: 'Save Configuration',
              command: () => {
                this.saveConfiguration()
              }
            }
          ]
        },
        {
          label: 'Plot',
          items: [
            {
              label: 'Add Plot',
              command: () => {
                this.addPlot()
              }
            }
          ]
        }
      ],
      settings: {
        secondsPlotted: {
          title: 'Seconds Plotted',
          icon: 'mdi-cog',
          value: 1000,
          rules: [value => !!value || 'Required']
        },
        pointsSaved: {
          title: 'Points Saved',
          value: 1000000,
          hint: 'Increasing may cause issues',
          rules: [value => !!value || 'Required']
        },
        pointsPlotted: {
          title: 'Points Plotted',
          value: 1000,
          rules: [value => !!value || 'Required']
        },
        refreshRate: {
          title: 'Refresh Rate (ms)',
          value: 1000,
          rules: [
            value => !!value || 'Required',
            value => (value && value >= 100) || 'Minimum 100ms'
          ]
        }
      }
    }
  },
  created() {
    this.api = new CosmosApi()
  },
  mounted() {
    this.grid = new Muuri('.grid', {
      dragEnabled: true,
      dragStartPredicate: {
        // Only allow drags starting from the v-system-bar title
        handle: '.v-system-bar'
      }
    })
  },
  methods: {
    addItem(item) {
      this.$refs['plot' + this.selectedPlotId][0].addItem(item)
    },
    addPlot() {
      this.selectedPlotId = this.counter
      this.plots.push(this.counter)
      this.counter += 1
      this.$nextTick(function() {
        this.grid.add(this.$refs.gridItem[this.$refs.gridItem.length - 1])
      })
    },
    plotId(id) {
      return 'tlmGrapherPlot' + id
    },
    closePlot(id) {
      this.grid.remove(document.getElementById(this.plotId(id)))
      pull(this.plots, id)
      this.selectedPlotId = null
    },
    closeAllPlots() {
      for (let plot of this.plots) {
        this.closePlot(plot)
      }
      this.counter = 1
    },
    minMaxPlot(id) {
      setTimeout(() => {
        this.grid.refreshItems().layout()
      }, 500) // TODO: Is 500ms ok for all plots?
    },
    resize(id) {
      this.grid.refreshItems().layout()
    },
    plotSelected(id) {
      this.selectedPlotId = id
    },
    async loadConfiguration() {
      this.closeAllPlots()
      let plots = JSON.parse(await this.api.load_config('tlmgrapher'))
      let plotId = 0
      for (let plot in plots) {
        plotId += 1
        await this.addPlot()
        for (let item of plots[plot].items) {
          this.addItem({
            targetName: item.targetName,
            packetName: item.packetName,
            itemName: item.itemName
          })
          let vuePlot = this.$refs['plot' + plotId][0]
          vuePlot.fullWidth = plots[plot].fullWidth
          vuePlot.fullHeight = plots[plot].fullHeight
          vuePlot.resize()
        }
      }
    },
    saveConfiguration() {
      let config = {}
      for (let plotId of this.plots) {
        const vuePlot = this.$refs['plot' + plotId][0]
        config[this.plotId(plotId)] = {
          fullWidth: vuePlot.fullWidth,
          fullHeight: vuePlot.fullHeight,
          items: vuePlot.items
        }
      }
      this.api.save_config('tlmgrapher', JSON.stringify(config))
    }
  }
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
