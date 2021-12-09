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
  <v-dialog v-model="show" width="600">
    <v-card>
      <form v-on:submit.prevent="success">
        <v-system-bar>
          <v-spacer />
          <span> {{ title }} </span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <div class="pa-3">
            <v-row dense>
              <v-text-field
                @input="handleSearch"
                v-model="search"
                flat
                autofocus
                solo-inverted
                hide-details
                clearable
                label="Search"
                data-test="file-open-save-search"
              />
            </v-row>
            <v-row dense class="mt-2">
              <v-treeview
                v-model="tree"
                @update:active="activeFile"
                dense
                activatable
                return-object
                ref="tree"
                style="width: 100%"
                :items="items"
                :search="search"
                :open-on-click="type === 'open'"
              >
                <template v-slot:prepend="{ item, open }">
                  <v-icon v-if="!item.file">
                    {{ open ? 'mdi-folder-open' : 'mdi-folder' }}
                  </v-icon>
                  <v-icon v-else>
                    {{ 'mdi-language-ruby' }}
                  </v-icon>
                </template>
              </v-treeview>
            </v-row>
            <v-row class="my-2">
              <v-text-field
                v-model="selectedFile"
                hide-details
                label="Filename"
                data-test="filename"
                :disabled="type === 'open'"
              />
            </v-row>
            <v-row dense>
              <span class="my-2 red--text" v-show="error" v-text="error" />
            </v-row>
            <v-row class="mt-2">
              <v-spacer />
              <v-btn
                @click="show = false"
                outlined
                class="mx-2"
                data-test="file-open-save-cancel-btn"
                :disabled="disableButtons"
              >
                Cancel
              </v-btn>
              <v-btn
                @click.prevent="success"
                type="submit"
                color="primary"
                class="mx-2"
                data-test="file-open-save-submit-btn"
                :disabled="disableButtons || !!error"
              >
                {{ submit }}
              </v-btn>
            </v-row>
          </div>
        </v-card-text>
      </form>
    </v-card>
  </v-dialog>
</template>

<script>
import Api from '../services/api'

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
    requireTargetParentDir: Boolean, // Require that the save filename be nested in a directory with the name of a target
    inputFilename: String, // passed if this is a 'save' dialog
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      tree: [],
      items: [],
      id: 1,
      search: null,
      selectedFile: null,
      disableButtons: false,
      targets: [],
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
    title: function () {
      if (this.type === 'open') {
        return 'File Open'
      } else {
        return 'File Save As...'
      }
    },
    submit: function () {
      if (this.type === 'open') {
        return 'OPEN'
      } else {
        return 'SAVE'
      }
    },
    error: function () {
      if (this.selectedFile === '' || this.selectedFile === null) {
        return 'No file selected must select a file'
      }
      if (
        !this.selectedFile.match(this.validFilenameRegex) ||
        this.selectedFile.match(/\.\.|\/\/|\.\/|\/\./) // Block .'s and /'s next to each other (block path traversal)
      ) {
        let message = `${this.selectedFile} is not a valid filename. Must `
        if (this.requireTargetParentDir) {
          message += 'be in a target directory and '
        }
        message += "only contain alphanumeric characters and / ! - _ . * ' ( )"
        return message
      }
      return null
    },
    validFilenameRegex: function () {
      const alphanumeric = '0-9a-zA-Z'
      const charset = `${alphanumeric}\\/\\!\\-\\_\\.\\*\\'\\(\\)` // From https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html a-z A-Z 0-9 / ! - _ . * ' ( )
      let expression = `[${charset}]+\\.[${alphanumeric}]+`
      if (this.requireTargetParentDir) {
        const targets = `(${this.targets.join('|')})`
        expression = `\\/?${targets}\\/${expression}`
      }
      return new RegExp(expression)
    },
  },
  created() {
    Api.get('/script-api/scripts')
      .then((response) => {
        this.items = []
        this.id = 1
        for (let file of response.data) {
          this.filepath = file
          this.insertFile(this.items, 1, file)
          this.id++
        }
        if (this.inputFilename) {
          this.selectedFile = this.inputFilename
        }
      })
      .catch((error) => {
        this.$emit('error', `Failed to connect to Cosmos. ${error}`)
      })
    if (this.requireTargetParentDir) {
      Api.get('/cosmos-api/targets').then((response) => {
        this.targets = response.data
      })
    }
  },
  methods: {
    clear: function () {
      this.show = false
      this.overwrite = false
      this.disableButtons = false
    },
    handleSearch: function (input) {
      if (input) {
        this.$refs.tree.updateAll(true)
      } else {
        this.$refs.tree.updateAll(false)
      }
    },
    activeFile: function (file) {
      if (file.length === 0) {
        this.selectedFile = null
      } else {
        this.selectedFile = file[0].path
      }
    },
    exists: function (root, name) {
      let found = false
      for (let item of root) {
        if (item.path === name) {
          return true
        }
        if (item.children) {
          found = found || this.exists(item.children, name)
        }
      }
      return found
    },
    success: function () {
      if (this.type === 'open') {
        this.openSuccess()
      } else {
        this.saveSuccess()
      }
    },
    openSuccess: function () {
      // Disable the buttons because the API call can take a bit
      this.disableButtons = true
      Api.get(`/script-api/scripts/${this.selectedFile}`)
        .then((response) => {
          const file = {
            name: this.selectedFile,
            contents: response.data.contents,
          }
          if (response.data.suites) {
            try {
              file['suites'] = JSON.parse(response.data.suites)
            } catch (e) {
              this.$emit('error', response.data.suites)
            }
          }
          this.$emit('file', file)
          this.clear()
        })
        .catch((error) => {
          this.$emit('error', `Failed to open ${this.selectedFile}. ${error}`)
          this.clear()
        })
    },
    saveSuccess: function () {
      const found = this.exists(this.items, this.selectedFile)
      if (found) {
        this.$dialog
          .confirm(`Are you sure you want to overwrite: ${this.selectedFile}`, {
            okText: 'Overwrite',
            cancelText: 'Cancel',
          })
          .then((dialog) => {
            this.$emit('filename', this.selectedFile)
            this.clear()
          })
      } else {
        this.$emit('filename', this.selectedFile)
        this.clear()
      }
    },
    insertFile: function (root, level, path) {
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
