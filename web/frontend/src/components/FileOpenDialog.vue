<template>
  <v-dialog v-model="show" width="400">
    <v-card>
      <v-card-title>File Open</v-card-title>
      <v-sheet class="pl-4 pr-4">
        <v-text-field
          label="Search"
          v-model="search"
          @input="handleSearch"
          flat
          solo-inverted
          hide-details
          clearable
          clear-icon="mdi-close-circle-outline"
        ></v-text-field>
      </v-sheet>
      <v-card-text>
        <v-container>
          <v-treeview
            ref="tree"
            :items="tree"
            :search="search"
            open-on-click
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
        </v-container>
        <v-alert dense type="warning" v-if="warning">No file selected</v-alert>
      </v-card-text>
      <v-card-actions>
        <v-btn color="primary" text @click="open()">Ok</v-btn>
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
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      tree: [],
      id: 1,
      search: null,
      selectedFile: null,
      warning: false,
    }
  },
  computed: {
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
        this.insertFile(this.tree, file)
        this.id++
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
    open() {
      if (this.selectedFile === null) {
        this.warning = true
        return
      }
      axios
        .get('http://localhost:3001/scripts/' + this.selectedFile)
        .then((response) => {
          this.show = false
          const file = { name: this.selectedFile, contents: response.data }
          this.$emit('file', file)
        })
    },
    insertFile(root, path) {
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
        root.push({ id: this.id, name: parts[0], children: [] })
        this.id++
        this.insertFile(
          root[root.length - 1].children, // Start from the node we just added
          parts.slice(1).join('/') // Strip the first part of the path
        )
      } else {
        // We already have something at this level so recursively
        // call the insertPart using the node we found and adjust the path
        this.insertFile(root[index].children, parts.slice(1).join('/'))
      }
    },
  },
}
</script>
