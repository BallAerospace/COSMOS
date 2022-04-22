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
    <v-row no-gutters align="center" class="px-2">
      <v-col>
        <v-file-input
          v-model="files"
          multiple
          show-size
          accept=".gem"
          class="mx-2"
          label="Click to select plugin .gem file(s)"
          ref="fileInput"
        />
      </v-col>
    </v-row>
    <v-row no-gutters class="px-2 pb-2">
      <v-btn
        @click="upload()"
        class="mx-2"
        color="primary"
        data-test="pluginUpload"
        :disabled="files.length < 1"
        :loading="loadingPlugin"
      >
        <v-icon left dark>mdi-cloud-upload</v-icon>
        <span> Upload </span>
        <template v-slot:loader>
          <span>Loading...</span>
        </template>
      </v-btn>
      <v-spacer />
      <v-btn
        @click="showDownloadDialog = true"
        class="mx-2"
        data-test="pluginDownload"
        :disabled="files.length > 0"
      >
        <v-icon left>mdi-cloud-download</v-icon>
        <span> Download </span>
      </v-btn>
    </v-row>
    <!-- TODO This alert shows both success and failure. Make consistent with rest of COSMOS. -->
    <v-alert
      dismissible
      transition="scale-transition"
      :type="alertType"
      v-model="showAlert"
      v-text="alert"
    />
    <v-list v-if="Object.keys(processes).length > 0" data-test="processList">
      <div v-for="process in processes" :key="process.name">
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title
              v-text="`Installing: ${process.detail} - ${process.state}`"
            />
            <v-list-item-subtitle
              v-text="' Updated At: ' + formatDate(process.updated_at)"
            ></v-list-item-subtitle>
          </v-list-item-content>
          <v-list-item-icon>
            <div v-if="process.state === 'Running'">
              <v-progress-circular indeterminate color="primary" />
            </div>
            <v-tooltip v-else bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon @click="showOutput(process)" v-bind="attrs" v-on="on">
                  mdi-eye
                </v-icon>
              </template>
              <span>Show Output</span>
            </v-tooltip>
          </v-list-item-icon>
        </v-list-item>
        <v-divider />
      </div>
    </v-list>
    <v-list data-test="pluginList">
      <div v-for="(plugin, index) in plugins" :key="index">
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title v-text="plugin" />
          </v-list-item-content>
          <v-list-item-icon>
            <div class="mx-3">
              <v-tooltip bottom>
                <template v-slot:activator="{ on, attrs }">
                  <v-icon @click="showPlugin(plugin)" v-bind="attrs" v-on="on">
                    mdi-eye
                  </v-icon>
                </template>
                <span>Show Plugin Details</span>
              </v-tooltip>
            </div>
            <div class="mx-3">
              <v-tooltip bottom>
                <template v-slot:activator="{ on, attrs }">
                  <v-icon
                    @click="upgradePlugin(plugin)"
                    v-bind="attrs"
                    v-on="on"
                  >
                    mdi-update
                  </v-icon>
                </template>
                <span>Upgrade Plugin</span>
              </v-tooltip>
            </div>
            <div class="mx-3">
              <v-tooltip bottom>
                <template v-slot:activator="{ on, attrs }">
                  <v-icon
                    @click="deletePlugin(plugin)"
                    v-bind="attrs"
                    v-on="on"
                  >
                    mdi-delete
                  </v-icon>
                </template>
                <span>Delete Plugin</span>
              </v-tooltip>
            </div>
          </v-list-item-icon>
        </v-list-item>
        <v-divider v-if="index < plugins.length - 1" :key="index" />
      </div>
    </v-list>
    <variables-dialog
      v-model="showVariableDialog"
      :variables="variables"
      @submit="variablesCallback"
    />
    <edit-dialog
      v-model="showEditDialog"
      v-if="showEditDialog"
      :title="`Plugin: ${dialogTitle}`"
      :content="jsonContent"
      readonly
      @submit="dialogCallback"
    />
    <download-dialog v-model="showDownloadDialog" />
    <simple-text-dialog
      v-model="showProcessOutput"
      title="Process Output"
      :text="processOutput"
    />
  </div>
</template>

