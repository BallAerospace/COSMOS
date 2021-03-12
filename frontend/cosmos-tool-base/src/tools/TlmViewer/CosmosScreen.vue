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
  <v-card>
    <v-system-bar>
      <v-spacer />
      <span>{{ target }} {{ screen }}</span>
      <v-spacer />
      <v-icon @click="minMaxTransition">mdi-window-minimize</v-icon>
      <v-icon @click="$emit('close-screen')">mdi-close-box</v-icon>
    </v-system-bar>
    <v-expand-transition>
      <div class="pa-1" ref="screen" v-show="expand">
        <VerticalWidget :widgets="layoutStack[0].widgets" />
      </div>
    </v-expand-transition>
  </v-card>
</template>

<script>
import { ConfigParserService } from '@/services/config-parser'
import { CosmosApi } from '@/services/cosmos-api'
import Vue from 'vue'
import upperFirst from 'lodash/upperFirst'
import camelCase from 'lodash/camelCase'

// Globally register all XxxWidget.vue components
const requireComponent = require.context(
  // The relative path of the components folder
  '@/components/widgets',
  // Whether or not to look in subfolders
  false,
  // The regular expression used to match base component filenames
  /[A-Z]\w+Widget\.vue$/
)

requireComponent.keys().forEach((filename) => {
  // Get component config
  const componentConfig = requireComponent(filename)

  // Get PascalCase name of component
  const componentName = upperFirst(
    camelCase(
      // Gets the filename regardless of folder depth
      filename
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
  props: {
    target: {
      type: String,
      default: '',
    },
    screen: {
      type: String,
      default: '',
    },
    definition: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      api: null,
      expand: true,
      configParser: null,
      currentLayout: null,
      layoutStack: [],
      namedWidgets: {},
      width: null,
      height: null,
      fixed: null,
      globalSettings: [],
      globalSubsettings: [],
      substitute: false,
      original_target_name: null,
      force_substitute: false,
      pollingPeriod: 1,
    }
  },
  created() {
    this.api = new CosmosApi()
    this.configParser = new ConfigParserService()
    this.configParser.parse_string(
      this.definition,
      '',
      false,
      true,
      (keyword, parameters) => {
        if (keyword) {
          switch (keyword) {
            case 'SCREEN':
              this.configParser.verify_num_parameters(
                3,
                4,
                `${keyword} <Width or AUTO> <Height or AUTO> <Polling Period> <FIXED>`
              )
              this.width = parseInt(parameters[0])
              this.height = parseInt(parameters[1])
              this.pollingPeriod = parseFloat(parameters[2])
              if (parameters.length === 4) {
                this.fixed = true
              } else {
                this.fixed = false
              }
              // Every screen starts with a VerticalWidget
              this.layoutStack.push({
                type: 'VerticalWidget',
                parameters: [],
                widgets: [],
              })
              this.currentLayout = this.layoutStack[this.layoutStack.length - 1]
              break
            case 'END':
              this.configParser.verify_num_parameters(0, 0, `${keyword}`)
              this.layoutStack.pop()
              this.currentLayout = this.layoutStack[this.layoutStack.length - 1]
              break
            case 'SETTING':
              this.currentLayout.widgets[
                this.currentLayout.widgets.length - 1
              ].settings.push(parameters)
              break
            case 'SUBSETTING':
              // Just push it onto the settings array and the widget will figure it out
              this.currentLayout.widgets[
                this.currentLayout.widgets.length - 1
              ].settings.push(parameters)
              break
            case 'GLOBAL_SETTING':
              this.globalSettings.push(parameters)
              break
            case 'GLOBAL_SUBSETTING':
              this.globalSubsettings.push(parameters)
              break
            default:
              this.process_widget(keyword, parameters)
              break
          } // switch keyword
        } // if keyword
      }
    )
    this.applyGlobalSettings(this.layoutStack[0].widgets)
  },
  mounted() {
    let refreshInterval = this.pollingPeriod * 1000
    this.updater = setInterval(() => {
      this.update()
    }, refreshInterval)
  },
  destroyed() {
    if (this.updater != null) {
      clearInterval(this.updater)
      this.updater = null
    }
  },
  methods: {
    // Called by button scripts to get named widgets
    // Underscores used to match COSMOS API rather than Javascript convention
    get_named_widget(name) {
      return this.namedWidgets[name]
    },
    // Called by named widgets to register with the screen
    setNamedWidget(name, widget) {
      this.namedWidgets[name] = widget
    },
    update() {
      if (this.$store.state.tlmViewerItems.length !== 0) {
        this.api
          .get_tlm_values(this.$store.state.tlmViewerItems)
          .then((data) => {
            this.$store.commit('tlmViewerUpdateValues', data)
          })
      }
    },
    minMaxTransition() {
      this.expand = !this.expand
      this.$emit('min-max-screen')
    },
    process_widget(keyword, parameters) {
      var widgetName = null
      if (keyword === 'NAMED_WIDGET') {
        this.configParser.verify_num_parameters(
          2,
          null,
          `${keyword} <Widget Name> <Widget Type> <Widget Settings... (optional)>`
        )
        widgetName = parameters[0].toUpperCase()
        keyword = parameters[1].toUpperCase()
        parameters = parameters.slice(2, parameters.length)
      } else {
        this.configParser.verify_num_parameters(
          0,
          null,
          `${keyword} <Widget Settings... (optional)>`
        )
      }
      const componentName =
        keyword.charAt(0).toUpperCase() +
        keyword.slice(1).toLowerCase() +
        'Widget'
      let settings = []
      if (widgetName !== null) {
        // Push a reference to the screen so the layout can register when it is created
        // We do this because the widget isn't actually created until
        // the layout happens with <component :is='type'>
        settings.push(['NAMED_WIDGET', widgetName, this])
      }
      // If this is a layout widget we add it to the layoutStack and reset the currentLayout
      if (
        keyword.includes('VERTICAL') ||
        keyword.includes('HORIZONTAL') ||
        keyword.includes('MATRIXBYCOLUMNS') ||
        keyword.startsWith('TAB') ||
        keyword === 'CANVAS' ||
        keyword === 'RADIOGROUP'
      ) {
        const layout = {
          type: componentName,
          parameters: parameters,
          settings: settings,
          widgets: [],
        }
        this.layoutStack.push(layout)
        this.currentLayout.widgets.push(layout)
        this.currentLayout = layout
      } else {
        // Buttons require a reference to the screen to call get_named_widget
        if (keyword.includes('BUTTON')) {
          settings.push(['SCREEN', this])
        }
        this.currentLayout.widgets.push({
          type: componentName,
          parameters: parameters,
          settings: settings,
        })
      }
    },
    applyGlobalSettings(widgets) {
      this.globalSettings.forEach((setting) => {
        widgets.forEach((widget) => {
          // widget.type is already the full camelcase widget name like LabelWidget
          // so we have to lower case both and tack on 'widget' to compare
          if (
            widget.type.toLowerCase() ===
            setting[0].toLowerCase() + 'widget'
          ) {
            widget.settings.push(setting.slice(1))
          }
          // Recursively apply to all widgets contained in layouts
          if (widget.widgets) {
            this.applyGlobalSettings(widget.widgets)
          }
        })
      })
    },
  },
}
</script>

<style lang="scss" scoped>
.v-card {
  background-color: var(--v-tertiary-darken2);
}
</style>
