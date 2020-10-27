<template>
  <div>
    <div id="header">
      <div id="controls">
        <v-btn color="secondary" icon @click="run()">
          <v-icon>mdi-play</v-icon>
        </v-btn>
      </div>
      <div id="title">{{ fileName }}&nbsp;{{ fileModified }}</div>
    </div>
    <div id="editorbox">
      <pre id="editor"></pre>
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
        <v-card-title class="headline">
          Are you sure?
        </v-card-title>
        <v-card-text>Permanently delete file {{ fileName }}! </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="primary" text @click="confirmDelete(true)">
            Ok
          </v-btn>
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

const NEW_FILENAME = '<Untitled>'

export default {
  components: {
    FileOpenDialog,
    FileSaveAsDialog
  },
  data() {
    return {
      fileName: NEW_FILENAME,
      fileModified: '',
      fileOpen: false,
      showSaveAs: false,
      areYouSure: false
    }
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
    this.editor.session.on('change', this.onChange)
    window.addEventListener('keydown', this.keydown)
    // Prevent the user from closing the tab accidentally
    window.addEventListener('beforeunload', event => {
      // Cancel the event as stated by the standard.
      event.preventDefault()
      // Older browsers supported custom message
      event.returnValue = ''
    })
  },
  beforeDestroy() {
    this.editor.destroy()
    this.editor.container.remove()
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
    run() {
      axios
        .post('http://localhost:3001/scripts/' + this.fileName + '/run', {})
        .then(response => {
          this.$router.push({
            name: 'ScriptRunnerEditor',
            params: { id: response.data }
          })
        })
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
        .then(response => {
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
          .then(response => {
            console.log(response)
          })
      }
    }
  }
}
</script>

<style scoped>
body {
  overflow: hidden;
}
#header {
  text-align: center;
}
#title {
  padding-top: 5px;
}
#controls {
  float: left;
  margin-left: 50px;
}
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
