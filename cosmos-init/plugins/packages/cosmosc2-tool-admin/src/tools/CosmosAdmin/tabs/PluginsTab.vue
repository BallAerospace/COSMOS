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
  <div>
    <v-row no-gutters align="center" class="px-2">
      <v-col>
        <div class="px-2">
          <v-btn
            block
            data-test="pluginDownload"
            :disabled="files.length > 0"
            @click="showDownloadDialog = true"
          >
            Download
            <v-icon right dark>mdi-cloud-download</v-icon>
          </v-btn>
        </div>
      </v-col>
      <v-col>
        <div class="px-2">
          <v-btn
            block
            color="primary"
            data-test="pluginUpload"
            :disabled="files.length < 1"
            :loading="loadingPlugin"
            @click="upload()"
          >
            Upload
            <v-icon right dark>mdi-cloud-upload</v-icon>
            <template v-slot:loader>
              <span>Loading...</span>
            </template>
          </v-btn>
        </div>
      </v-col>
      <v-col cols="9">
        <div class="px-4">
          <v-file-input
            multiple
            show-size
            v-model="files"
            ref="fileInput"
            accept=".gem"
            label="Click to select plugin .gem file(s)"
          />
        </div>
      </v-col>
    </v-row>
    <!-- TODO This alert shows both success and failure. Make consistent with rest of COSMOS. -->
    <v-alert
      dismissible
      transition="scale-transition"
      :type="alertType"
      v-model="showAlert"
      v-text="alert"
    />
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
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import DownloadDialog from '@/tools/CosmosAdmin/DownloadDialog'
import EditDialog from '@/tools/CosmosAdmin/EditDialog'
import VariablesDialog from '@/tools/CosmosAdmin/VariablesDialog'

export default {
  components: {
    DownloadDialog,
    EditDialog,
    VariablesDialog,
  },
  data() {
    return {
      files: [],
      loadingPlugin: false,
      plugins: [],
      alert: '',
      alertType: 'success',
      showAlert: false,
      variables: [],
      jsonContent: '',
      dialogTitle: '',
      showDownloadDialog: false,
      showEditDialog: false,
      showVariableDialog: false,
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update: function () {
      Api.get('/cosmos-api/plugins').then((response) => {
        this.plugins = response.data
      })
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
          this.alert = `Installed ${responses.length} plugin${
            responses.length > 1 ? 's' : ''
          }`
          this.alertType = 'success'
          this.showAlert = true
          this.files = []
          this.variables = []
          setTimeout(() => {
            this.showAlert = false
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
