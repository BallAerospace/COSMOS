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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
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
    <div id="sr-controls">
      <v-row no-gutters justify="space-between">
        <v-icon v-if="showDisconnect" class="mr-2" color="red">
          mdi-connection
        </v-icon>
        <v-select
          outlined
          dense
          hide-details
          :items="fileList"
          :disabled="fileList.length <= 1"
          label="Filename"
          v-model="fullFilename"
          @change="fileNameChanged"
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
        <div v-else style="width: 40px; height: 40px" class="ml-2 mr-2"></div>

        <!-- Disable the Start button when Suite Runner controls are showing -->
        <v-spacer />
        <div v-if="startOrGoButton === 'Start'">
          <v-btn
            @click="startHandler"
            class="mx-1"
            color="primary"
            data-test="start-button"
            :disabled="startOrGoDisabled"
          >
            <span> Start </span>
          </v-btn>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-btn
                v-on="on"
                v-bind="attrs"
                @click="scriptEnvironment.show = !scriptEnvironment.show"
                class="mx-1"
                data-test="env-button"
                :color="environmentIconColor"
                :disabled="envDisabled"
              >
                <v-icon> {{ environmentIcon }} </v-icon>
              </v-btn>
            </template>
            <span> Open Environment Dialog </span>
          </v-tooltip>
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
    </div>
    <!-- Create Multipane container to support resizing.
         NOTE: We listen to paneResize event and call editor.resize() to prevent weird sizing issues,
         The event must be paneResize and not pane-resize -->
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
        <div id="debug" class="pa-0" v-if="showDebug">
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
        </div>
        <script-log-messages v-model="messages" />
      </div>
    </multipane>
    <!--- MENUS --->
    <file-open-save-dialog
      v-if="fileOpen"
      v-model="fileOpen"
      type="open"
      api-url="/script-api/scripts"
      @file="setFile($event)"
      @error="setError($event)"
    />
    <file-open-save-dialog
      v-if="showSaveAs"
      v-model="showSaveAs"
      type="save"
      api-url="/script-api/scripts"
      require-target-parent-dir
      :input-filename="filenameOrBlank"
      @filename="saveAsFilename($event)"
      @error="setError($event)"
    />
    <environment-dialog v-if="showEnvironment" v-model="showEnvironment" />
    <ask-dialog
      v-if="ask.show"
      v-model="ask.show"
      :question="ask.question"
      :default="ask.default"
      :password="ask.password"
      :answer-required="ask.answerRequired"
      @response="ask.callback"
    />
    <file-dialog
      v-if="file.show"
      v-model="file.show"
      :title="file.title"
      :message="file.message"
      :multiple="file.multiple"
      :filter="file.filter"
      @response="fileDialogCallback"
    />
    <information-dialog
      v-if="information.show"
      v-model="information.show"
      :title="information.title"
      :text="information.text"
    />
    <input-metadata-dialog
      v-if="inputMetadata.show"
      v-model="inputMetadata.show"
      :target="inputMetadata.target"
      @response="inputMetadata.callback"
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
    <results-dialog
      v-if="results.show"
      v-model="results.show"
      :text="results.text"
    />
    <script-environment-dialog
      v-if="scriptEnvironment.show"
      v-model="scriptEnvironment.show"
      :input-environment="scriptEnvironment.env"
      @environment="environmentHandler"
    />
    <simple-text-dialog
      v-model="showSuiteError"
      title="Suite Analysis Error"
      :text="suiteError"
      :width="1000"
    />
    <v-bottom-sheet v-model="showStartedScripts">
      <v-sheet class="pb-11 pt-5 px-5">
        <running-scripts
          :connect-in-new-tab="!!fileModified"
          @close="
            () => {
              showStartedScripts = false
            }
          "
        />
      </v-sheet>
    </v-bottom-sheet>
  </div>
</template>

