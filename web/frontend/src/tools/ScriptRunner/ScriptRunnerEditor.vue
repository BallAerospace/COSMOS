<template>
  <div>
    <app-nav />
    <v-btn v-if="showRestart" color="primary" @click="restart">Restart</v-btn>
    <div v-if="showGoPauseStop" style="display: inline">
      <v-btn color="primary" @click="go">Go</v-btn>
      <v-btn color="primary" @click="pause">Pause</v-btn>
      <v-btn color="primary" @click="stop">Stop</v-btn>
    </div>
    <span>State: {{ state }}</span>
    <div id="editorbox">
      <pre id="editor"></pre>
      <div v-if="state === 'Connecting...'" class="loadingOverlay">
        <div class="loaderBox">
          <div class="overlayMessage">Connecting...</div>
          <div class="loader"></div>
        </div>
      </div>
    </div>
    <div id="messages" class="ma-2" ref="messagesDiv">
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
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import * as ace from 'brace'
import 'brace/mode/ruby'
import 'brace/theme/twilight'
import axios from 'axios'
import ActionCable from 'actioncable'
import AskDialog from './AskDialog.vue'
import PromptDialog from './PromptDialog.vue'

export default {
  components: { AppNav, AskDialog, PromptDialog },
  data() {
    return {
      title: 'ScriptRunner Editor',
      showGoPauseStop: true,
      showRestart: false,
      curTab: null,
      tabs: [],
      current_filename: null,
      files: {},
      editor: null,
      cable: null,
      subscription: null,
      marker: null,
      state: 'Connecting...',
      search: '',
      messages: [],
      headers: [
        { text: 'Time', value: '@timestamp', width: 250 },
        { text: 'Message', value: 'message' },
      ],
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
    }
  },
  mounted() {
    this.editor = ace.edit('editor')
    this.editor.setTheme('ace/theme/twilight')
    this.editor.session.setMode('ace/mode/ruby')
    this.editor.$blockScrolling = Infinity
    this.editor.setReadOnly(true)
    this.editor.setHighlightActiveLine(false)
    this.subscribe()
  },
  beforeDestroy() {
    this.editor.destroy()
    this.editor.container.remove()
  },
  destroyed() {
    this.subscription.unsubscribe()
    this.cable.disconnect()
  },
  methods: {
    restart() {},
    go() {
      axios.post(
        'http://localhost:3001/running-script/' + this.$route.params.id + '/go',
        {}
      )
    },
    pause() {
      axios.post(
        'http://localhost:3001/running-script/' +
          this.$route.params.id +
          '/pause',
        {}
      )
    },
    stop() {
      axios.post(
        'http://localhost:3001/running-script/' +
          this.$route.params.id +
          '/stop',
        {}
      )
    },
    received(data) {
      //console.log(data)
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
              break
            case 'waiting':
              marker = 'waitingMarker'
              break
            case 'paused':
              marker = 'pausedMarker'
              break
            case 'error':
              marker = 'errorMarker'
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
          this.messages.push({ '@timestamp': Date.now(), message: data.line })
          while (this.messages.length > this.maxArrayLength) {
            this.messages.shift()
          }
          break

        case 'script':
          this.handleScript(data)
          break

        default:
          //console.log('Unexpected ActionCable message')
          //console.log(data)
          break
      }
      //event.unshift(Date.now())
    },
    scrollDown() {
      this.$refs.messagesDiv.scrollTop = this.$refs.messagesDiv.scrollHeight
    },
    subscribe() {
      this.cable = ActionCable.createConsumer('ws://localhost:3001/cable')
      this.subscription = this.cable.subscriptions.create(
        { channel: 'RunningScriptChannel', id: this.$route.params.id },
        {
          received: (data) => this.received(data),
        }
      )
    },
    promptDialogCallback(value) {
      this.prompt.show = false
      axios.post(
        'http://localhost:3001/running-script/' +
          this.$route.params.id +
          '/prompt',
        { method: this.prompt.method, answer: value }
      )
    },
    handleScript(data) {
      this.prompt.method = data.method // Set it here since all prompts use this
      this.prompt.layout = 'horizontal' // Reset the layout since most are horizontal
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
                this.$route.params.id +
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
          this.prompt.buttons = []
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
          this.prompt.buttons = []
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
        default:
          /* console.log(
            'Unknown script method:' + data.method + ' with args:' + data.args
          ) */
          break
      }
    },
  },
}
</script>

<style scoped>
.v-card,
.v-card__title {
  background-color: var(--v-secondary-darken3);
}
body {
  overflow: hidden;
}
#editorbox {
  margin: 0;
  position: absolute;
  top: 60px;
  bottom: 220px;
  left: 0;
  right: 0;
}
#editor {
  margin: 0;
  position: absolute;
  top: 0px;
  bottom: 0px;
  left: 0;
  right: 0;
  font-size: 16px;
}
#messages {
  margin: 0;
  position: absolute;
  height: 200px;
  bottom: 0;
  left: 0;
  right: 0;
  overflow: auto;
}
.v-btn {
  margin-right: 10px;
}
.loadingOverlay {
  position: absolute;
  top: 0;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  opacity: 0.25;
}
.loaderBox {
  position: relative;
  left: 50%;
  top: 50%;
}
.loader {
  border: 16px solid black;
  border-radius: 50%;
  border-top: 16px solid #3498db;
  width: 70px;
  height: 70px;
  -webkit-animation: spin 2s linear infinite;
  animation: spin 2s linear infinite;
}
.overlayMessage {
  color: black;
}
@-webkit-keyframes spin {
  0% {
    -webkit-transform: rotate(0deg);
  }
  100% {
    -webkit-transform: rotate(360deg);
  }
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
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
  background: rgba(100, 180, 100, 0.5);
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
