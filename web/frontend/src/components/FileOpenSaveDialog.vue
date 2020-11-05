<template>
  <v-dialog v-model="show" width="400">
    <v-card>
      <v-card-title>{{ title }}</v-card-title>
      <v-sheet class="pl-4 pr-4">
        <v-text-field
          label="Search"
          v-model="search"
          @input="handleSearch"
          autofocus
          flat
          solo-inverted
          hide-details
          clearable
          clear-icon="mdi-close-circle-outline"
        ></v-text-field>
      </v-sheet>
      <v-card-text>
        <v-treeview
          ref="tree"
          :items="tree"
          :search="search"
          :open-on-click="type === 'open'"
          return-object
          @update:active="activeFile"
          activatable
          dense
        >
          <template v-slot:prepend="{ item, open }">
            <v-icon v-if="!item.file">
              {{ open ? 'mdi-folder-open' : 'mdi-folder' }}
            </v-icon>
            <v-icon v-else>
              {{ 'mdi-language-ruby' }}
            </v-icon>
          </template></v-treeview
        >
        <v-alert dense type="warning" v-if="warning">{{ warningText }}</v-alert>
        <v-text-field
          v-if="type === 'save'"
          hide-details
          label="File Name"
          v-model="selectedFile"
        ></v-text-field>
      </v-card-text>
      <v-card-actions>
        <v-btn color="primary" text @click="ok()">Ok</v-btn>
        <v-spacer></v-spacer>
        <v-btn color="primary" text @click="show = false">Cancel</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
import axios from 'axios'

export default {
  props: {
    type: {
      type: String,
      required: true,
      validator: function (value) {
        // The value must match one of these strings
        return ['open', 'save'].indexOf(value) !== -1
      },
    },
    inputFileName: String, // passed if this is a 'save' dialog
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      tree: [],
      id: 1,
      search: null,
      selectedFile: null,
      warning: false,
      warningText: '',
    }
  },
  computed: {
    title() {
      if (this.type === 'open') {
        return 'File Open'
      } else {
        return 'File Save As...'
      }
    },
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  created() {
    axios.get('http://localhost:3001/scripts').then((response) => {
      this.tree = []
      this.id = 1
      for (let file of response.data) {
        this.filepath = file
        this.insertFile(this.tree, 1, file)
        this.id++
      }
      if (this.inputFileName) {
        this.selectedFile = this.inputFileName
      }
    })
  },
  methods: {
    handleSearch(input) {
      if (input) {
        this.$refs.tree.updateAll(true)
      } else {
        this.$refs.tree.updateAll(false)
      }
    },
    activeFile(file) {
      if (file.length === 0) {
        this.selectedFile = null
      } else {
        this.selectedFile = file[0].path
        this.warning = false
      }
    },
    ok() {
      if (this.selectedFile === null) {
        this.warningText = 'Nothing selected'
        this.warning = true
        return
      }
      if (this.type === 'open') {
        axios
          .get('http://localhost:3001/scripts/' + this.selectedFile)
          .then((response) => {
            const file = { name: this.selectedFile, contents: response.data }
            this.$emit('file', file)
            this.show = false
          })
      } else {
        if (!this.checkValid(this.selectedFile)) {
          this.warningText =
            this.selectedFile + ' is not a valid path / filename.'
          this.warning = true
          return
        }
        this.found = false
        this.checkExists(this.tree, this.selectedFile)
        if (this.found && !this.warning) {
          this.warningText =
            this.selectedFile + ' already exists. Click OK to overwrite.'
          this.warning = true
          return
        } else {
          this.$emit('file-name', this.selectedFile)
          this.show = false
        }
      }
    },
    checkValid(filename) {
      // Require a path 2 levels deep with a file extension, e.g. INST/lib/inst.rb
      if (filename.match(/.*\/.*\/.*\..*/)) return true
      return false
    },
    checkExists(root, name) {
      for (let item of root) {
        if (item.path === name) this.found = true
        if (item.children) this.checkExists(item.children, name)
      }
    },
    insertFile(root, level, path) {
      var parts = path.split('/')
      // When there is only 1 part we're at the root so push the filename
      if (parts.length === 1) {
        root.push({
          id: this.id,
          name: parts[0],
          file: 'ruby',
          path: this.filepath,
        })
        this.id++
        return
      }
      // Look for the first part of the path
      const index = root.findIndex((item) => item.name === parts[0])
      if (index === -1) {
        // Name not found so push the item and add a children array
        root.push({
          id: this.id,
          name: parts[0],
          children: [],
          path: this.filepath.split('/').slice(0, level).join('/'),
        })
        this.id++
        this.insertFile(
          root[root.length - 1].children, // Start from the node we just added
          level + 1,
          parts.slice(1).join('/') // Strip the first part of the path
        )
      } else {
        // We already have something at this level so recursively
        // call the insertPart using the node we found and adjust the path
        this.insertFile(
          root[index].children,
          level + 1,
          parts.slice(1).join('/')
        )
      }
    },
  },
}
</script>
