<template>
  <div>
    <v-container id="header">
      <v-row no-gutters>
        <v-col cols="4">
          <v-btn color="primary" @click="start" class="mr-4"
            >Start
            <v-icon right> mdi-play </v-icon>
          </v-btn>
          <v-btn color="primary" @click="pause" class="mr-4"
            >Pause <v-icon right> mdi-pause </v-icon>
          </v-btn>
          <v-btn color="primary" @click="stop" class="mr-4"
            >Stop <v-icon right> mdi-stop </v-icon>
          </v-btn>
          <v-progress-circular
            v-if="state === 'Connecting...'"
            indeterminate
            color="primary"
          ></v-progress-circular>
        </v-col>
        <v-col cols="2">
          <v-text-field
            style="width: 150px"
            outlined
            dense
            hide-details
            label="Script State"
            v-model="state"
          ></v-text-field>
        </v-col>
        <v-col>
          <v-text-field
            class="ml-10"
            outlined
            dense
            hide-details
            label="Filename"
            v-model="fullFileName"
          ></v-text-field>
        </v-col>
      </v-row>
    </v-container>
    <div id="editorbox">
      <pre id="editor"></pre>
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

    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <FileOpenDialog
      v-if="fileOpen"
      v-model="fileOpen"
      @file="setFile($event)"
    />
    <FileSaveAsDialog
      v-if="showSaveAs"
      v-model="showSaveAs"
      :fileName="fileName"
      @fileName="saveAsFileName($event)"
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
  </div>
</template>

<script>
import axios from 'axios'
import * as ace from 'brace'
import 'brace/mode/ruby'
import 'brace/theme/twilight'
import FileOpenDialog from '@/components/FileOpenDialog'
import FileSaveAsDialog from '@/components/FileSaveAsDialog'
import ActionCable from 'actioncable'

const NEW_FILENAME = '<Untitled>'

export default {
  components: {
    FileOpenDialog,
    FileSaveAsDialog,
  },
  data() {
    return {
      state: ' ',
      scriptId: null,
      files: {},
      fileName: NEW_FILENAME,
      fileModified: '',
      fileOpen: false,
      showSaveAs: false,
      areYouSure: false,
      subscription: null,
      cable: null,
      marker: null,
      search: '',
      messages: [],
      headers: [
        { text: 'Time', value: '@timestamp', width: 250 },
        { text: 'Message', value: 'message' },
      ],
      maxArrayLength: 30,
      Range: ace.acequire('ace/range').Range,
    }
  },
  computed: {
    fullFileName() {
      return this.fileName + ' ' + this.fileModified
    },
  },
  created() {
    this.$root.$refs.Editor = this
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
      this.fileModified = '*'
    },
    start() {
      axios
        .post('http://localhost:3001/scripts/' + this.fileName + '/run', {})
        .then((response) => {
          // TODO: Start spinner
          this.state = 'Connecting...'
          this.scriptId = response.data
          this.editor.setReadOnly(true)
          this.subscription = this.cable.subscriptions.create(
            { channel: 'RunningScriptChannel', id: response.data },
            {
              received: (data) => this.received(data),
            }
          )
        })
    },
    go() {
      axios.post(
        'http://localhost:3001/running-script/' + this.scriptId + '/go',
        {}
      )
    },
    pause() {
      axios.post(
        'http://localhost:3001/running-script/' + this.scriptId + '/pause',
        {}
      )
    },
    stop() {
      axios.post(
        'http://localhost:3001/running-script/' + this.scriptId + '/stop',
        {}
      )
    },
    received(data) {
      console.log(data)
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
            console.log(this.marker)
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
          console.log('Unexpected ActionCable message')
          console.log(data)
          break
      }
    },
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
    saveFile() {
      if (this.fileName === NEW_FILENAME) {
        this.saveAs()
        return
      }
      axios
        .post(
          'http://localhost:3001/scripts/' + this.fileName,
          this.editor.getValue() // Pass in the raw file text
        )
        .then((response) => {
          this.fileModified = ''
        })
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
            console.log(response)
          })
      }
    },
  },
}
</script>

<style scoped>
#editorbox {
  height: 100vh;
}
#editor {
  height: 100%;
  width: 100%;
  position: relative;
  font-size: 16px;
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
