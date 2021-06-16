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
    <v-alert dense dismissible :type="alertType" v-if="alertType">
      {{ alertText }}
    </v-alert>
    <suite-runner
      v-if="suiteRunner"
      :suiteMap="suiteMap"
      :disableButtons="disableSuiteButtons"
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
            >
            </v-text-field>
            <v-text-field
              class="shrink ml-2 script-state"
              style="width: 120px"
              outlined
              dense
              readonly
              hide-details
              label="Script State"
              v-model="state"
              data-test="state"
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
            <v-btn
              color="primary"
              @click="startOrGo"
              class="mr-2"
              :disabled="startOrGoDisabled"
              data-test="start-go-button"
            >
              {{ startOrGoButton }}
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
        <pre id="editor"></pre>
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
            Log Messages
            <v-spacer />
            <v-text-field
              v-model="search"
              append-icon="$astro-search"
              label="Search"
              single-line
              hide-details
              data-test="search-output-messages"
            />
            <v-icon
              @click="downloadLog"
              class="pa-2 mt-3"
              data-test="download-log"
            >
              mdi-download
            </v-icon>
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
      :question="ask.question"
      :default="ask.default"
      :password="ask.password"
      :answerRequired="ask.answerRequired"
      @submit="ask.callback"
    />
    <prompt-dialog
      v-if="prompt.show"
      :title="prompt.title"
      :subtitle="prompt.subtitle"
      :message="prompt.message"
      :details="prompt.details"
      :buttons="prompt.buttons"
      :layout="prompt.layout"
      @submit="prompt.callback"
    />
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <file-open-save-dialog
      v-if="fileOpen"
      v-model="fileOpen"
      type="open"
      @file="setFile($event)"
    />
    <file-open-save-dialog
      v-if="showSaveAs"
      v-model="showSaveAs"
      type="save"
      :inputFilename="filename"
      @filename="saveAsFilename($event)"
    />
    <v-dialog v-model="areYouSure" max-width="350">
      <v-card>
        <v-card-title class="headline"> Are you sure? </v-card-title>
        <v-card-text>Permanently delete file {{ filename }}! </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn color="primary" text @click="confirmDelete(true)"> Ok </v-btn>
          <v-btn color="primary" text @click="confirmDelete(false)">
            Cancel
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <v-dialog v-model="infoDialog" max-width="750">
      <v-card>
        <v-card-title class="headline">{{ infoTitle }}</v-card-title>
        <v-card-text class="mb-0">
          <v-container>
            <v-row no-gutters v-for="(line, index) in infoText" :key="index">
              {{ line }}
            </v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-btn color="primary" text @click="infoDialog = false">Ok</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <v-dialog v-model="resultsDialog" max-width="750">
      <v-card>
        <v-card-title class="headline">Script Results</v-card-title>
        <v-card-text class="mb-0 pb-0">
          <v-textarea
            readonly
            hide-details
            dense
            auto-grow
            :value="scriptResults"
          />
        </v-card-text>
        <v-card-actions>
          <v-btn color="primary" text @click="resultsDialog = false">Ok</v-btn>
          <v-spacer />
          <v-btn color="primary" text @click="downloadResults">Download</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
// TODO: brace appears to be abandened. Some guy put together this: https://github.com/aminoeditor/vue-ace
// or we just try to use ace directly ...
import * as ace from 'brace'
import 'brace/mode/ruby'
import 'brace/theme/twilight'
import { toDate, format } from 'date-fns'
import { Multipane, MultipaneResizer } from 'vue-multipane'
import FileOpenSaveDialog from '@cosmosc2/tool-common/src/components/FileOpenSaveDialog'
import ActionCable from 'actioncable'
import AskDialog from './AskDialog.vue'
import PromptDialog from './PromptDialog.vue'
import SuiteRunner from './SuiteRunner.vue'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'

const NEW_FILENAME = '<Untitled>'

