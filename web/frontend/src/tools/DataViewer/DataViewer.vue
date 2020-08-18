<template>
  <div>
    <app-nav app :menus="menus" />
    <v-card>
      <v-tabs v-model="curTab" fixed-tabs>
        <v-tab v-for="(tab, index) in tabs" :key="index">{{ tab.name }}</v-tab>
      </v-tabs>
      <v-tabs-items v-model="curTab">
        <v-tab-item v-for="(tab, index) in tabs" :key="index">
          <component
            ref="component"
            :is="tab.component"
            v-bind:tabId="index"
            v-bind:curTab="curTab"
            v-bind:refreshInterval="refreshInterval"
          ></component>
        </v-tab-item>
      </v-tabs-items>
    </v-card>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import { ConfigParserService } from '@/services/config-parser'
import { CosmosApi } from '@/services/cosmos-api'
import Vue from 'vue'
import upperFirst from 'lodash/upperFirst'
import camelCase from 'lodash/camelCase'

// Globally register all XxxWidget.vue components
const requireComponent = require.context(
  // The relative path of the components folder
  '@/tools/DataViewer',
  // Whether or not to look in subfolders
  false,
  // The regular expression used to match base component filenames
  /[A-Z]\w+Component\.vue$/
)

requireComponent.keys().forEach(fileName => {
  // Get component config
  const componentConfig = requireComponent(fileName)

  // Get PascalCase name of component
  const componentName = upperFirst(
    camelCase(
      // Gets the file name regardless of folder depth
      fileName
        .split('/')
        .pop()
        .replace(/\.\w+$/, '')
    )
  )

  // Register component globally
  Vue.component(
    componentName,
    // Look for the component options on `.default`, which will
    // exist if the component was exported with `export default`,
    // otherwise fall back to module's root.
    componentConfig.default || componentConfig
  )
})

export default {
  components: {
    AppNav
  },
  data() {
    return {
      api: null,
      configParser: null,
      curTab: null,
      tabs: [],
      updater: null,
      refreshInterval: 1000,
      optionsDialog: false,
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Reset',
              command: () => {
                this.$refs.component.forEach(child => {
                  child.reset()
                })
              }
            }
          ]
        }
      ]
    }
  },
  created() {
    this.api = new CosmosApi()
    this.config = `
COMPONENT "Health Status" dump_component.rb
  PACKET INST HEALTH_STATUS

COMPONENT "ADCS" data_viewer_component.rb
  PACKET INST ADCS

COMPONENT "Other Packets" data_viewer_component.rb
  PACKET INST PARAMS
  PACKET INST IMAGE

COMPONENT "Operators" text_component.rb "OPERATOR_NAME"
  PACKET SYSTEM META
`
    this.configParser = new ConfigParserService()
    this.configParser.parse_string(
      this.config,
      '',
      false,
      true,
      (keyword, parameters) => {
        if (keyword) {
          switch (keyword) {
            case 'COMPONENT':
              this.configParser.verify_num_parameters(
                2,
                null,
                `${keyword} <tab name> <component class> <component options ...>`
              )
              let componentName = parameters[1]
              if (componentName.includes('.rb')) {
                componentName = upperFirst(
                  camelCase(componentName.slice(0, -3))
                )
              }
              this.tabs.push({
                name: parameters[0],
                component: componentName,
                options: parameters.slice(2)
              })
              break
          }
        }
      }
    )
  }
}
</script>

<style scoped></style>
