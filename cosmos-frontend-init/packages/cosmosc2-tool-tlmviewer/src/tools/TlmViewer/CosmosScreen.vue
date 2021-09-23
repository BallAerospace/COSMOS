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
    <v-card>
      <v-system-bar>
        <v-icon v-if="errors.length !== 0">mdi-alert</v-icon>
        <v-spacer />
        <span>{{ target }} {{ screen }}</span>
        <v-spacer />
        <v-icon @click="openEdit">mdi-pencil</v-icon>
        <v-icon @click="minMaxTransition">mdi-window-minimize</v-icon>
        <v-icon @click="$emit('close-screen')">mdi-close-box</v-icon>
      </v-system-bar>
      <v-expand-transition>
        <div class="pa-1" ref="screen" v-show="expand">
          <vertical-widget
            :widgets="layoutStack[0].widgets"
            v-on="$listeners"
          />
        </div>
      </v-expand-transition>
    </v-card>
    <v-dialog v-model="editDialog" width="800">
      <v-card>
        <v-card-title>
          <span class="text-h5">Edit Screen</span>
        </v-card-title>
        <v-alert type="error" v-model="showSaveAlert" dismissible>
          {{ saveAlert }}
        </v-alert>
        <v-card-text>
          <v-textarea auto-grow v-model="currentDefinition"></v-textarea>
        </v-card-text>
        <v-card-actions>
          <v-btn color="primary" @click="saveEdit">Save</v-btn>
          <v-btn color="primary" @click="cancelEdit">Cancel</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import { ConfigParserService } from '@cosmosc2/tool-common/src/services/config-parser'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import Vue from 'vue'
import upperFirst from 'lodash/upperFirst'
import camelCase from 'lodash/camelCase'

// Globally register all XxxWidget.vue components
const requireComponent = require.context(
  // The relative path of the components folder
  '@cosmosc2/tool-common/src/components/widgets',
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
      currentDefinition: this.definition,
      backup: '',
      editDialog: false,
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
      showSaveAlert: false,
      saveAlert: '',
      errors: [],
    }
  },
  // Called when an error from any descendent component is captured
  // We need this because an error can occur from any of the children
  // in the widget stack and are typically thrown on create()
  errorCaptured(err, vm, info) {
    if (err.usage) {
      this.errors.push(err.usage)
    } else {
      this.errors.push(err)
    }
    return false
  },
  created() {
    this.api = new CosmosApi()
    this.configParser = new ConfigParserService()
    this.parseDefinition()
  },
  mounted() {
    let refreshInterval = this.pollingPeriod * 1000
    this.updater = setInterval(() => {
      this.update()
    }, refreshInterval)
  },
  updated() {
    this.$nextTick(function () {
      // This ensures that we only display the errors after they have
      // been parsed by the errorCaptured handler
      if (this.editDialog && this.errors.length > 0) {
        this.saveAlert = this.errors.toString()
        this.showSaveAlert = true
      }
    })
  },
  destroyed() {
    if (this.updater != null) {
      clearInterval(this.updater)
      this.updater = null
    }
  },
  methods: {
    parseDefinition() {
      // Each time we start over and parse the screen definition
      this.showSaveAlert = false
      this.errors = []
      this.namedWidgets = {}
      this.layoutStack = []
      // Every screen starts with a VerticalWidget
      this.layoutStack.push({
        type: 'VerticalWidget',
        parameters: [],
        widgets: [],
      })
      this.currentLayout = this.layoutStack[this.layoutStack.length - 1]

      this.configParser.parse_string(
        this.currentDefinition,
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
                break
              case 'END':
                this.configParser.verify_num_parameters(0, 0, `${keyword}`)
                this.layoutStack.pop()
                this.currentLayout = this.layoutStack[
                  this.layoutStack.length - 1
                ]
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
    openEdit() {
      // Make a copy in case they edit and cancel
      this.backup = this.currentDefinition.repeat(1)
      this.editDialog = true
    },
    cancelEdit() {
      this.editDialog = false
      // Restore the backup since we cancelled
      this.currentDefinition = this.backup
      this.parseDefinition()
    },
    saveEdit() {
      this.parseDefinition()
      // After parsing wait and see if there are errors before saving
      this.$nextTick(function () {
        if (this.errors.length === 0) {
          Api.post('/cosmos-api/screen/', {
            data: {
              scope: localStorage.scope,
              target: this.target,
              screen: this.screen,
              text: this.currentDefinition,
            },
          }).catch((error) => {
            this.saveAlert = error
            this.showSaveAlert = true
          })
          this.editDialog = false
        }
      })
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
        keyword === 'MATRIXBYCOLUMNS' ||
        keyword === 'TABBOOK' ||
        keyword === 'TABITEM' ||
        keyword === 'CANVAS' ||
        keyword === 'RADIOGROUP' ||
        keyword === 'SCROLLWINDOW'
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

<style scoped>
.v-card {
  background-color: var(--v-tertiary-darken2);
}
.v-textarea >>> textarea {
  padding: 5px;
  background-color: var(--v-tertiary-darken1) !important;
}
</style>
