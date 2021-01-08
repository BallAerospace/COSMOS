<template>
  <div>
    <app-nav />
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
          <v-btn class="primary" @click="showScreen">Show Screen</v-btn>
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
          <CosmosScreen
            :target="def.target"
            :screen="def.screen"
            :definition="def.definition"
            @close-screen="closeScreen(def.id)"
            @min-max-screen="minMaxScreen(def.id)"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import AppNav from '@/AppNav'
import { CosmosApi } from '@/services/cosmos-api'
import CosmosScreen from './CosmosScreen'
import Muuri from 'muuri'

export default {
  components: {
    AppNav,
    CosmosScreen,
  },
  data() {
    return {
      counter: 0,
      definitions: [],
      targets: [],
      screens: [],
      selectedTarget: '',
      selectedScreen: '',
      grid: null,
      api: null,
    }
  },
  created() {
    this.api = new CosmosApi()
    this.api.get_target_list({ params: { scope: 'DEFAULT' } }).then((data) => {
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
  },
  methods: {
    updateScreens() {
      this.screens = []
      axios
        .get('http://localhost:7777/screen/' + this.selectedTarget, {
          params: { scope: 'DEFAULT' },
        })
        .then((response) => {
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
    showScreen() {
      axios
        .get(
          'http://localhost:7777/screen/' +
            this.selectedTarget +
            '/' +
            this.selectedScreen,
          {
            params: { scope: 'DEFAULT' },
          }
        )
        .then((response) => {
          this.definitions.push({
            id: this.counter,
            target: this.selectedTarget,
            screen: this.selectedScreen,
            definition: response.data,
          })
          this.counter += 1
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
    minMaxScreen(id) {
      setTimeout(() => {
        this.grid.refreshItems().layout()
      }, 500) // TODO: Is 500ms ok for all screens?
    },
    screenId(id) {
      return 'tlmViewerScreen' + id
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
