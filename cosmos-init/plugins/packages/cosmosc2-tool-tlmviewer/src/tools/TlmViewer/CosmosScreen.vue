<!--
# Copyright 2022 Ball Aerospace & Technologies Corp.
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
        <div v-show="errors.length !== 0">
          <v-tooltip top>
            <template v-slot:activator="{ on, attrs }">
              <div v-on="on" v-bind="attrs">
                <v-icon
                  data-test="error-graph-icon"
                  @click="errorDialog = true"
                >
                  mdi-alert
                </v-icon>
              </div>
            </template>
            <span> Errors </span>
          </v-tooltip>
        </div>
        <v-spacer />
        <span>{{ target }} {{ screen }}</span>
        <v-spacer />
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-icon data-test="edit-screen-icon" @click="openEdit">
                mdi-pencil
              </v-icon>
            </div>
          </template>
          <span> Edit Screen </span>
        </v-tooltip>
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-icon
                data-test="minimize-screen-icon"
                @click="minMaxTransition"
                v-show="expand"
              >
                mdi-window-minimize
              </v-icon>
              <v-icon
                data-test="maximize-screen-icon"
                @click="minMaxTransition"
                v-show="!expand"
              >
                mdi-window-maximize
              </v-icon>
            </div>
          </template>
          <span v-show="expand"> Minimize Screen </span>
          <span v-show="!expand"> Maximize Screen </span>
        </v-tooltip>
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-icon
                data-test="close-screen-icon"
                @click="$emit('close-screen')"
              >
                mdi-close-box
              </v-icon>
            </div>
          </template>
          <span> Close Screen </span>
        </v-tooltip>
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

    <!-- Edit dialog -->
    <v-dialog v-model="editDialog" width="600">
      <v-card>
        <v-system-bar>
          <v-spacer />
          <span> Edit Screen: {{ target }} {{ screen }} </span>
          <v-spacer />
          <div class="mx-2">
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-icon
                    data-test="download-screen-icon"
                    @click="downloadScreen"
                  >
                    mdi-download
                  </v-icon>
                </div>
              </template>
              <span> Download Screen </span>
            </v-tooltip>
          </div>
        </v-system-bar>
        <v-card-text>
          <v-row class="mt-3"> Upload a screen file. </v-row>
          <v-row no-gutters align="center">
            <v-col cols="3">
              <v-btn
                block
                color="success"
                @click="loadFile"
                :disabled="!file || loadingFile"
                :loading="loadingFile"
                data-test="editScreenLoadBtn"
              >
                Load
                <template v-slot:loader>
                  <span>Loading...</span>
                </template>
              </v-btn>
            </v-col>
            <v-col cols="9">
              <v-file-input
                v-model="file"
                truncate-length="15"
                accept=".txt"
                label="Click to select .txt screen file."
              />
            </v-col>
          </v-row>
          <v-row> Edit the screen definition. </v-row>
          <v-row no-gutters>
            <v-textarea
              v-model="currentDefinition"
              rows="12"
              :rules="[rules.required]"
              data-test="screen-text-input"
            />
          </v-row>
          <v-row class="my-3">
            <span class="red--text" v-show="editErrors" v-text="editErrors" />
          </v-row>
          <v-row>
            <v-spacer />
            <v-btn
              @click="cancelEdit"
              class="mx-2"
              outlined
              data-test="editScreenCancelBtn"
            >
              Cancel
            </v-btn>
            <v-btn
              @click="saveEdit"
              class="mx-2"
              color="primary"
              data-test="editScreenSubmitBtn"
              :disabled="!!editErrors"
            >
              Save
            </v-btn>
          </v-row>
        </v-card-text>
      </v-card>
    </v-dialog>

    <!-- Error dialog -->
    <v-dialog v-model="errorDialog" max-width="600">
      <v-system-bar>
        <v-spacer />
        <span> Screen: {{ target }} {{ screen }} Errors </span>
        <v-spacer />
      </v-system-bar>
      <v-card class="pa-3">
        <v-row class="my-3">
          <v-textarea readonly rows="13" :value="error" />
        </v-row>
        <v-row>
          <v-btn block @click="clearErrors"> Clear </v-btn>
        </v-row>
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
      rules: {
        required: (value) => !!value || 'Required',
      },
      api: null,
      loadingFile: false,
      file: null,
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
      errors: [],
      errorDialog: false,
    }
  },
  computed: {
    editErrors: function () {
      if (this.currentDefinition === '' && !this.file) {
        return 'Input can not be blank.'
      }
      if (this.currentDefinition === this.backup) {
        return 'No changes have been made to save.'
      }
      return null
    },
    error: function () {
      if (this.errorDialog && this.errors.length > 0) {
        return JSON.stringify(this.errors, null, 4)
      }
      return null
    },
  },
  // Called when an error from any descendent component is captured
  // We need this because an error can occur from any of the children
  // in the widget stack and are typically thrown on create()
  errorCaptured(err, vm, info) {
    if (err.usage) {
      this.errors.push({
        type: 'usage',
        message: err.usage,
        time: new Date().getTime(),
      })
    } else {
      this.errors.push({
        type: 'error',
        message: `${err}`,
        time: new Date().getTime(),
      })
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
  destroyed() {
    if (this.updater != null) {
      clearInterval(this.updater)
      this.updater = null
    }
  },
  methods: {
    clearErrors: function () {
      this.errors = []
    },
    parseDefinition: function () {
      // Each time we start over and parse the screen definition
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
                this.currentLayout =
                  this.layoutStack[this.layoutStack.length - 1]
                break
              case 'SETTING':
              case 'SUBSETTING':
                const widget =
                  this.currentLayout.widgets[
                    this.currentLayout.widgets.length - 1
                  ] ?? this.currentLayout
                widget.settings.push(parameters)
                break
              case 'GLOBAL_SETTING':
                this.globalSettings.push(parameters)
                break
              case 'GLOBAL_SUBSETTING':
                this.globalSubsettings.push(parameters)
                break
              default:
                this.processWidget(keyword, parameters)
                break
            } // switch keyword
          } // if keyword
        }
      )
      this.applyGlobalSettings(this.layoutStack[0].widgets)
    },
    // Called by button scripts to get named widgets
    // Underscores used to match COSMOS API rather than Javascript convention
    get_named_widget: function (name) {
      return this.namedWidgets[name]
    },
    // Called by named widgets to register with the screen
    setNamedWidget: function (name, widget) {
      this.namedWidgets[name] = widget
    },
    update: function () {
      if (this.$store.state.tlmViewerItems.length !== 0) {
        this.api
          .get_tlm_values(this.$store.state.tlmViewerItems)
          .then((data) => {
            this.$store.commit('tlmViewerUpdateValues', data)
          })
      }
    },
    openEdit: function () {
      // Make a copy in case they edit and cancel
      this.backup = this.currentDefinition.repeat(1)
      this.editDialog = true
    },
    cancelEdit: function () {
      this.file = null
      this.editDialog = false
      // Restore the backup since we cancelled
      this.currentDefinition = this.backup
      this.parseDefinition()
    },
    loadFile: function () {
      const fileReader = new FileReader()
      fileReader.readAsText(this.file)
      this.loadingFile = true
      const that = this
      fileReader.onload = function () {
        that.loadingFile = false
        that.currentDefinition = fileReader.result
        that.inputType = 'txt'
        that.file = null
      }
    },
    saveEdit: function () {
      this.parseDefinition()
      // After parsing wait and see if there are errors before saving
      this.$nextTick(function () {
        Api.post('/cosmos-api/screen/', {
          data: {
            scope: localStorage.scope,
            target: this.target,
            screen: this.screen,
            text: this.currentDefinition,
          },
        })
        this.editDialog = false
      })
    },
    downloadScreen: function () {
      const blob = new Blob([this.currentDefinition], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute('download', `${this.target}_${this.screen}.txt`)
      link.click()
    },
    minMaxTransition: function () {
      this.expand = !this.expand
      this.$emit('min-max-screen')
    },
    processWidget: function (keyword, parameters) {
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
        if (Vue.options.components[componentName]) {
          this.currentLayout.widgets.push({
            type: componentName,
            target: this.target,
            parameters: parameters,
            settings: settings,
          })
        } else {
          this.currentLayout.widgets.push({
            type: 'DynamicWidget',
            target: this.target,
            parameters: parameters,
            settings: settings,
            name: componentName,
          })
        }
      }
    },
    applyGlobalSettings: function (widgets) {
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