export default {
  components: {
    FileOpenSaveDialog,
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
      showSave: false,
      alertType: null,
      alertText: '',
      state: ' ',
      scriptId: null,
      startOrGoButton: 'Start',
      startOrGoDisabled: false,
      pauseOrRetryButton: 'Pause',
      pauseOrRetryDisabled: true,
      stopDisabled: true,
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
      showSaveAs: false,
      areYouSure: false,
      subscription: null,
      cable: null,
      marker: null,
      fatal: false,
      search: '',
      messages: [],
      headers: [{ text: 'Message', value: 'message' }],
      maxArrayLength: 30,
      Range: ace.acequire('ace/range').Range,
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
    }
  },
  computed: {
    fullFilename() {
      if (this.fileModified.length > 0) {
        return this.filename + ' ' + this.fileModified
      } else {
        return this.filename
      }
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
              label: 'Show Running Scripts',
              command: () => {
                let routeData = this.$router.resolve({ name: 'RunningScripts' })
                window.open(routeData.href, '_blank')
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
              disabled: !this.scriptId,
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
  },
  mounted() {
    this.editor = ace.edit('editor')
    this.editor.setTheme('ace/theme/twilight')
    this.editor.session.setMode('ace/mode/ruby')
    this.editor.session.setTabSize(2)
    this.editor.session.setUseWrapMode(true)
    this.editor.$blockScrolling = Infinity
    this.editor.setHighlightActiveLine(false)
    this.editor.focus()
    // We listen to tokenizerUpdate rather than change because this
    // is the background process that updates as changes are processed
    // while change fires immediately before the UndoManager is updated.
    this.editor.session.on('tokenizerUpdate', this.onChange)
    window.addEventListener('keydown', this.keydown)
    this.cable = ActionCable.createConsumer('/script-api/cable')
    if (this.$route.params.id) {
      this.scriptStart(this.$route.params.id)
    }
    this.autoSaveInterval = setInterval(() => {
      this.saveFile('auto')
    }, 60000) // Save every minute
  },
  beforeDestroy() {
    this.editor.destroy()
    this.editor.container.remove()
  },
  destroyed() {
    if (this.autoSaveInterval != null) {
      clearInterval(this.autoSaveInterval)
    }
    if (this.tempFilename) {
      Api.post('/script-api/scripts/' + this.tempFilename + '/delete')
    }
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    suiteRunnerButton(event) {
      this.startOrGo(event, 'suiteRunner')
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
      if (this.editor.session.getUndoManager().dirtyCounter > 0) {
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
      this.startOrGoButton = 'Go'
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
      this.startOrGoButton = 'Start'
      this.pauseOrRetryButton = 'Pause'
      // Disable start if suiteRunner
      this.startOrGoDisabled = this.suiteRunner
      this.pauseOrRetryDisabled = true
      this.stopDisabled = true
      this.fatal = false
      this.marker = null
      this.editor.setReadOnly(false)
    },
    startOrGo(event, suiteRunner = null) {
      if (this.startOrGoButton === 'Start') {
        this.saveFile('start')

        let filename = this.filename
        if (this.filename === NEW_FILENAME) {
          // NEW_FILENAME so use tempFilename created by saveFile()
          filename = this.tempFilename
        }
        let url = '/script-api/scripts/' + filename + '/run'
        if (this.showDisconnect) {
          url += '/disconnect'
        }
        let data = { scope: localStorage.scope }
        if (suiteRunner) {
          data['suiteRunner'] = event
        }
        Api.post(url, data).then((response) => {
          this.scriptStart(response.data)
        })
      } else {
        Api.post('/script-api/running-script/' + this.scriptId + '/go')
      }
    },
    pauseOrRetry() {
      if (this.pauseOrRetryButton === 'Pause') {
        Api.post('/script-api/running-script/' + this.scriptId + '/pause')
      } else {
        this.pauseOrRetryButton = 'Pause'
        Api.post('/script-api/running-script/' + this.scriptId + '/retry')
      }
    },
    stop() {
      // We previously encountered a fatal error so remove the marker
      // and cleanup by calling scriptComplete()
      if (this.fatal) {
        this.editor.session.removeMarker(this.marker)
        this.scriptComplete()
      } else {
        Api.post('/script-api/running-script/' + this.scriptId + '/stop')
      }
    },
    step() {
      Api.post('/script-api/running-script/' + this.scriptId + '/step')
    },
    received(data) {
      switch (data.type) {
        case 'file':
          this.files[data.filename] = data.text
          break
        case 'line':
          if (data.filename !== null) {
            if (data.filename !== this.current_filename) {
              this.editor.setValue(this.files[data.filename])
              this.editor.clearSelection()
              this.current_filename = data.filename
            }
          }
          if (this.marker && !this.fatal) {
            this.editor.session.removeMarker(this.marker)
          }
          var marker = null
          switch (data.state) {
            case 'running':
              marker = 'runningMarker'
              this.startOrGoDisabled = false
              this.pauseOrRetryDisabled = false
              this.stopDisabled = false
              this.pauseOrRetryButton = 'Pause'
              break
            case 'waiting':
              marker = 'waitingMarker'
              break
            case 'paused':
              marker = 'pausedMarker'
              break
            case 'error':
              marker = 'errorMarker'
              this.pauseOrRetryButton = 'Retry'
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
            this.marker = this.editor.session.addMarker(
              new this.Range(data.line_no - 1, 0, data.line_no - 1, 1),
              marker,
              'fullLine'
            )
            this.editor.gotoLine(data.line_no)
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
      Api.post('/script-api/running-script/' + this.scriptId + '/prompt', {
        method: this.prompt.method,
        answer: value,
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
              Api.post(
                '/script-api/running-script/' + this.scriptId + '/prompt',
                {
                  method: data.method,
                  password: value, // Using password as a key automatically filters it from rails logs
                }
              )
            } else {
              Api.post(
                '/script-api/running-script/' + this.scriptId + '/prompt',
                {
                  method: data.method,
                  answer: value,
                }
              )
            }
          }
          this.ask.show = true // Display the dialog
          break
        case 'prompt_for_hazardous':
          this.prompt.title = 'Hazardous Command'
          this.prompt.message =
            'Warning: Command ' +
            data.args[0] +
            ' ' +
            data.args[1] +
            ' is Hazardous. '
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
    setFile(file) {
      this.suiteRunner = false
      // Split off the ' *' which indicates a file is modified on the server
      this.filename = file.name.split('*')[0]
      this.editor.session.setValue(file.contents)
      this.fileModified = ''
      if (file.suites) {
        if (typeof file.suites === 'string') {
          this.alertType = 'warning'
          this.alertText =
            'Processing ' + this.filename + ' resulted in: ' + file.suites
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
        } else if (type === 'start' || (type === 'auto' && this.fileModified)) {
          if (this.tempFilename === null) {
            this.tempFilename =
              format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_temp.rb'
          }
          this.showSave = true
          Api.post('/script-api/scripts/' + this.tempFilename, {
            text: this.editor.getValue(), // Pass in the raw file text
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
        Api.post('/script-api/scripts/' + this.filename, {
          text: this.editor.getValue(), // Pass in the raw file text
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
              this.alertText =
                'Error saving file. Code: ' +
                response.status +
                ' Text: ' +
                response.statusText
            }
          })
          .catch((error) => {
            this.showSave = false
          })
      }
    },
    saveAs() {
      this.showSaveAs = true
    },
    saveAsFilename(filename) {
      this.filename = filename
      if (this.tempFilename) {
        Api.post('/script-api/scripts/' + this.tempFilename + '/delete')
        this.tempFilename = null
      }
      this.saveFile()
    },
    delete() {
      this.areYouSure = true
    },
    confirmDelete(action) {
      if (action === true) {
        // TODO: Delete instead of post
        Api.post('/script-api/scripts/' + this.filename + '/delete', {}).then(
          (response) => {
            this.areYouSure = false
            this.newFile()
          }
        )
      }
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
      Api.post(
        '/script-api/scripts/syntax',
        this.editor.getValue() // Pass in the raw text, no scope needed
      ).then((response) => {
        this.infoTitle = response.data.title
        this.infoText = JSON.parse(response.data.description)
        this.infoDialog = true
      })
    },
    showCallStack() {
      Api.post('/script-api/running-script/' + this.scriptId + '/backtrace')
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
        Api.post('/script-api/running-script/' + this.scriptId + '/debug', {
          args: this.debug,
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
      let output = ''
      for (let msg of this.messages) {
        output += msg.message + '\n'
      }
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
