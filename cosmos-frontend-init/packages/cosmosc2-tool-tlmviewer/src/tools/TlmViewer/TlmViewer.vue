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
    <top-bar :title="title" />
    <v-container>
      <v-row>
        <v-col>
          <v-select
            class="ma-0 pa-0"
            label="Select Target"
            :items="targets"
            item-text="label"
            item-value="value"
            v-model="selectedTarget"
            @change="targetSelect"
          />
        </v-col>
        <v-col>
          <v-select
            class="ma-0 pa-0"
            label="Select Screen"
            :items="screens"
            v-model="selectedScreen"
            @change="screenSelect"
          />
        </v-col>
        <v-col>
          <v-btn
            class="primary"
            @click="() => showScreen(selectedTarget, selectedScreen)"
          >
            Show Screen
          </v-btn>
        </v-col>
      </v-row>
    </v-container>
    <div class="grid">
      <div
        class="item"
        v-for="def in definitions"
        :key="def.id"
        :id="screenId(def.id)"
        ref="gridItem"
      >
        <div class="item-content">
          <cosmos-screen
            :target="def.target"
            :screen="def.screen"
            :definition="def.definition"
            @close-screen="closeScreen(def.id)"
            @min-max-screen="refreshLayout"
          />
        </div>
      </div>
    </div>
    <!-- Dialogs for opening and saving configs -->
    <open-config-dialog
      v-if="openConfig"
      v-model="openConfig"
      :tool="toolName"
      @success="openConfiguration($event)"
    />
    <save-config-dialog
      v-if="saveConfig"
      v-model="saveConfig"
      :tool="toolName"
      @success="saveConfiguration($event)"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import CosmosScreen from './CosmosScreen'
import OpenConfigDialog from '@cosmosc2/tool-common/src/components/OpenConfigDialog'
import SaveConfigDialog from '@cosmosc2/tool-common/src/components/SaveConfigDialog'
import Muuri from 'muuri'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'

export default {
  components: {
    CosmosScreen,
    TopBar,
    OpenConfigDialog,
    SaveConfigDialog,
  },
  data() {
    return {
      title: 'Telemetry Viewer',
      counter: 0,
      definitions: [],
      targets: [],
      screens: [],
      selectedTarget: '',
      selectedScreen: '',
      grid: null,
      api: null,
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
      ],
      toolName: 'tlm-viewer',
      openConfig: false,
      saveConfig: false,
    }
  },
  created() {
    this.api = new CosmosApi()
    this.api
      .get_target_list({ params: { scope: localStorage.scope } })
      .then((data) => {
        var arrayLength = data.length
        for (var i = 0; i < arrayLength; i++) {
          this.targets.push({ label: data[i], value: data[i] })
        }
        if (!this.selectedTarget) {
          this.selectedTarget = this.targets[0].value
        }
        this.updateScreens()
      })
  },
  mounted() {
    this.grid = new Muuri('.grid', {
      dragEnabled: true,
      // Only allow drags starting from the v-system-bar title
      dragHandle: '.v-system-bar',
    })
    this.grid.on('dragEnd', this.refreshLayout)
    const previousConfig = localStorage['lastconfig__telemetry_viewer']
    if (previousConfig) {
      this.openConfiguration(previousConfig)
    }
  },
  methods: {
    updateScreens() {
      this.screens = []
      Api.get('/cosmos-api/screen/' + this.selectedTarget).then((response) => {
        for (let screen of response.data) {
          this.screens.push(screen)
        }
      })
    },
    targetSelect(target) {
      this.selectedTarget = target
      this.selectedScreen = ''
      this.updateScreens()
    },
    screenSelect(screen) {
      this.selectedScreen = screen
    },
    showScreen(target, screen) {
      this.loadScreen(target, screen).then((response) => {
        this.pushScreen({
          id: this.counter++,
          target: target,
          screen: screen,
          definition: response.data,
        })
      })
    },
    loadScreen(target, screen) {
      return Api.get('/cosmos-api/screen/' + target + '/' + screen)
    },
    pushScreen(definition) {
      this.definitions.push(definition)
      this.$nextTick(function () {
        var items = this.grid.add(
          this.$refs.gridItem[this.$refs.gridItem.length - 1],
          {
            active: false,
          }
        )
        this.grid.show(items)
        this.grid.refreshItems().layout()
      })
    },
    closeScreen(id) {
      var items = this.grid.getItems([
        document.getElementById(this.screenId(id)),
      ])
      this.grid.remove(items)
      this.grid.refreshItems().layout()
      this.definitions = this.definitions.filter((value, index, arr) => {
        return value.id != id
      })
    },
    refreshLayout() {
      setTimeout(() => {
        this.grid.refreshItems().layout()
      }, 600) // TODO: Is 600ms ok for all screens?
    },
    screenId(id) {
      return 'tlmViewerScreen' + id
    },
    openConfiguration: async function (name) {
      localStorage['lastconfig__telemetry_viewer'] = name
      this.counter = 0
      this.definitions = []
      let configResponse = await this.api.load_config(this.toolName, name)
      if (configResponse) {
        const config = JSON.parse(configResponse)
        // Load all the screen definitions from the API at once
        const loadScreenPromises = config.map((definition) => {
          return this.loadScreen(definition.target, definition.screen)
        })
        // Wait until they're all loaded
        Promise.all(loadScreenPromises)
          .then((responses) => {
            // Then add all the screens in order
            responses.forEach((response, index) => {
              const definition = config[index]
              setTimeout(() => {
                this.pushScreen({
                  id: this.counter++,
                  target: definition.target,
                  screen: definition.screen,
                  definition: response.data,
                })
              }, 0) // I don't even know... but Muuri complains if this isn't in a setTimeout
            })
          })
          .then(() => {
            this.$nextTick(this.refreshLayout) // Muuri probably stacked some, so refresh that
          })
      }
    },
    saveConfiguration: function (name) {
      localStorage['lastconfig__telemetry_viewer'] = name
      const gridItems = this.grid.getItems().map((item) => item.getElement().id)
      const config = this.definitions
        .sort((a, b) => {
          // Sort by their current position on the page
          return gridItems.indexOf(this.screenId(a)) >
            gridItems.indexOf(this.screenId(b))
            ? 1
            : -1
        })
        .map((def) => {
          return {
            screen: def.screen,
            target: def.target,
          }
        })
      this.api.save_config(this.toolName, name, JSON.stringify(config))
    },
  },
}
</script>

<style scoped>
.grid {
  position: relative;
}
.item {
  position: absolute;
  display: block;
  margin: 5px;
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
}
</style>
