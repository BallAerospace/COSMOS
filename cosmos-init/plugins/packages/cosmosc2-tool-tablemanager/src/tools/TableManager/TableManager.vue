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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <div>
    <top-bar :menus="menus" :title="title" />
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
    <v-file-input
      show-size
      v-model="fileInput"
      ref="fileInput"
      accept=".bin"
      data-test="fileInput"
      style="position: fixed; top: -100%"
    />
    <v-text-field
      outlined
      dense
      readonly
      hide-details
      label="Definition"
      v-model="definitionFilename"
      id="definition-filename"
      data-test="definitionFilename"
    />
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
    <v-card>
      <v-card-title>
        Items
        <v-spacer />
        <v-text-field
          v-model="search"
          append-icon="$astro-search"
          label="Search"
          single-line
          hide-details
        />
      </v-card-title>
      <v-data-table
        :headers="headers"
        :items="rows"
        :search="search"
        calculate-widths
        disable-pagination
        hide-default-footer
        multi-sort
        dense
      >
        <template v-slot:item.index="{ item }">
          <span>
            {{
              rows
                .map(function (x) {
                  return x.name
                })
                .indexOf(item.name)
            }}
          </span>
        </template>
        <template v-slot:item.value="{ item }">
          <table-item :item="item" :key="item.name" @change="onChange(item, $event)" />
        </template>
      </v-data-table>
    </v-card>
    <file-open-save-dialog
      v-if="fileOpen"
      v-model="fileOpen"
      type="open"
      api-url="/cosmos-api/tables"
      @file="setFile($event)"
      @error="setError($event)"
    />
    <file-open-save-dialog
      v-if="showSaveAs"
      v-model="showSaveAs"
      type="save"
      require-target-parent-dir
      api-url="/cosmos-api/tables"
      :input-filename="filename"
      @filename="saveAsFilename($event)"
      @error="setError($event)"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'
import TableItem from '@/tools/TableManager/TableItem'
import FileOpenSaveDialog from '@cosmosc2/tool-common/src/components/FileOpenSaveDialog'

export default {
  components: {
    TopBar,
    TableItem,
    FileOpenSaveDialog,
  },
  data() {
    return {
      title: 'Table Manager',
      search: '',
      tableName: '',
      rows: [],
      headers: [
        { text: 'Index', value: 'index' },
        { text: 'Name', value: 'name' },
        { text: 'Value', value: 'value' },
      ],
      api: null,
      definition: null,
      fileInput: '',
      definitionFilename: '',
      fileNew: false,
      filename: '',
      fileModified: '',
      lockedBy: null,
      fileOpen: false,
      showSave: false,
      showSaveAs: false,
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
              label: 'Upload',
              icon: 'mdi-cloud-upload',
              command: () => {
                this.upload()
              },
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
      ]
    },
  },
  created() {
    this.api = new CosmosApi()
  },
  methods: {
    // File menu actions
    newFile: function () {
      this.fileModified = ''
      this.fileNew = true
      this.fileOpen = true
    },
    openFile: function () {
      this.fileOpen = true
    },
    // Called by the FileOpenDialog to set the file contents
    setFile: function ({ file, locked }) {
      // They opened a definition file so create a new binary
      if (file.name.includes('.txt')) {
        if (this.fileNew) {
          this.buildNewBinary(file)
          this.fileNew = false
        } else {
          this.getDefinition(file.name)
        }
      } else {
        this.unlockFile() // first unlock what was just being edited
        // Split off the ' *' which indicates a file is modified on the server
        this.filename = file.name.split('*')[0]
        this.fileModified = ''
        this.lockedBy = locked

        this.getDefinition()
      }
    },
    saveFile: function () {
      // Save a file by posting the new contents
      this.showSave = true

      const formData = new FormData()
      formData.append('binary', this.filename)
      formData.append('definition', this.definitionFilename)
      let table = { [this.tableName]: this.rows }
      formData.append('table', JSON.stringify(table))
      console.log(`filename:${this.filename}`)
      Api.post(`/cosmos-api/tables/save`, {
        data: formData,
      })
        .then((response) => {
          if (response.status == 200) {
            this.fileModified = ''
            setTimeout(() => {
              this.showSave = false
            }, 2000)
          } else {
            this.showSave = false
            this.$notify.caution({
              title: 'Error',
              body: `Error saving file. Code: ${response.status} Text: ${response.statusText}`,
            })
          }
        })
        .catch(({ response }) => {
          this.showSave = false
          this.$notify.caution({
            title: 'Error',
            body: `Error saving file. Code: ${response.status} Text: ${response.statusText}`,
          })
        })
      this.lockFile() // Ensure this file is locked for editing
    },
    saveAs: function () {
      this.showSaveAs = true
    },
    saveAsFilename: function (filename) {
      this.filename = filename
      this.saveFile()
    },
    delete: function () {
      this.$dialog
        .confirm(`Permanently delete file: ${this.filename}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          return Api.delete(`/cosmos-api/tables/${this.filename}`, {
            data: {},
          })
        })
        .then((response) => {
          this.newFile()
        })
        .catch((error) => {
          if (error) {
            this.$notify.caution({
              title: 'Error',
              body: `Error deleting file: ${error}`,
            })
          }
        })
    },
    download: function () {
      const blob = new Blob([this.editor.getValue()], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute('download', this.filename)
      link.click()
    },
    async upload() {
      this.fileInput = ''
      this.$refs.fileInput.$refs.input.click()
      // Wait for the file to be set by the dialog so upload works
      while (this.fileInput === '') {
        await new Promise((resolve) => setTimeout(resolve, 500))
      }
      this.filename = this.fileInput.name
      this.saveAs()
    },
    confirmLocalUnlock: function () {
      this.$dialog
        .confirm(
          'Are you sure you want to unlock this file for editing? If another user is editing this file, your changes might conflict with each other.',
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
      return Api.post(`/cosmos-api/tables/${this.filename}/lock`)
    },
    unlockFile: function () {
      if (this.filename !== '' && !this.readOnly) {
        Api.post(`/cosmos-api/tables/${this.filename}/unlock`)
      }
    },
    getDefinition: function (definitionFilename = null) {
      if (!definitionFilename) {
        definitionFilename = this.filename
          .replace('/bin/', '/config/')
          .replace('.bin', '_def.txt')
      }
      const formData = new FormData()
      formData.append('binary', this.filename)
      formData.append('definition', definitionFilename)
      Api.post(`/cosmos-api/tables/load`, {
        data: formData,
      })
        .then((response) => {
          this.definitionFilename = definitionFilename
          // TODO: Handle multiple tables with v-tabs
          for (const [tableName, rows] of Object.entries(response.data)) {
            this.tableName = tableName
            this.rows = rows
          }
        })
        .catch((error) => {
          if (error.response.status == 404) {
            this.$notify.normal({
              title: 'Definition File Not Found',
              body: `Definition file ${definitionFilename} not found. Please select definition file.`,
            })
            this.fileOpen = true
          } else {
            this.$notify.serious({
              title: 'Error',
              body: `Error loading due to ${error.response.statusText}. Status: ${error.response.status}`,
            })
          }
        })
    },
    buildNewBinary: function (file) {
      const formData = new FormData()
      formData.append('contents', file.contents)
      Api.post(`/cosmos-api/tables/${file.name}/generate`, {
        data: formData,
      }).then((response) => {
        this.filename = response.data.filename
        this.getDefinition(file.name)
      })
    },
    onChange: function (item, event) {
      this.fileModified = '*'
      item.value = event
    },
  },
}
</script>
