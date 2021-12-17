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
    <v-snackbar v-model="showAlert" top :color="alertType" :timeout="3000">
      <v-icon> mdi-{{ alertType }} </v-icon>
      {{ alertText }}
      <template v-slot:action="{ attrs }">
        <v-btn text v-bind="attrs" @click="showAlert = false"> Close </v-btn>
      </template>
    </v-snackbar>
    <v-snackbar v-model="showReadOnlyToast" top :timeout="-1" color="orange">
      <v-icon> mdi-pencil-off </v-icon>
      {{ lockedBy }} is editing this script. Editor is in read-only mode
      <template v-slot:action="{ attrs }">
        <v-btn
          text
          v-bind="attrs"
          color="danger"
          @click="confirmLocalUnlock"
          data-test="unlock-button"
        >
          Unlock
        </v-btn>
        <v-btn
          text
          v-bind="attrs"
          @click="
            () => {
              showReadOnlyToast = false
            }
          "
        >
          dismiss
        </v-btn>
      </template>
    </v-snackbar>

    <suite-runner
      v-if="suiteRunner"
      :suite-map="suiteMap"
      :disable-buttons="disableSuiteButtons"
      @button="suiteRunnerButton"
    />
    <v-container id="sc-controls">
      <v-row no-gutters justify="space-between">
        <v-col cols="8">
          <v-row no-gutters>
            <v-icon v-if="showDisconnect" class="mr-2" color="red">
              mdi-connection
            </v-icon>
            <v-text-field
              outlined
              dense
              readonly
              hide-details
              label="Filename"
              v-model="fullFilename"
              id="filename"
              data-test="filename"
            />
            <v-text-field
              v-model="scriptId"
              label="Script ID"
              data-test="id"
              class="shrink ml-2 script-state"
              style="width: 100px"
              dense
              outlined
              readonly
              hide-details
            />
            <v-text-field
              v-model="state"
              label="Script State"
              data-test="state"
              class="shrink ml-2 script-state"
              style="width: 120px"
              dense
              outlined
              readonly
              hide-details
            />
            <v-progress-circular
              v-if="state === 'Connecting...'"
              :size="40"
              class="ml-2 mr-2"
              indeterminate
              color="primary"
            />
            <div
              v-else
              style="width: 40px; height: 40px"
              class="ml-2 mr-2"
            ></div>
          </v-row>
        </v-col>

        <!-- Disable the Start button when Suite Runner controls are showing -->
        <v-col cols="4">
          <v-row no-gutters>
            <v-spacer />
            <div v-if="startOrGoButton === 'Start'">
              <v-btn
                @click="startHandeler"
                color="primary"
                class="mx-2"
                data-test="start-button"
                :disabled="startOrGoDisabled"
              >
                <span> Start </span>
              </v-btn>
              <v-btn
                @click="environmentHandeler"
                class="mx-1"
                data-test="env-button"
                :disabled="startOrGoDisabled"
              >
                <v-icon>
                  {{ environmentOn ? 'mdi-library' : 'mdi-run' }}
                </v-icon>
              </v-btn>
            </div>
            <div v-else>
              <v-btn
                @click="go"
                color="primary"
                class="mr-2"
                :disabled="startOrGoDisabled"
                data-test="go-button"
              >
                Go
              </v-btn>
              <v-btn
                color="primary"
                @click="pauseOrRetry"
                class="mr-2"
                :disabled="pauseOrRetryDisabled"
                data-test="pause-retry-button"
              >
                {{ pauseOrRetryButton }}
              </v-btn>

              <v-btn
                color="primary"
                @click="stop"
                data-test="stop-button"
                :disabled="stopDisabled"
              >
                Stop
              </v-btn>
            </div>
          </v-row>
        </v-col>
      </v-row>
    </v-container>
    <!-- Create Multipane container to support resizing.
         NOTE: We listen to paneResize event and call editor.resize() to prevent weird sizing issues -->
    <multipane
      class="horizontal-panes"
      layout="horizontal"
      @paneResize="editor.resize()"
    >
      <div id="editorbox" class="pane">
        <v-snackbar
          v-model="showSave"
          absolute
          top
          right
          :timeout="-1"
          class="saving"
        >
          Saving...
        </v-snackbar>
        <pre id="editor" @contextmenu.prevent="showExecuteSelectionMenu"></pre>
        <v-menu
          v-model="executeSelectionMenu"
          :position-x="menuX"
          :position-y="menuY"
          absolute
          offset-y
        >
          <v-list>
            <v-list-item
              v-for="item in executeSelectionMenuItems"
              :key="item.label"
            >
              <v-list-item-title @click="item.command">
                {{ item.label }}
              </v-list-item-title>
            </v-list-item>
          </v-list>
        </v-menu>
      </div>
      <multipane-resizer><hr /></multipane-resizer>
      <div id="messages" class="mt-2 pane" ref="messagesDiv">
        <v-container id="debug" class="pa-0" v-if="showDebug">
          <v-row no-gutters>
            <v-btn
              color="primary"
              @click="step"
              style="width: 100px"
              class="mr-4"
              data-test="step-button"
            >
              Step
              <v-icon right> mdi-step-forward </v-icon>
            </v-btn>
            <v-text-field
              class="mb-2"
              outlined
              dense
              hide-details
              label="Debug"
              v-model="debug"
              @keydown="debugKeydown"
              data-test="debug-text"
            />
          </v-row>
        </v-container>
        <v-card>
          <v-card-title>
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-btn
                    icon
                    class="mx-2"
                    data-test="download-log"
                    @click="downloadLog"
                  >
                    <v-icon> mdi-download </v-icon>
                  </v-btn>
                </div>
              </template>
              <span> Download Log </span>
            </v-tooltip>
            Log Messages
            <v-menu :close-on-content-click="false" offset-y>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-tooltip top>
                    <template v-slot:activator="{ on, attrs }">
                      <v-btn
                        icon
                        data-test="searchClearLogs"
                        class="mx-2"
                        v-on="on"
                        v-bind="attrs"
                      >
                        <v-icon v-if="search === ''"> mdi-magnify </v-icon>
                        <v-icon v-else @click="search = ''">
                          mdi-cancel
                        </v-icon>
                      </v-btn>
                    </template>
                    <span>
                      {{ search === '' ? 'Search Log' : 'Clear Search' }}
                    </span>
                  </v-tooltip>
                </div>
              </template>
              <v-card outlined width="500px">
                <div class="pa-3">
                  <v-text-field
                    v-model="search"
                    single-line
                    hide-details
                    autofocus
                    label="Search"
                    data-test="search-output-messages"
                  />
                </div>
              </v-card>
            </v-menu>
            <div v-show="search" class="mx-2">
              <span> Search: {{ search }} </span>
            </div>
            <v-spacer />
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-btn
                    icon
                    class="mx-2"
                    data-test="clear-log"
                    @click="clearLog"
                  >
                    <v-icon> mdi-delete </v-icon>
                  </v-btn>
                </div>
              </template>
              <span> Clear Log </span>
            </v-tooltip>
          </v-card-title>
          <v-data-table
            :headers="headers"
            :items="messages"
            :search="search"
            calculate-widths
            disable-pagination
            hide-default-footer
            multi-sort
            dense
            height="45vh"
            data-test="output-messages"
          />
        </v-card>
      </div>
    </multipane>
    <ask-dialog
      v-if="ask.show"
      v-model="ask.show"
      :question="ask.question"
      :default="ask.default"
      :password="ask.password"
      :answer-required="ask.answerRequired"
      @response="ask.callback"
    />
    <prompt-dialog
      v-if="prompt.show"
      v-model="prompt.show"
      :title="prompt.title"
      :subtitle="prompt.subtitle"
      :message="prompt.message"
      :details="prompt.details"
      :buttons="prompt.buttons"
      :layout="prompt.layout"
      @response="prompt.callback"
    />
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <environment-dialog v-if="environmentOpen" v-model="environmentOpen" />
    <file-open-save-dialog
      v-if="fileOpen"
      v-model="fileOpen"
      type="open"
      @file="setFile($event)"
      @error="setError($event)"
    />
    <file-open-save-dialog
      v-if="showSaveAs"
      v-model="showSaveAs"
      type="save"
      require-target-parent-dir
      :input-filename="filename"
      @filename="saveAsFilename($event)"
      @error="setError($event)"
    />
    <!-- START -->
    <v-dialog v-model="startDialog" width="600">
      <v-card>
        <v-system-bar>
          <v-spacer />
          <span> Start with Environment Options </span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <div class="pa-3">
            <environment-chooser @selected="selectedHandeler" />
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn
            @click="cancelCallback"
            class="mx-2"
            outlined
            data-test="environment-dialog-cancel"
          >
            Cancel
          </v-btn>
          <v-btn
            @click="optionCallback"
            class="mx-2"
            color="primary"
            data-test="environment-dialog-start"
          >
            Start
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <!-- INFO -->
    <v-dialog v-model="infoDialog" width="600">
      <v-card>
        <v-system-bar>
          <v-spacer />
          <span> {{ infoTitle }} </span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <div class="pa-3">
            <v-row no-gutters v-for="(line, index) in infoText" :key="index">
              <span v-text="line" />
            </v-row>
            <v-row>
              <v-btn block color="primary" @click="infoDialog = false">
                Ok
              </v-btn>
            </v-row>
          </div>
        </v-card-text>
      </v-card>
    </v-dialog>
    <!-- RESULTS -->
    <v-dialog v-model="resultsDialog" width="600">
      <v-card>
        <v-system-bar>
          <v-spacer />
          <span> Script Results </span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <div class="pa-3">
            <v-textarea
              readonly
              hide-details
              dense
              auto-grow
              :value="scriptResults"
            />
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn class="mx-2" outlined @click="downloadResults">
            Download
          </v-btn>
          <v-btn class="mx-2" color="primary" @click="resultsDialog = false">
            Ok
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import * as ace from 'ace-builds'
import 'ace-builds/src-min-noconflict/mode-ruby'
import 'ace-builds/src-min-noconflict/theme-twilight'
import 'ace-builds/src-min-noconflict/ext-language_tools'
import 'ace-builds/src-min-noconflict/ext-searchbox'
import { toDate, format } from 'date-fns'
import { Multipane, MultipaneResizer } from 'vue-multipane'
import FileOpenSaveDialog from '@cosmosc2/tool-common/src/components/FileOpenSaveDialog'
import EnvironmentChooser from '@cosmosc2/tool-common/src/components/EnvironmentChooser'
import EnvironmentDialog from '@cosmosc2/tool-common/src/components/EnvironmentDialog'
import ActionCable from 'actioncable'
import AskDialog from './AskDialog.vue'
import PromptDialog from './PromptDialog.vue'
import SuiteRunner from './SuiteRunner.vue'
import { CmdCompleter, TlmCompleter } from './autocomplete'
import { SleepAnnotator } from './annotations'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'