<script>
import axios from 'axios'
import Cable from '@openc3/tool-common/src/services/cable.js'
import Api from '@openc3/tool-common/src/services/api'
import * as ace from 'ace-builds'
import 'ace-builds/src-min-noconflict/mode-ruby'
import 'ace-builds/src-min-noconflict/theme-twilight'
import 'ace-builds/src-min-noconflict/ext-language_tools'
import 'ace-builds/src-min-noconflict/ext-searchbox'
import { toDate, format } from 'date-fns'
import { Multipane, MultipaneResizer } from 'vue-multipane'
import FileOpenSaveDialog from '@openc3/tool-common/src/components/FileOpenSaveDialog'
import EnvironmentDialog from '@openc3/tool-common/src/components/EnvironmentDialog'
import SimpleTextDialog from '@openc3/tool-common/src/components/SimpleTextDialog'
import TopBar from '@openc3/tool-common/src/components/TopBar'

import AskDialog from '@/tools/ScriptRunner/Dialogs/AskDialog'
import FileDialog from '@/tools/ScriptRunner/Dialogs/FileDialog'
import InformationDialog from '@/tools/ScriptRunner/Dialogs/InformationDialog'
import InputMetadataDialog from '@/tools/ScriptRunner/Dialogs/InputMetadataDialog'
import PromptDialog from '@/tools/ScriptRunner/Dialogs/PromptDialog'
import ResultsDialog from '@/tools/ScriptRunner/Dialogs/ResultsDialog'
import ScriptEnvironmentDialog from '@/tools/ScriptRunner/Dialogs/ScriptEnvironmentDialog'
import SuiteRunner from '@/tools/ScriptRunner/SuiteRunner'
import ScriptLogMessages from '@/tools/ScriptRunner/ScriptLogMessages'
import {
  CmdCompleter,
  TlmCompleter,
  MnemonicChecker,
} from '@/tools/ScriptRunner/autocomplete'
import { SleepAnnotator } from '@/tools/ScriptRunner/annotations'
import RunningScripts from './RunningScripts.vue'

const NEW_FILENAME = '<Untitled>'
const START = 'Start'
const GO = 'Go'
const PAUSE = 'Pause'
const RETRY = 'Retry'

