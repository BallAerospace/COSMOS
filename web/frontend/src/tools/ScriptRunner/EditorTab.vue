<template>
  <div>
    <v-alert dense dismissible :type="alertType" v-if="alertType">{{
      alertText
    }}</v-alert>
    <v-container id="header" class="pane">
      <v-row no-gutters>
        <v-icon v-if="showDisconnect" class="mr-2" color="red"
          >mdi-connection</v-icon
        >
        <v-btn
          color="primary"
          @click="startOrGo"
          style="width: 100px"
          class="mr-4"
          >{{ startOrGoButton }}
          <v-icon right> mdi-play </v-icon>
        </v-btn>
        <v-btn
          color="primary"
          @click="pauseOrRetry"
          style="width: 100px"
          class="mr-4"
          >{{ pauseOrRetryButton }} <v-icon right> mdi-pause </v-icon>
        </v-btn>
        <v-btn color="primary" @click="stop" style="width: 100px" class="mr-4"
          >Stop <v-icon right> mdi-stop </v-icon>
        </v-btn>
        <v-text-field
          class="shrink"
          style="width: 120px"
          outlined
          dense
          hide-details
          label="Script State"
          v-model="state"
        ></v-text-field>
        <v-progress-circular
          v-if="state === 'Connecting...'"
          :size="40"
          class="ml-2"
          indeterminate
          color="primary"
        ></v-progress-circular>
        <div v-else style="width: 40px; height: 40px" class="ml-2"></div>
        <v-text-field
          class="ml-2"
          outlined
          dense
          hide-details
          label="Filename"
          v-model="fullFileName"
        ></v-text-field>
        <v-icon v-if="showDisconnect" class="ml-2" color="red"
          >mdi-connection</v-icon
        >
      </v-row>
    </v-container>
    <!-- Create Multipane container to support resizing.
         NOTE: We listen to paneResize event and call editor.resize() to prevent weird sizing issues -->
    <Multipane
      class="horizontal-panes"
      layout="horizontal"
      @paneResize="editor.resize()"
    >
      <div id="editorbox" class="pane">
        <pre id="editor"></pre>
      </div>
      <MultipaneResizer><hr /></MultipaneResizer>
      <div id="messages" class="ma-2 pane" ref="messagesDiv">
        <v-container id="debug" class="pa-0" v-if="showDebug">
          <v-row no-gutters>
            <v-btn
              color="primary"
              @click="step"
              style="width: 100px"
              class="mr-4"
              >Step
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
            ></v-text-field>
          </v-row>
        </v-container>
        <v-card>
          <v-card-title>
            Log Messages
            <v-spacer></v-spacer>
            <v-text-field
              v-model="search"
              append-icon="mdi-magnify"
              label="Search"
              single-line
              hide-details
              data-test="search-output-messages"
            ></v-text-field>
            <v-icon @click="downloadLog" class="pa-2 mt-3">mdi-download</v-icon>
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
          ></v-data-table>
        </v-card>
      </div>
    </Multipane>
    <AskDialog
      v-if="ask.show"
      :question="ask.question"
      :default="ask.default"
      :password="ask.password"
      :answerRequired="ask.answerRequired"
      @submit="ask.callback"
    ></AskDialog>
    <PromptDialog
      v-if="prompt.show"
      :title="prompt.title"
      :message="prompt.message"
      :buttons="prompt.buttons"
      :layout="prompt.layout"
      @submit="prompt.callback"
    ></PromptDialog>
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <FileOpenSaveDialog
      v-if="fileOpen"
      v-model="fileOpen"
      type="open"
      @file="setFile($event)"
    />
    <FileOpenSaveDialog
      v-if="showSaveAs"
      v-model="showSaveAs"
      type="save"
      :inputFileName="fileName"
      @file-name="saveAsFileName($event)"
    />
    <v-dialog v-model="areYouSure" max-width="350">
      <v-card>
        <v-card-title class="headline"> Are you sure? </v-card-title>
        <v-card-text>Permanently delete file {{ fileName }}! </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
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
            <v-row no-gutters v-for="(line, index) in infoText" :key="index">{{
              line
            }}</v-row>
          </v-container>
        </v-card-text>
        <v-card-actions>
          <v-btn color="primary" text @click="infoDialog = false"> Ok </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import axios from 'axios'
import * as ace from 'brace'
import 'brace/mode/ruby'
import 'brace/theme/twilight'
import { toDate, format } from 'date-fns'
import { Multipane, MultipaneResizer } from 'vue-multipane'
import FileOpenSaveDialog from '@/components/FileOpenSaveDialog'
import ActionCable from 'actioncable'
import AskDialog from './AskDialog.vue'
import PromptDialog from './PromptDialog.vue'

const NEW_FILENAME = '<Untitled>'