const NEW_FILENAME = '<Untitled>'
const START = 'Start'
const GO = 'Go'
const PAUSE = 'Pause'
const RETRY = 'Retry'

export default {
  components: {
    FileOpenSaveDialog,
    EnvironmentChooser,
    EnvironmentDialog,
    AskDialog,
    PromptDialog,
    SuiteRunner,
    Multipane,
    MultipaneResizer,
    TopBar,
  },
  data() {
    return {
      title: 'Script Runner',
      suiteRunner: false, // Whether to display the SuiteRunner GUI
      disableSuiteButtons: false,
      suiteMap: {
        // Useful for testing the various options in the SuiteRunner GUI
        // Suite: {
        //   teardown: true,
        //   groups: {
        //     Group: {
        //       setup: true,
        //       cases: ['case1', 'case2', 'really_long_test_case_name3'],
        //     },
        //     ReallyLongGroupName: {
        //       cases: ['case1', 'case2', 'case3'],
        //     },
        //   },
        // },
      },
      current_filename: null,
      environmentOn: false,
      environmentOpen: false,
      environmentOptions: [],
      showSave: false,
      showAlert: false,
      alertType: null,
      alertText: '',
      state: ' ',
      scriptId: ' ',
      startDialog: false,
      startOrGoButton: START,
      startOrGoDisabled: false,
      pauseOrRetryButton: PAUSE,
      pauseOrRetryDisabled: false,
      stopDisabled: false,
      showDebug: false,
      debug: '',
      debugHistory: [],
      debugHistoryIndex: 0,
      showDisconnect: false,
      files: {},
      filename: NEW_FILENAME,
      tempFilename: null,
      fileModified: '',
      fileOpen: false,
      lockedBy: null,
      showReadOnlyToast: false,
      showSaveAs: false,
      areYouSure: false,
      subscription: null,
      cable: null,
      fatal: false,
      search: '',
      messages: [],
      headers: [{ text: 'Message', value: 'message' }],
      maxArrayLength: 30,
      Range: ace.require('ace/range').Range,
      ask: {
        show: false,
        question: '',
        default: null,
        password: false,
        answerRequired: true,
        callback: () => {},
      },
      prompt: {
        show: false,
        title: '',
        subtitle: '',
        message: '',
        details: '',
        buttons: null,
        layout: 'horizontal',
        callback: () => {},
      },
      infoDialog: false,
      infoTitle: '',
      infoText: [],
      resultsDialog: false,
      scriptResults: '',
      executeSelectionMenu: false,
      menuX: 0,
      menuY: 0,
    }
  },
  computed: {
    readOnly: function () {
      return !!this.lockedBy
    },
    fullFilename() {
      return `${this.filename} ${this.fileModified}`.trim()
    },
    menus: function () {
      return [
        {
          label: 'File',
          items: [
            {
              label: 'New File',
              icon: 'mdi-file-plus',
              command: () => {
                this.newFile()
              },
            },
            {
              label: 'Open File',
              icon: 'mdi-folder-open',
              command: () => {
                this.openFile()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Save File',
              icon: 'mdi-content-save',
              command: () => {
                this.saveFile()
              },
            },
            {
              label: 'Save As...',
              icon: 'mdi-content-save',
              command: () => {
                this.saveAs()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Download',
              icon: 'mdi-cloud-download',
              command: () => {
                this.download()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Delete File',
              icon: 'mdi-delete',
              command: () => {
                this.delete()
              },
            },
          ],
        },
        {
          label: 'Script',
          items: [
            {
              label: 'Open Running Scripts',
              icon: 'mdi-run',
              command: () => {
                let routeData = this.$router.resolve({ name: 'RunningScripts' })
                window.open(routeData.href, '_blank')
              },
            },
            {
              divider: true,
            },
            {
              label: 'Show Environment',
              icon: 'mdi-eye',
              command: () => {
                this.environmentOpen = !this.environmentOpen
              },
            },
            {
              divider: true,
            },
            {
              label: 'Ruby Syntax Check',
              icon: 'mdi-language-ruby',
              command: () => {
                this.rubySyntaxCheck()
              },
            },
            {
              label: 'Show Call Stack',
              icon: 'mdi-format-list-numbered',
              disabled: !this.scriptId || this.scriptId === ' ',
              command: () => {
                this.showCallStack()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Toggle Debug',
              icon: 'mdi-bug',
              command: () => {
                this.toggleDebug()
              },
            },
            {
              label: 'Toggle Disconnect',
              icon: 'mdi-connection',
              command: () => {
                this.toggleDisconnect()
              },
            },
          ],
        },
      ]
    },
    executeSelectionMenuItems: function () {
      return [
        {
          label: 'Execute selection',
          command: this.executeSelection,
        },
      ]
    },
  },
  watch: {
    readOnly: function (val) {
      this.showReadOnlyToast = val
      this.startOrGoDisabled = val
      this.editor.setReadOnly(val)
    },
  },
  created: function () {
    window.onbeforeunload = this.unlockFile
  },
  mounted() {
    this.editor = ace.edit('editor')
    this.editor.setTheme('ace/theme/twilight')
    this.editor.session.setMode('ace/mode/ruby')
    this.editor.session.setTabSize(2)
    this.editor.session.setUseWrapMode(true)
    this.editor.$blockScrolling = Infinity
    this.editor.setOption('enableBasicAutocompletion', true)
    this.editor.setOption('enableLiveAutocompletion', true)
    this.editor.completers = [new CmdCompleter(), new TlmCompleter()]
    this.editor.setHighlightActiveLine(false)
    this.editor.focus()
    // We listen to tokenizerUpdate rather than change because this
    // is the background process that updates as changes are processed
    // while change fires immediately before the UndoManager is updated.
    this.editor.session.on('tokenizerUpdate', this.onChange)

    const sleepAnnotator = new SleepAnnotator(this.editor)
    this.editor.session.on('change', sleepAnnotator.annotate)

    window.addEventListener('keydown', this.keydown)
    this.cable = ActionCable.createConsumer('/script-api/cable')
    Api.get('/script-api/running-script').then((response) => {
      const loadRunningScript = response.data.find(
        (s) => `${s.id}` === `${this.$route.params.id}`
      )
      if (loadRunningScript) {
        this.filename = loadRunningScript.name
        this.scriptStart(loadRunningScript.id)
      } else if (this.$route.params.id) {
        this.$notify.caution({
          title: '404 Not Found',
          body: `Failed to load running script id: ${this.$route.params.id}`,
        })
      } else {
        this.alertType = 'success'
        this.alertText = `Currently ${response.data.length} running scripts.`
        this.showAlert = true
      }
    })
    this.autoSaveInterval = setInterval(() => {
      // Only save if modified and visible (e.g. not open in another tab)
      if (
        this.fileModified.length > 0 &&
        document.visibilityState === 'visible'
      ) {
        this.saveFile('auto')
      }
    }, 60000) // Save every minute
  },
  beforeDestroy() {
    this.editor.destroy()
    this.editor.container.remove()
  },
  destroyed() {
    this.unlockFile()
    if (this.autoSaveInterval != null) {
      clearInterval(this.autoSaveInterval)
    }
    if (this.tempFilename) {
      Api.post(`/script-api/scripts/${this.tempFilename}/delete`)
    }
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    showExecuteSelectionMenu: function ($event) {
      this.menuX = $event.pageX
      this.menuY = $event.pageY
      this.executeSelectionMenu = true
    },
    executeSelection: function () {
      const text = this.editor.getSelectedText()
      if (this.state === 'error') {
        // Execute via debugger
        const lines = text.split('\n')
        for (const line of lines) {
          this.debug = line.trim()
          this.debugKeydown({ key: 'Enter' })
        }
      } else {
        // Create a new temp script and open in new tab
        const selectionTempFilename =
          format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_temp.rb'
        Api.post(`/script-api/scripts/${selectionTempFilename}`, {
          data: {
            text,
          },
        })
          .then((response) => {
            return Api.post(
              `/script-api/scripts/${selectionTempFilename}/run`,
              {
                data: {
                  scope: localStorage.scope,
                  environment: this.environmentOptions,
                },
              }
            )
          })
          .then((response) => {
            window.open(`/tools/scriptrunner/${response.data}`)
          })
      }
    },
    suiteRunnerButton(event) {
      if (this.startOrGoButton === START) {
        this.start(event, 'suiteRunner')
      } else {
        this.go(event, 'suiteRunner')
      }
    },
    keydown(event) {
      // NOTE: Chrome does not allow overriding Ctrl-N, Ctrl-Shift-N, Ctrl-T, Ctrl-Shift-T, Ctrl-W
      // NOTE: metaKey == Command on Mac
      if (
        (event.metaKey || event.ctrlKey) &&
        event.keyCode === 'S'.charCodeAt(0)
      ) {
        event.preventDefault()
        this.saveFile()
      } else if (
        (event.metaKey || event.ctrlKey) &&
        event.shiftKey &&
        event.keyCode === 'S'.charCodeAt(0)
      ) {
        event.preventDefault()
        this.saveAs()
      }
    },
    onChange(event) {
      // Don't track changes when we're read-only (we're running)
      if (this.editor.getReadOnly() === true) {
        return
      }
      if (this.editor.session.getUndoManager().canUndo()) {
        this.fileModified = '*'
      } else {
        this.fileModified = ''
      }
    },
    scriptStart(id) {
      this.disableSuiteButtons = true
      this.startOrGoDisabled = true
      this.pauseOrRetryDisabled = true
      this.stopDisabled = true
      this.state = 'Connecting...'
      this.startOrGoButton = GO
      this.scriptId = id
      this.editor.setReadOnly(true)
      this.subscription = this.cable.subscriptions.create(
        { channel: 'RunningScriptChannel', id: this.scriptId },
        {
          received: (data) => this.received(data),
        }
      )
    },
    scriptComplete() {
      this.disableSuiteButtons = false
      this.startOrGoButton = START
      this.pauseOrRetryButton = PAUSE
      // Disable start if suiteRunner
      this.startOrGoDisabled = this.suiteRunner
      this.pauseOrRetryDisabled = true
      this.stopDisabled = true
      this.fatal = false
      this.editor.setReadOnly(false)
    },
    selectedHandeler: function (event) {
      this.environmentOptions = event ? event : null
    },
    environmentHandeler: function (event) {
      this.environmentOn = !this.environmentOn
      const environmentValue = this.environmentOn ? 'ON' : 'OFF'
      this.alertType = 'success'
      this.alertText = `Environment dialog toggled: ${environmentValue}`
      this.showAlert = true
    },
    startHandeler: function () {
      if (this.environmentOn) {
        this.startDialog = true
      } else {
        this.start()
      }
    },
    optionCallback: function () {
      this.startDialog = false
      this.start()
    },
    cancelCallback: function () {
      this.startDialog = false
    },
    start(event, suiteRunner = null) {
      this.saveFile('start')
      let filename = this.filename
      if (this.filename === NEW_FILENAME) {
        // NEW_FILENAME so use tempFilename created by saveFile()
        filename = this.tempFilename
      }
      let url = `/script-api/scripts/${filename}/run`
      if (this.showDisconnect) {
        url += '/disconnect'
      }
      let data = {
        scope: localStorage.scope,
        environment: this.environmentOptions,
      }
      if (suiteRunner) {
        data['suiteRunner'] = event
      }
      Api.post(url, { data }).then((response) => {
        this.scriptStart(response.data)
      })
      this.environmentOptions = []
    },
    go(event, suiteRunner = null) {
      Api.post(`/script-api/running-script/${this.scriptId}/go`)
    },
    pauseOrRetry() {
      if (this.pauseOrRetryButton === PAUSE) {
        Api.post(`/script-api/running-script/${this.scriptId}/pause`)
      } else {
        this.pauseOrRetryButton = PAUSE
        Api.post(`/script-api/running-script/${this.scriptId}/retry`)
      }
    },
    stop() {
      // We previously encountered a fatal error so remove the marker
      // and cleanup by calling scriptComplete()
      if (this.fatal) {
        this.removeAllRunningMarkers()
        this.scriptComplete()
      } else {
        Api.post(`/script-api/running-script/${this.scriptId}/stop`)
      }
    },
    step() {
      Api.post(`/script-api/running-script/${this.scriptId}/step`)
    },
    received(data) {
      switch (data.type) {
        case 'file':
          this.files[data.filename] = data.text
          this.filename = data.filename
          break
        case 'line':
          if (data.filename && data.filename !== this.current_filename) {
            if (!this.files[data.filename]) {
              // We don't have the contents of the running file (probably because connected to running script)
              // Set the contents initially to an empty string so we don't start slamming the API
              this.files[data.filename] = ''

              // Request the script we need
              Api.get(`/script-api/scripts/${data.filename}`)
                .then((response) => {
                  // Success - Save thes script text and mark the current_filename as null
                  // so it will get loaded in on the next line executed
                  this.files[data.filename] = response.data.contents
                  this.current_filename = null
                })
                .catch((err) => {
                  // Error - Restore the file contents to null so we'll try the API again on the next line
                  this.files[data.filename] = null
                })
            } else {
              this.editor.setValue(this.files[data.filename])
              this.editor.clearSelection()
              this.current_filename = data.filename
            }
          }
          if (!this.fatal) {
            this.removeAllRunningMarkers()
          }
          let marker = null
          switch (data.state) {
            case 'running':
              marker = 'runningMarker'
              this.startOrGoDisabled = false
              this.pauseOrRetryDisabled = false
              this.stopDisabled = false
              this.pauseOrRetryButton = PAUSE
              break
            case 'waiting':
              marker = 'waitingMarker'
              break
            case 'paused':
              marker = 'pausedMarker'
              break
            case 'error':
              marker = 'errorMarker'
              this.pauseOrRetryButton = RETRY
              this.startOrGoDisabled = false
              this.pauseOrRetryDisabled = false
              this.stopDisabled = false
              break
            case 'fatal':
              marker = 'fatalMarker'
              this.fatal = true
              this.startOrGoDisabled = true
              this.pauseOrRetryDisabled = true
              break
            default:
              marker = null
              break
          }
          this.state = data.state
          if (marker) {
            this.editor.session.addMarker(
              new this.Range(data.line_no - 1, 0, data.line_no - 1, 1),
              marker,
              'fullLine'
            )
            if (this.editor.getSelectedText() === '') {
              this.editor.gotoLine(data.line_no)
            }
          }
          break
        case 'output':
          this.messages.push({ message: data.line })
          while (this.messages.length > this.maxArrayLength) {
            this.messages.shift()
          }
          break
        case 'script':
          this.handleScript(data)
          break
        case 'report':
          this.resultsDialog = true
          this.scriptResults = data.report
          break
        case 'complete':
          // Don't complete on fatal because we just sit there on the fatal line
          if (!this.fatal) {
            this.removeAllRunningMarkers()
            this.scriptComplete()
          }
        default:
          // console.log('Unexpected ActionCable message')
          // console.log(data)
          break
      }
    },
    promptDialogCallback(value) {
      this.prompt.show = false
      Api.post(`/script-api/running-script/${this.scriptId}/prompt`, {
        data: {
          method: this.prompt.method,
          answer: value,
        },
      })
    },
    handleScript(data) {
      this.prompt.method = data.method // Set it here since all prompts use this
      this.prompt.layout = 'horizontal' // Reset the layout since most are horizontal
      this.prompt.title = 'Prompt'
      this.prompt.subtitle = ''
      this.prompt.details = ''
      this.prompt.buttons = [] // Reset buttons so 'Yes', 'No' are used by default
      switch (data.method) {
        case 'ask':
        case 'ask_string':
          // Reset values since this dialog can be re-used
          this.ask.default = null
          this.ask.answerRequired = true
          this.ask.password = false
          this.ask.question = data.args[0]
          // If the second parameter is not true or false it indicates a default value
          if (data.args[1] && data.args[1] !== true && data.args[1] !== false) {
            this.ask.default = data.args[1].toString()
          } else if (data.args[1] === true) {
            // If the second parameter is true it means no value is required to be entered
            this.ask.answerRequired = false
          }
          // The third parameter indicates a password textfield
          if (data.args[2] === true) {
            this.ask.password = true
          }
          this.ask.callback = (value) => {
            this.ask.show = false // Close the dialog
            if (this.ask.password) {
              Api.post(`/script-api/running-script/${this.scriptId}/prompt`, {
                data: {
                  method: data.method,
                  password: value, // Using password as a key automatically filters it from rails logs
                },
              })
            } else {
              Api.post(`/script-api/running-script/${this.scriptId}/prompt`, {
                data: {
                  method: data.method,
                  answer: value,
                },
              })
            }
          }
          this.ask.show = true // Display the dialog
          break
        case 'prompt_for_hazardous':
          this.prompt.title = 'Hazardous Command'
          this.prompt.message = `Warning: Command ${data.args[0]} ${data.args[1]} is Hazardous. `
          if (data.args[2]) {
            this.prompt.message += data.args[2] + ' '
          }
          this.prompt.message += 'Send?'
          this.prompt.callback = this.promptDialogCallback
          this.prompt.show = true
          break
        case 'prompt':
          if (data.kwargs && data.kwargs.informative) {
            this.prompt.subtitle = data.kwargs.informative
          }
          if (data.kwargs && data.kwargs.details) {
            this.prompt.details = data.kwargs.details
          }
          this.prompt.message = data.args[0]
          this.prompt.buttons = [{ text: 'Ok', value: 'Ok' }]
          this.prompt.callback = this.promptDialogCallback
          this.prompt.show = true
          break
        case 'combo_box':
          if (data.kwargs && data.kwargs.informative) {
            this.prompt.subtitle = data.kwargs.informative
          }
          if (data.kwargs && data.kwargs.details) {
            this.prompt.details = data.kwargs.details
          }
          this.prompt.message = data.args[0]
          data.args.slice(1).forEach((v) => {
            this.prompt.buttons.push({ text: v, value: v })
          })
          this.prompt.combo = true
          this.prompt.layout = 'combo'
          this.prompt.callback = this.promptDialogCallback
          this.prompt.show = true
          break
        case 'message_box':
        case 'vertical_message_box':
          if (data.kwargs && data.kwargs.informative) {
            this.prompt.subtitle = data.kwargs.informative
          }
          if (data.kwargs && data.kwargs.details) {
            this.prompt.details = data.kwargs.details
          }
          this.prompt.message = data.args[0]
          data.args.slice(1).forEach((v) => {
            this.prompt.buttons.push({ text: v, value: v })
          })
          if (data.method.includes('vertical')) {
            this.prompt.layout = 'vertical'
          }
          this.prompt.callback = this.promptDialogCallback
          this.prompt.show = true
          break
        case 'backtrace':
          this.infoTitle = 'Call Stack'
          this.infoText = data.args
          this.infoDialog = true
          break
        default:
          /* console.log(
            'Unknown script method:' + data.method + ' with args:' + data.args
          ) */
          break
      }
    },
    setError(event) {
      this.alertType = 'error'
      this.alertText = `Error: ${event}`
      this.showAlert = true
    },
    // ScriptRunner File menu actions
    newFile() {
      this.filename = NEW_FILENAME
      this.editor.session.setValue('')
      this.fileModified = ''
      this.suiteRunner = false
      this.startOrGoDisabled = false
    },
    openFile() {
      this.fileOpen = true
    },
    // Called by the FileOpenDialog to set the file contents
    setFile({ file, locked }) {
      this.suiteRunner = false
      // Split off the ' *' which indicates a file is modified on the server
      this.filename = file.name.split('*')[0]
      this.editor.session.setValue(file.contents)
      this.fileModified = ''
      this.lockedBy = locked
      if (file.suites) {
        if (typeof file.suites === 'string') {
          this.alertType = 'warning'
          this.alertText = `Processing ${this.filename} resulted in: ${file.suites}`
          this.showAlert = true
        } else {
          this.suiteRunner = true
          this.suiteMap = file.suites
          this.startOrGoDisabled = true
        }
      }
    },
    // saveFile takes a type to indicate if it was called by the Menu
    // or automatically by 'Start' (to ensure a consistent backend file) or autoSave
    saveFile(type = 'menu') {
      if (this.filename === NEW_FILENAME) {
        if (type === 'menu') {
          // Menu driven saves on a new file should prompt SaveAs
          this.saveAs()
        } else {
          if (this.tempFilename === null) {
            this.tempFilename =
              format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_temp.rb'
          }
          this.showSave = true
          Api.post(`/script-api/scripts/${this.tempFilename}`, {
            data: {
              text: this.editor.getValue(), // Pass in the raw file text
            },
          })
            .then((response) => {
              this.fileModified = ''
              setTimeout(() => {
                this.showSave = false
              }, 2000)
            })
            .catch((error) => {
              this.showSave = false
            })
        }
      } else {
        // Save a file by posting the new contents
        this.showSave = true
        Api.post(`/script-api/scripts/${this.filename}`, {
          data: {
            text: this.editor.getValue(), // Pass in the raw file text
          },
        })
          .then((response) => {
            if (response.status == 200) {
              if (response.data.suites) {
                this.suiteRunner = true
                this.suiteMap = JSON.parse(response.data.suites)
              }
              this.fileModified = ''
              setTimeout(() => {
                this.showSave = false
              }, 2000)
            } else {
              this.showSave = false
              this.alertType = 'error'
              this.alertText = `Error saving file. Code: ${response.status} Text: ${response.statusText}`
              this.showAlert = true
            }
          })
          .catch(({ response }) => {
            this.showSave = false
            // 422 error means we couldn't parse the script file into Suites
            // response.data.suites holds the parse result
            if (response.status == 422) {
              this.alertType = 'error'
              this.alertText = response.data.suites
            } else {
              this.alertType = 'error'
              this.alertText = `Error saving file. Code: ${response.status} Text: ${response.statusText}`
            }
            this.showAlert = true
          })
      }
      this.lockFile() // Ensure this file is locked for editing
    },
    saveAs() {
      this.showSaveAs = true
    },
    saveAsFilename(filename) {
      this.filename = filename
      if (this.tempFilename) {
        Api.post(`/script-api/scripts/${this.tempFilename}/delete`)
        this.tempFilename = null
      }
      this.saveFile()
    },
    delete() {
      // TODO: Delete instead of post
      this.$dialog
        .confirm(`Permanently delete file: ${this.filename}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          return Api.post(`/script-api/scripts/${this.filename}/delete`, {
            data: {},
          })
        })
        .then((response) => {
          this.newFile()
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed Multi-Delete. ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
    },
    download() {
      const blob = new Blob([this.editor.getValue()], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute('download', this.filename)
      link.click()
    },

    // ScriptRunner Script menu actions
    rubySyntaxCheck() {
      Api.post('/script-api/scripts/syntax', {
        data: this.editor.getValue(),
        headers: {
          Accept: 'application/json',
          'Content-Type': 'plain/text',
        },
      }).then((response) => {
        this.infoTitle = response.data.title
        this.infoText = JSON.parse(response.data.description)
        this.infoDialog = true
      })
    },
    showCallStack() {
      Api.post(`/script-api/running-script/${this.scriptId}/backtrace`)
    },
    toggleDebug() {
      this.showDebug = !this.showDebug
    },
    toggleDisconnect() {
      this.showDisconnect = !this.showDisconnect
    },

    debugKeydown(event) {
      if (event.key === 'Escape') {
        this.debug = ''
        this.debugHistoryIndex = this.debugHistory.length
      } else if (event.key === 'Enter') {
        this.debugHistory.push(this.debug)
        this.debugHistoryIndex = this.debugHistory.length
        // Post the code to /debug, output is processed by receive()
        Api.post(`/script-api/running-script/${this.scriptId}/debug`, {
          data: {
            args: this.debug,
          },
        })
        this.debug = ''
      } else if (event.key === 'ArrowUp') {
        this.debugHistoryIndex -= 1
        if (this.debugHistoryIndex < 0) {
          this.debugHistoryIndex = this.debugHistory.length - 1
        }
        this.debug = this.debugHistory[this.debugHistoryIndex]
      } else if (event.key === 'ArrowDown') {
        this.debugHistoryIndex += 1
        if (this.debugHistoryIndex >= this.debugHistory.length) {
          this.debugHistoryIndex = 0
        }
        this.debug = this.debugHistory[this.debugHistoryIndex]
      }
    },
    downloadResults() {
      const blob = new Blob([this.scriptResults], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_suite_results.txt'
      )
      link.click()
    },
    downloadLog() {
      const output = this.messages.join('\n')
      const blob = new Blob([output], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_sr_message_log.txt'
      )
      link.click()
    },
    clearLog: function () {
      this.$dialog
        .confirm('Are you sure you want to clear the logs?', {
          okText: 'Clear',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          this.messages = []
        })
    },
    removeAllRunningMarkers: function () {
      const allMarkers = this.editor.session.getMarkers()
      Object.keys(allMarkers)
        .filter((key) => allMarkers[key].type === 'fullLine')
        .forEach((marker) => this.editor.session.removeMarker(marker))
    },
    confirmLocalUnlock: function () {
      this.$dialog
        .confirm(
          'Are you sure you want to unlock this script for editing? If another user is editing this script, your changes might conflict with each other.',
          {
            okText: 'Force Unlock',
            cancelText: 'Cancel',
          }
        )
        .then(() => {
          this.lockedBy = null
          return this.lockFile() // Re-lock it as this user so it's locked for anyone else who opens it
        })
    },
    lockFile: function () {
      return Api.post(`/script-api/scripts/${this.filename}/lock`)
    },
    unlockFile: function () {
      if (this.filename !== NEW_FILENAME && !this.readOnly) {
        Api.post(`/script-api/scripts/${this.filename}/unlock`)
      }
    },
  },
}
</script>

<style scoped>
#sc-controls {
  padding-top: 0px;
  padding-bottom: 5px;
  padding-left: 0px;
  padding-right: 0px;
}
#editorbox {
  height: 50vh;
}
#editor {
  height: 100%;
  width: 100%;
  position: relative;
  font-size: 16px;
}
hr {
  pointer-events: none;
  position: relative;
  top: 7px;
  background-color: grey;
  height: 3px;
  width: 5%;
  margin: auto;
}
.script-state >>> input {
  text-transform: capitalize;
}
</style>
<style>
.runningMarker {
  position: absolute;
  background: rgba(100, 255, 100, 0.5);
  z-index: 20;
}
.waitingMarker {
  position: absolute;
  background: rgba(0, 255, 0, 0.5);
  z-index: 20;
}
.pausedMarker {
  position: absolute;
  background: rgba(0, 140, 255, 0.5);
  z-index: 20;
}
.errorMarker {
  position: absolute;
  background: rgba(255, 0, 119, 0.5);
  z-index: 20;
}
.fatalMarker {
  position: absolute;
  background: rgba(255, 0, 0, 0.5);
  z-index: 20;
}
.saving {
  z-index: 20;
  opacity: 0.35;
}
</style>