export default {
  components: {
    FileOpenSaveDialog,
    EnvironmentDialog,
    Multipane,
    MultipaneResizer,
    TopBar,
    AskDialog,
    FileDialog,
    InformationDialog,
    InputMetadataDialog,
    PromptDialog,
    ResultsDialog,
    ScriptEnvironmentDialog,
    SimpleTextDialog,
    SuiteRunner,
    RunningScripts,
    ScriptLogMessages,
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
      currentFilename: null,
      showSave: false,
      showAlert: false,
      alertType: null,
      alertText: '',
      state: ' ',
      scriptId: ' ',
      startOrGoButton: START,
      startOrGoDisabled: false,
      envDisabled: false,
      pauseOrRetryButton: PAUSE,
      pauseOrRetryDisabled: false,
      stopDisabled: false,
      showEnvironment: false,
      showDebug: false,
      debug: '',
      debugHistory: [],
      debugHistoryIndex: 0,
      showDisconnect: false,
      files: {},
      breakpoints: {},
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
      messages: [],
      maxArrayLength: 200,
      Range: ace.require('ace/range').Range,
      ask: {
        show: false,
        question: '',
        default: null,
        password: false,
        answerRequired: true,
        callback: () => {},
      },
      file: {
        show: false,
        message: '',
        directory: null,
        filter: '*',
        multiple: false,
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
      information: {
        show: false,
        title: '',
        text: [],
      },
      inputMetadata: {
        show: false,
        target: null,
        callback: () => {},
      },
      results: {
        show: false,
        text: '',
      },
      scriptEnvironment: {
        show: false,
        env: [],
      },
      showSuiteError: false,
      suiteError: '',
      executeSelectionMenu: false,
      menuX: 0,
      menuY: 0,
      mnemonicChecker: new MnemonicChecker(),
      showStartedScripts: false,
      activePromptId: '',
    }
  },
  computed: {
    fileList: function () {
      const filenames = Object.keys(this.files)
      filenames.push(this.fullFilename)
      return [...new Set(filenames)] // ensure unique
    },
    environmentIcon: function () {
      return this.scriptEnvironment.env.length > 0
        ? 'mdi-bookmark'
        : 'mdi-bookmark-outline'
    },
    environmentIconColor: function () {
      return this.scriptEnvironment.env.length > 0 ? 'primary' : ''
    },
    readOnly: function () {
      return !!this.lockedBy
    },
    fullFilename: function () {
      if (this.currentFilename) return this.currentFilename
      return this.filename //`${this.filename} ${this.fileModified}`.trim()
    },
    // It's annoying for people (and tests) to clear the <Untitled>
    // when saving a new file so replace with blank
    filenameOrBlank: function () {
      return this.filename === NEW_FILENAME ? '' : this.filename
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
          label: 'Edit',
          items: [
            {
              label: 'Find',
              icon: 'mdi-magnify',
              command: () => {
                this.editor.execCommand('find')
              },
            },
            {
              label: 'Replace',
              icon: 'mdi-find-replace',
              command: () => {
                this.editor.execCommand('replace')
              },
            },
          ],
        },
        {
          label: 'Script',
          items: [
            {
              label: 'View Started Scripts',
              icon: 'mdi-run',
              command: () => {
                this.showStartedScripts = true
              },
            },
            {
              divider: true,
            },
            {
              label: 'Show Environment',
              icon: 'mdi-library',
              command: () => {
                this.showEnvironment = !this.showEnvironment
              },
            },
            {
              label: 'Show Metadata',
              icon: 'mdi-calendar',
              command: () => {
                ;(this.inputMetadata.callback = () => {}),
                  (this.inputMetadata.show = !this.inputMetadata.show)
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
              label: 'Mnemonic Check',
              icon: 'mdi-spellcheck',
              command: () => {
                this.checkMnemonics()
              },
            },
            {
              label: 'View Instrumented Script',
              icon: 'mdi-code-braces-box',
              command: () => {
                this.showInstrumented()
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
            {
              divider: true,
            },
            {
              label: 'Delete All Breakpoints',
              icon: 'mdi-delete-circle-outline',
              command: () => {
                this.deleteAllBreakpoints()
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
        {
          label: 'Run from here',
          command: this.runFromCursor,
        },
        {
          label: 'Clear these breakpoints',
          command: this.clearBreakpoints,
        },
      ]
    },
  },
  watch: {
    readOnly: function (val) {
      this.showReadOnlyToast = val
      if (!this.suiteRunner) {
        this.startOrGoDisabled = val
      }
      this.editor.setReadOnly(val)
    },
  },
  created: function () {
    window.onbeforeunload = this.unlockFile
  },
  mounted: async function () {
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
    this.editor.on('guttermousedown', this.toggleBreakpoint)
    // We listen to tokenizerUpdate rather than change because this
    // is the background process that updates as changes are processed
    // while change fires immediately before the UndoManager is updated.
    this.editor.session.on('tokenizerUpdate', this.onChange)

    const sleepAnnotator = new SleepAnnotator(this.editor)
    this.editor.session.on('change', ($event, session) => {
      sleepAnnotator.annotate($event, session)
      this.updateBreakpoints($event, session)
    })

    window.addEventListener('keydown', this.keydown)
    this.cable = new Cable('/script-api/cable')
    await this.tryLoadRunningScript(this.$route.params.id)
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
  beforeRouteUpdate: function (to, from, next) {
    if (to.params.id) {
      this.tryLoadRunningScript(to.params.id).then(next)
    } else {
      next()
    }
  },
  methods: {
    fileNameChanged(filename) {
      this.editor.setValue(this.files[filename].content)
      this.restoreBreakpoints(filename)
      this.editor.clearSelection()
      this.removeAllMarkers()
      this.editor.session.addMarker(
        new this.Range(
          this.files[filename].lineNo - 1,
          0,
          this.files[filename].lineNo - 1,
          1
        ),
        `${this.state}Marker`,
        'fullLine'
      )
      this.editor.gotoLine(this.files[filename].lineNo)
      this.filename = filename
    },
    tryLoadRunningScript: function (id) {
      return Api.get('/script-api/running-script').then((response) => {
        const loadRunningScript = response.data.find(
          (s) => `${s.id}` === `${id}`
        )
        if (loadRunningScript) {
          this.filename = loadRunningScript.name
          this.tryLoadSuites()
          this.scriptStart(loadRunningScript.id)
        } else if (id) {
          this.$notify.caution({
            title: '404 Not Found',
            body: `Failed to load running script id: ${id}`,
          })
        } else {
          this.alertType = 'success'
          this.alertText = `Currently ${response.data.length} running scripts.`
          this.showAlert = true
        }
      })
    },
    tryLoadSuites: function () {
      Api.get(`/script-api/scripts/${this.filename}`).then((response) => {
        if (response.data.suites) {
          this.startOrGoDisabled = true
          this.suiteRunner = true
          this.suiteMap = JSON.parse(response.data.suites)
        }
        if (response.data.error) {
          this.suiteError = response.data.error
          this.showSuiteError = true
        }
        // Disable suite buttons if we didn't successfully parse the suite
        this.disableSuiteButtons = response.data.success == false
      })
    },
    showExecuteSelectionMenu: function ($event) {
      this.menuX = $event.pageX
      this.menuY = $event.pageY
      this.executeSelectionMenu = true
    },
    runFromCursor: function () {
      const start = this.editor.getCursorPosition().row
      const text = this.editor.session.doc
        .getLines(start, this.editor.session.doc.getLength())
        .join('\n')
      const breakpoints = this.getBreakpointRows()
        .filter((row) => row >= start)
        .map((row) => row - start)
      this.executeText(text, breakpoints)
    },
    executeSelection: function () {
      const text = this.editor.getSelectedText()
      const range = this.editor.getSelectionRange()
      const breakpoints = this.getBreakpointRows()
        .filter((row) => row <= range.end.row && row >= range.start.row)
        .map((row) => row - range.start.row)
      this.executeText(text, breakpoints)
    },
    executeText: function (text, breakpoints = []) {
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
          format(Date.now(), 'yyyy_MM_dd_HH_mm_ss_SSS') + '_temp.rb'
        Api.post(`/script-api/scripts/${selectionTempFilename}`, {
          data: {
            text,
            breakpoints,
          },
        })
          .then((response) => {
            return Api.post(
              `/script-api/scripts/${selectionTempFilename}/run`,
              {
                data: {
                  environment: this.scriptEnvironment.env,
                },
              }
            )
          })
          .then((response) => {
            window.open(`/tools/scriptrunner/${response.data}`)
          })
      }
    },
    clearBreakpoints: function () {
      this.editor.session.clearBreakpoints()
    },
    toggleBreakpoint: function ($event) {
      if (
        $event.domEvent.which === 1 && // left click
        $event.domEvent.path[0].classList.contains('ace_gutter-cell') // on a line number
      ) {
        const row = $event.getDocumentPosition().row
        if ($event.editor.session.getBreakpoints(row, 0)[row]) {
          $event.editor.session.clearBreakpoint(row)
        } else {
          $event.editor.session.setBreakpoint(row)
        }
      }
    },
    updateBreakpoints: function ($event, session) {
      if ($event.lines.length <= 1) {
        return
      }
      const rowsToUpdate = this.getBreakpointRows(session).filter(
        (row) =>
          ($event.start.column === 0 && row === $event.start.row) ||
          row > $event.start.row
      )
      let rowsToDelete = []
      let offset = 0
      switch ($event.action) {
        case 'insert':
          offset = $event.lines.length - 1
          rowsToUpdate.reverse() // shift the lower ones down out of the way first
          break
        case 'remove':
          offset = -$event.lines.length + 1
          rowsToDelete = [...Array($event.lines.length).keys()].map(
            (row) => row + $event.start.row
          )
          break
      }
      rowsToUpdate.forEach((row) => {
        session.clearBreakpoint(row)
        if (!rowsToDelete.includes(row)) {
          session.setBreakpoint(row + offset)
        }
      })
    },
    getBreakpointRows: function (session = this.editor.session) {
      return session
        .getBreakpoints()
        .map((breakpoint, row) => breakpoint && row) // [empty, 'ace_breakpoint', 'ace_breakpoint', empty] -> [empty, 1, 2, empty]
        .filter(Number.isInteger) // [empty, 1, 2, empty] -> [1, 2]
    },
    restoreBreakpoints: function (filename) {
      this.clearBreakpoints()
      this.breakpoints[filename]?.forEach((breakpoint) => {
        this.editor.session.setBreakpoint(breakpoint)
      })
    },
    deleteAllBreakpoints: function () {
      this.$dialog
        .confirm('Permanently delete all breakpoints for ALL scripts?', {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          return Api.delete('/script-api/breakpoints/delete/all')
        })
        .then((response) => {
          this.clearBreakpoints()
        })
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
    checkMnemonics: function () {
      this.mnemonicChecker
        .checkText(this.editor.getValue())
        .then(({ skipped, problems }) => {
          let alertText = ''
          if (problems.length) {
            const problemText = problems
              .map((problem) => `${problem.lineNumber}: ${problem.error}`)
              .join('<br/>')
            alertText += `<strong>The following lines have problems:</strong><br/>${problemText}<br/><br/>`
          }
          if (skipped.length) {
            alertText +=
              '<strong>Mnemonics with string interpolation were not checked.</strong>'
          }
          if (alertText === '') {
            alertText = '<strong>Everything looks good!</strong>'
          }
          this.$dialog.alert(alertText.trim(), { html: true })
        })
    },
    scriptStart(id) {
      this.disableSuiteButtons = true
      this.startOrGoDisabled = true
      this.envDisabled = true
      this.pauseOrRetryDisabled = true
      this.stopDisabled = true
      this.state = 'Connecting...'
      this.startOrGoButton = GO
      this.scriptId = id
      this.editor.setReadOnly(true)
      this.cable
        .createSubscription(
          'RunningScriptChannel',
          localStorage.scope,
          {
            received: (data) => this.received(data),
          },
          {
            id: this.scriptId,
          }
        )
        .then((subscription) => {
          this.subscription = subscription
        })
    },
    scriptComplete() {
      this.disableSuiteButtons = false
      this.startOrGoButton = START
      this.pauseOrRetryButton = PAUSE
      // Disable start if suiteRunner
      this.startOrGoDisabled = this.suiteRunner
      this.envDisabled = false
      this.pauseOrRetryDisabled = true
      this.stopDisabled = true
      // Ensure stopped, if the script has an error we don't get the server stopped message
      this.state = 'stopped'
      this.fatal = false
      this.scriptId = null
      this.editor.setReadOnly(false)
    },
    environmentHandler: function (event) {
      this.scriptEnvironment.env = event
    },
    startHandler: function () {
      this.start()
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
        environment: this.scriptEnvironment.env,
      }
      if (suiteRunner) {
        data['suiteRunner'] = event
      }
      Api.post(url, { data }).then((response) => {
        this.scriptStart(response.data)
      })
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
      // and cleanup by calling scriptComplete() because the script
      // is already stopped in the backend
      if (this.fatal) {
        this.removeAllMarkers()
        this.scriptComplete()
      } else {
        Api.post(`/script-api/running-script/${this.scriptId}/stop`)
      }
    },
    step() {
      Api.post(`/script-api/running-script/${this.scriptId}/step`)
    },
    received(data) {
      // console.log(data) // Uncomment for debugging
      switch (data.type) {
        case 'file':
          this.files[data.filename] = { content: data.text, lineNo: 0 }
          this.breakpoints[data.filename] = data.breakpoints
          if (this.currentFilename === data.filename) {
            this.restoreBreakpoints(data.filename)
          }
          break
        case 'line':
          if (data.filename && data.filename !== this.currentFilename) {
            if (!this.files[data.filename]) {
              // We don't have the contents of the running file (probably because connected to running script)
              // Set the contents initially to an empty string so we don't start slamming the API
              this.files[data.filename] = { content: '', lineNo: 0 }

              // Request the script we need
              Api.get(`/script-api/scripts/${data.filename}`)
                .then((response) => {
                  // Success - Save the script text and mark the currentFilename as null
                  // so it will get loaded in on the next line executed
                  this.files[data.filename] = {
                    content: response.data.contents,
                    lineNo: 0,
                  }
                  this.breakpoints[data.filename] = response.data.breakpoints
                  this.restoreBreakpoints(data.filename)
                  this.currentFilename = null
                })
                .catch((err) => {
                  // Error - Restore the file contents to null so we'll try the API again on the next line
                  this.files[data.filename] = null
                })
            } else {
              this.editor.setValue(this.files[data.filename].content)
              this.restoreBreakpoints(data.filename)
              this.editor.clearSelection()
              this.currentFilename = data.filename
            }
          }
          this.state = data.state
          const markers = this.editor.session.getMarkers()
          switch (this.state) {
            case 'running':
              this.startOrGoDisabled = false
              this.pauseOrRetryDisabled = false
              this.stopDisabled = false
              this.pauseOrRetryButton = PAUSE

              this.removeAllMarkers()
              this.editor.session.addMarker(
                new this.Range(data.line_no - 1, 0, data.line_no - 1, 1),
                'runningMarker',
                'fullLine'
              )
              this.editor.gotoLine(data.line_no)
              this.files[data.filename].lineNo = data.line_no
              break
            case 'fatal':
              this.fatal = true
            // Deliberate fall through (no break)
            case 'error':
              this.pauseOrRetryButton = RETRY
            // Deliberate fall through (no break)
            case 'breakpoint':
            case 'waiting':
            case 'paused':
              if (this.state == 'fatal') {
                this.startOrGoDisabled = true
                this.pauseOrRetryDisabled = true
              } else {
                this.startOrGoDisabled = false
                this.pauseOrRetryDisabled = false
              }
              this.stopDisabled = false
              let existing = Object.keys(markers).filter(
                (key) => markers[key].clazz === `${this.state}Marker`
              )
              if (existing.length === 0) {
                this.removeAllMarkers()
                let line = data.line_no > 0 ? data.line_no : 1
                this.editor.session.addMarker(
                  new this.Range(line - 1, 0, line - 1, 1),
                  `${this.state}Marker`,
                  'fullLine'
                )
                this.editor.gotoLine(line)
                // Fatal errors don't always have a filename set
                if (data.filename) {
                  this.files[data.filename].lineNo = line
                }
              }
              break
            default:
              break
          }
          break
        case 'output':
          this.messages.unshift({ message: data.line })
          while (this.messages.length > this.maxArrayLength) {
            this.messages.pop()
          }
          break
        case 'script':
          this.handleScript(data)
          break
        case 'report':
          this.results.text = data.report
          this.results.show = true
          break
        case 'complete':
          // Don't complete on fatal because we just sit there on the fatal line
          if (!this.fatal) {
            this.removeAllMarkers()
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
          prompt_id: this.activePromptId,
        },
      })
    },
    handleScript(data) {
      if (data.prompt_complete) {
        this.activePromptId = ''
        this.prompt.show = false
        this.ask.show = false
        return
      }
      this.activePromptId = data.prompt_id
      this.prompt.method = data.method // Set it here since all prompts use this
      this.prompt.layout = 'horizontal' // Reset the layout since most are horizontal
      this.prompt.title = 'Prompt'
      this.prompt.subtitle = ''
      this.prompt.details = ''
      this.prompt.buttons = []
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
                  prompt_id: this.activePromptId,
                },
              })
            } else {
              Api.post(`/script-api/running-script/${this.scriptId}/prompt`, {
                data: {
                  method: data.method,
                  answer: value,
                  prompt_id: this.activePromptId,
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
          this.prompt.buttons = [{ text: 'Yes', value: 'Yes' }]
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
          this.information.title = 'Call Stack'
          this.information.text = data.args
          this.information.show = true
          break
        case 'input_metadata':
          this.inputMetadata.target = data.args[0]
          this.inputMetadata.callback = (value) => {
            this.inputMetadata.show = false
            Api.post(`/script-api/running-script/${this.scriptId}/prompt`, {
              data: {
                method: data.method,
                answer: value,
                prompt_id: this.activePromptId,
              },
            })
          }
          this.inputMetadata.show = true
          break
        case 'open_file_dialog':
        case 'open_files_dialog':
          this.file.title = data.args[0]
          this.file.message = data.args[1]
          if (data.kwargs && data.kwargs.filter) {
            this.file.filter = data.kwargs.filter
          }
          if (data.method == 'open_files_dialog') {
            this.file.multiple = true
          }
          this.file.show = true
          break
        default:
          /* console.log(
            'Unknown script method:' + data.method + ' with args:' + data.args
          ) */
          break
      }
    },
    async fileDialogCallback(files) {
      this.file.show = false // Close the dialog
      // Set fileNames to 'Cancel' in case they cancelled
      // otherwise we will populate it with the file names they selected
      let fileNames = 'Cancel'
      if (files != 'Cancel') {
        fileNames = []
        await files.forEach(async (file) => {
          fileNames.push(file.name)
          // Reassign data to presignedRequest for readability
          const { data: presignedRequest } = await Api.get(
            `/openc3-api/storage/upload/${encodeURIComponent(
              `${localStorage.scope}/tmp/${file.name}`
            )}?bucket=config`
          )
          // This pushes the file into S3 by using the fields in the presignedRequest
          // See storage_controller.rb get_presigned_request()
          const response = await axios({
            ...presignedRequest,
            data: file,
          })
        })
      }
      await Api.post(`/script-api/running-script/${this.scriptId}/prompt`, {
        data: {
          method: this.file.multiple ? 'open_files_dialog' : 'open_file_dialog',
          answer: fileNames,
          prompt_id: this.activePromptId,
        },
      })
    },
    setError(event) {
      this.alertType = 'error'
      this.alertText = `Error: ${event}`
      this.showAlert = true
    },
    // ScriptRunner File menu actions
    newFile() {
      this.filename = NEW_FILENAME
      this.currentFilename = null
      this.files = {} // Clear the cached file list
      this.editor.session.setValue('')
      this.fileModified = ''
      this.suiteRunner = false
      this.startOrGoDisabled = false
      this.envDisabled = false
    },
    openFile() {
      this.fileOpen = true
    },
    // Called by the FileOpenDialog to set the file contents
    setFile({ file, locked, breakpoints }) {
      this.files = {} // Clear the cached file list
      this.unlockFile() // first unlock what was just being edited
      this.suiteRunner = false
      // Split off the ' *' which indicates a file is modified on the server
      this.filename = file.name.split('*')[0]
      this.currentFilename = null
      this.editor.session.setValue(file.contents)
      this.breakpoints[filename] = breakpoints
      this.restoreBreakpoints(filename)
      this.fileModified = ''
      this.lockedBy = locked
      this.envDisabled = false

      if (file.suites) {
        this.suiteRunner = true
        this.suiteMap = file.suites
        this.startOrGoDisabled = true
      }
      if (file.error) {
        this.suiteError = file.error
        this.showSuiteError = true
      }
      // Disable suite buttons if we didn't successfully parse the suite
      this.disableSuiteButtons = file.success == false
    },
    // saveFile takes a type to indicate if it was called by the Menu
    // or automatically by 'Start' (to ensure a consistent backend file) or autoSave
    saveFile(type = 'menu') {
      const breakpoints = this.getBreakpointRows()
      if (this.filename === NEW_FILENAME) {
        if (type === 'menu') {
          // Menu driven saves on a new file should prompt SaveAs
          this.saveAs()
        } else {
          if (this.tempFilename === null) {
            this.tempFilename =
              format(Date.now(), 'yyyy_MM_dd_HH_mm_ss_SSS') + '_temp.rb'
          }
          this.showSave = true
          Api.post(`/script-api/scripts/${this.tempFilename}`, {
            data: {
              text: this.editor.getValue(), // Pass in the raw file text
              breakpoints,
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
            breakpoints,
          },
        })
          .then((response) => {
            if (response.status == 200) {
              if (response.data.suites) {
                this.startOrGoDisabled = true
                this.suiteRunner = true
                this.suiteMap = JSON.parse(response.data.suites)
              } else {
                this.startOrGoDisabled = false
                this.suiteRunner = false
                this.suiteMap = {}
              }
              if (response.data.error) {
                this.suiteError = response.data.error
                this.showSuiteError = true
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
        this.information.title = response.data.title
        this.information.text = JSON.parse(response.data.description)
        this.information.show = true
      })
    },
    showInstrumented() {
      Api.post(`/script-api/scripts/${this.filename}/instrumented`, {
        data: this.editor.getValue(),
        headers: {
          Accept: 'application/json',
          'Content-Type': 'plain/text',
        },
      }).then((response) => {
        this.information.title = response.data.title
        this.information.text = JSON.parse(response.data.description)
        this.information.show = true
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
    removeAllMarkers: function () {
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
#sr-controls {
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
  background: rgba(0, 255, 0, 0.5);
  z-index: 20;
}
.waitingMarker {
  position: absolute;
  background: rgba(0, 155, 0, 1);
  z-index: 20;
}
.breakpointMarker {
  position: absolute;
  border-style: solid;
  border-color: red;
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
.ace_gutter-cell.ace_breakpoint {
  border-radius: 20px 0px 0px 20px;
  box-shadow: 0px 0px 1px 1px red inset;
}
</style>