export default {
  components: {
    FileOpenSaveDialog,
    AskDialog,
    PromptDialog,
    Multipane,
    MultipaneResizer,
  },
  data() {
    return {
      alertType: null,
      alertText: '',
      state: ' ',
      scriptId: null,
      pauseOrRetryButton: 'Pause',
      showDebug: false,
      debug: '',
      debugHistory: [],
      debugHistoryIndex: 0,
      showDisconnect: false,
      files: {},
      fileName: NEW_FILENAME,
      tempFileName: null,
      fileModified: '',
      fileOpen: false,
      startOrGoButton: 'Start',
      showSaveAs: false,
      areYouSure: false,
      subscription: null,
      cable: null,
      marker: null,
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
        message: '',
        buttons: null,
        layout: 'horizontal',
        callback: () => {},
      },
      infoDialog: false,
      infoTitle: '',
      infoText: [],
    }
  },
  computed: {
    fullFileName() {
      return this.fileName + ' ' + this.fileModified
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
    this.editor.session.on('change', this.onChange)
    window.addEventListener('keydown', this.keydown)
    // Prevent the user from closing the tab accidentally
    window.addEventListener('beforeunload', (event) => {
      // Cancel the event as stated by the standard.
      event.preventDefault()
      // Older browsers supported custom message
      event.returnValue = ''
    })
    this.cable = ActionCable.createConsumer('ws://localhost:3001/cable')

    if (this.$route.params.id) {
      this.state = 'Connecting...'
      this.startOrGoButton = 'Go'
      this.scriptId = this.$route.params.id
      this.editor.setReadOnly(true)
      this.subscription = this.cable.subscriptions.create(
        { channel: 'RunningScriptChannel', id: this.scriptId },
        {
          received: (data) => this.received(data),
        }
      )
    }
  },
  beforeDestroy() {
    this.editor.destroy()
    this.editor.container.remove()
  },
  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
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
    onChange(delta) {
      // Don't track changes on a new unsaved file
      if (this.fileName !== NEW_FILENAME) {
        this.fileModified = '*'
      }
    },
    startOrGo() {
      if (this.startOrGoButton === 'Start') {
        this.saveFile('start') // Save first or they'll be running old code

        let fileName = this.fileName
        if (this.fileName === NEW_FILENAME) {
          // NEW_FILENAME so use tempFileName created by saveFile()
          fileName = this.tempFileName
        }
        let url = 'http://localhost:3001/scripts/' + fileName + '/run'
        if (this.showDisconnect) {
          url += '/disconnect'
        }
        axios.post(url).then((response) => {
          this.state = 'Connecting...'
          this.startOrGoButton = 'Go'
          this.scriptId = response.data
          this.editor.setReadOnly(true)
          this.subscription = this.cable.subscriptions.create(
            { channel: 'RunningScriptChannel', id: this.scriptId },
            {
              received: (data) => this.received(data),
            }
          )
        })
      } else {
        axios.post(
          'http://localhost:3001/running-script/' + this.scriptId + '/go'
        )
      }
    },
    pauseOrRetry() {
      if (this.pauseOrRetryButton === 'Pause') {
        axios.post(
          'http://localhost:3001/running-script/' + this.scriptId + '/pause'
        )
      } else {
        this.pauseOrRetryButton = 'Pause'
        axios.post(
          'http://localhost:3001/running-script/' + this.scriptId + '/retry'
        )
      }
    },
    stop() {
      axios.post(
        'http://localhost:3001/running-script/' + this.scriptId + '/stop'
      )
    },
    step() {
      axios.post(
        'http://localhost:3001/running-script/' + this.scriptId + '/step'
      )
    },
    received(data) {
      // console.log(data)
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
          if (this.marker) {
            this.editor.session.removeMarker(this.marker)
          }
          var marker = null
          switch (data.state) {
            case 'running':
              marker = 'runningMarker'
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
        case 'complete':
          this.startOrGoButton = 'Start'
          this.pauseOrRetryButton = 'Pause'
          this.editor.setReadOnly(false)
          // Delete the temp file created as a result of saving a NEW file
          if (this.tempFileName) {
            axios.post(
              'http://localhost:3001/scripts/' + this.tempFileName + '/delete'
            )
          }
        default:
          // console.log('Unexpected ActionCable message')
          // console.log(data)
          break
      }
    },
    promptDialogCallback(value) {
      this.prompt.show = false
      axios.post(
        'http://localhost:3001/running-script/' + this.scriptId + '/prompt',
        { method: this.prompt.method, answer: value }
      )
    },
    handleScript(data) {
      this.prompt.method = data.method // Set it here since all prompts use this
      this.prompt.layout = 'horizontal' // Reset the layout since most are horizontal
      this.prompt.buttons = null // Reset buttons so 'Yes', 'No' are used by default
      switch (data.method) {
        case 'ask_string':
          // Reset values since this dialog can be re-used
          this.ask.default = null
          this.ask.answerRequired = true
          this.ask.password = false
          this.ask.question = data.args[0]
          // If the second parameter is not true or false it indicates a default value
          if (data.args[1] !== true && data.args[1] !== false) {
            this.ask.default = data.args[1]
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
            axios.post(
              'http://localhost:3001/running-script/' +
                this.scriptId +
                '/prompt',
              { method: data.method, answer: value }
            )
          }
          this.ask.show = true // Display the dialog
          break
        case 'prompt_dialog_box':
          this.prompt.title = data.args[0]
          this.prompt.message = data.args[1]
          this.prompt.callback = this.promptDialogCallback
          this.prompt.show = true
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
        case 'prompt_to_continue':
          this.prompt.title = 'Prompt'
          this.prompt.message = data.args[0]
          this.prompt.buttons = [
            { text: 'Ok', value: 'Ok' },
            { text: 'Cancel', value: 'Cancel' },
          ]
          this.prompt.callback = this.promptDialogCallback
          this.prompt.show = true
          break
        case 'prompt_combo_box':
          this.prompt.title = 'Prompt'
          this.prompt.message = data.args[0]
          data.args[1].forEach((v) => {
            this.prompt.buttons.push({ text: v, value: v })
          })
          this.prompt.combo = true
          this.prompt.layout = 'combo'
          this.prompt.callback = this.promptDialogCallback
          this.prompt.show = true
          break
        case 'prompt_message_box':
        case 'prompt_vertical_message_box':
          this.prompt.title = 'Prompt'
          this.prompt.message = data.args[0]
          data.args[1].forEach((v) => {
            this.prompt.buttons.push({ text: v, value: v })
          })
          // If the last item is false it means they don't want a Cancel button
          if (data.args[1][data.args[1].length - 1] === false) {
            this.prompt.buttons.pop()
          } else {
            this.prompt.buttons.push({ text: 'Cancel', value: 'Cancel' })
          }
          if (data.method === 'prompt_vertical_message_box') {
            this.prompt.layout = 'vertical'
          }
          this.prompt.callback = this.promptDialogCallback
          this.prompt.show = true
          break
        case 'backtrace':
          this.infoTitle = 'Call Stack'
          this.infoText = JSON.parse(data.args)
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
      this.fileName = NEW_FILENAME
      this.editor.session.setValue('')
      this.fileModified = ''
    },
    openFile() {
      this.fileOpen = true
    },
    // Called by the FileOpenDialog to set the file contents
    setFile(file) {
      this.fileName = file.name
      this.editor.session.setValue(file.contents)
      this.fileModified = ''
    },
    // saveFile takes a type to indicate if it was called by the Menu
    // or automatically by the 'Start' button (to ensure a consistent backend file)
    saveFile(type = 'menu') {
      if (this.fileName === NEW_FILENAME) {
        // If this saveFile was called by 'Start' we need to create a temp file
        if (type === 'start') {
          this.tempFileName =
            format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_temp.rb'
          axios.post(
            'http://localhost:3001/scripts/' + this.tempFileName,
            this.editor.getValue() // Pass in the raw file text
          )
        } else {
          // Menu driven saves on a new file should prompt SaveAs
          this.saveAs()
        }
      } else {
        // Save an existing file by posting the new contents
        axios
          .post(
            'http://localhost:3001/scripts/' + this.fileName,
            this.editor.getValue() // Pass in the raw file text
          )
          .then((response) => {
            if (response.status == 200) {
              this.fileModified = ''
            } else {
              this.alertType = 'error'
              this.alertText =
                'Error saving file. Code: ' +
                response.status +
                ' Text: ' +
                response.statusText
            }
          })
      }
    },
    saveAs() {
      this.showSaveAs = true
    },
    saveAsFileName(fileName) {
      this.fileName = fileName
      this.saveFile()
    },
    delete() {
      this.areYouSure = true
    },
    confirmDelete(action) {
      if (action === true) {
        axios
          .post('http://localhost:3001/scripts/' + this.fileName + '/delete')
          .then((response) => {
            this.areYouSure = false
            this.newFile()
          })
      }
    },
    download() {
      const blob = new Blob([this.editor.getValue()], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute('download', this.fileName)
      link.click()
    },

    // ScriptRunner Script menu actions
    rubySyntaxCheck() {
      axios
        .post(
          'http://localhost:3001/scripts/syntax',
          this.editor.getValue() // Pass in the raw text
        )
        .then((response) => {
          console.log(response.data)
          this.infoTitle = response.data.title
          this.infoText = JSON.parse(response.data.description)
          this.infoDialog = true
        })
    },
    showCallStack() {
      axios.post(
        'http://localhost:3001/running-script/' + this.scriptId + '/backtrace'
      )
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
        axios.post(
          'http://localhost:3001/running-script/' + this.scriptId + '/debug',
          { args: this.debug }
        )
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
</style>