<script>
import { toDate, format } from 'date-fns'
import Api from '@cosmosc2/tool-common/src/services/api'
import DownloadDialog from '@/tools/CosmosAdmin/DownloadDialog'
import EditDialog from '@/tools/CosmosAdmin/EditDialog'
import VariablesDialog from '@/tools/CosmosAdmin/VariablesDialog'
import SimpleTextDialog from '@cosmosc2/tool-common/src/components/SimpleTextDialog'

export default {
  components: {
    DownloadDialog,
    EditDialog,
    VariablesDialog,
    SimpleTextDialog,
  },
  data() {
    return {
      files: [],
      loadingPlugin: false,
      plugins: [],
      processes: {},
      alert: '',
      alertType: 'success',
      showAlert: false,
      variables: [],
      jsonContent: '',
      dialogTitle: '',
      showDownloadDialog: false,
      showProcessOutput: false,
      processOutput: '',
      showEditDialog: false,
      showVariableDialog: false,
    }
  },
  mounted() {
    this.update()
    this.updateProcesses()
  },
  methods: {
    showOutput: function (process) {
      this.processOutput = process.output
      this.showProcessOutput = true
    },
    update: function () {
      Api.get('/cosmos-api/plugins').then((response) => {
        this.plugins = response.data
      })
    },
    updateProcesses: function () {
      Api.get('/cosmos-api/process_status/plugin_install').then((response) => {
        this.processes = response.data
        if (Object.keys(this.processes).length > 0) {
          setTimeout(() => {
            this.updateProcesses()
            this.update()
          }, 10000)
        }
      })
    },
    formatDate(nanoSecs) {
      return format(
        toDate(parseInt(nanoSecs) / 1_000_000),
        'yyyy-MM-dd HH:mm:ss.SSS'
      )
    },
    upload: function (existing = null) {
      const method = existing ? 'put' : 'post'
      const path = existing
        ? `/cosmos-api/plugins/${existing}`
        : '/cosmos-api/plugins'
      this.loadingPlugin = true
      const promises = this.files.map((file) => {
        const formData = new FormData()
        formData.append('plugin', file, file.name)
        return Api[method](path, { data: formData })
      })
      Promise.all(promises)
        .then((responses) => {
          this.alert = `Uploaded ${responses.length} file${
            responses.length > 1 ? 's' : ''
          }`
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
          this.variables = responses.map((response) => {
            return {
              name: response.data.name,
              variables: response.data.variables,
            }
          })
          this.showVariableDialog = true
        })
        .catch((error) => {
          this.loadingPlugin = false
          this.files = []
        })
    },
    variablesCallback: function (updatedVariables) {
      this.showVariableDialog = false
      const promises = updatedVariables.map((plugin) => {
        return Api.post(`/cosmos-api/plugins/install/${plugin.name}`, {
          data: {
            variables: JSON.stringify(plugin.variables),
          },
        })
      })
      Promise.all(promises)
        .then((responses) => {
          this.loadingPlugin = false
          this.alert = `Started installing ${responses.length} plugin${
            responses.length > 1 ? 's' : ''
          }`
          this.alertType = 'success'
          this.showAlert = true
          this.files = []
          this.variables = []
          setTimeout(() => {
            this.showAlert = false
            this.updateProcesses()
          }, 5000)
          this.update()
        })
        .catch((error) => {
          this.loadingPlugin = false
        })
    },
    showPlugin: function (name) {
      Api.get(`/cosmos-api/plugins/${name}`).then((response) => {
        this.jsonContent = JSON.stringify(response.data, null, '\t')
        this.dialogTitle = name
        this.showEditDialog = true
      })
    },
    dialogCallback: function (content) {
      this.showEditDialog = false
    },
    deletePlugin: function (plugin) {
      this.$dialog
        .confirm(`Are you sure you want to remove: ${plugin}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          return Api.delete(`/cosmos-api/plugins/${plugin}`)
        })
        .then((response) => {
          this.alert = `Removed plugin ${plugin}`
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
    },
    async upgradePlugin(plugin) {
      this.files = []
      this.$refs.fileInput.$refs.input.click()
      // Wait for the file to be set by the dialog so upload works
      while (this.files.length === 0) {
        await new Promise((resolve) => setTimeout(resolve, 500))
      }
      this.upload(plugin)
    },
  },
}
</script>
