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
    <v-row no-gutters align="center" style="padding-left: 10px">
      <v-col cols="3">
        <v-btn
          block
          color="primary"
          data-test="pluginUpload"
          :disabled="!file"
          :loading="loading"
          @click="upload()"
        >
          Upload
          <v-icon right dark>mdi-cloud-upload</v-icon>
        </v-btn>
      </v-col>
      <v-col cols="9">
        <div class="px-4">
          <v-file-input
            show-size
            v-model="file"
            ref="fileInput"
            accept=".gem"
            label="Click to Select Plugin .gem File"
          />
        </div>
      </v-col>
    </v-row>
    <!-- TODO This alert shows both success and failure. Make consistent with rest of COSMOS. -->
    <v-alert
      :type="alertType"
      v-model="showAlert"
      dismissible
      transition="scale-transition"
    >
      {{ alert }}
    </v-alert>
    <v-list data-test="pluginList">
      <v-list-item v-for="(plugin, i) in plugins" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="plugin" />
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="showPlugin(plugin)" v-bind="attrs" v-on="on">
                mdi-eye
              </v-icon>
            </template>
            <span>Show Plugin Details</span>
          </v-tooltip>
        </v-list-item-icon>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="upgradePlugin(plugin)" v-bind="attrs" v-on="on">
                mdi-update
              </v-icon>
            </template>
            <span>Upgrade Plugin</span>
          </v-tooltip>
        </v-list-item-icon>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="deletePlugin(plugin)" v-bind="attrs" v-on="on">
                mdi-delete
              </v-icon>
            </template>
            <span>Delete Plugin</span>
          </v-tooltip>
        </v-list-item-icon>
      </v-list-item>
    </v-list>
    <v-alert
      dismissible
      transition="scale-transition"
      :type="alertType"
      v-model="showAlert"
      v-text="alert"
    />
    <variables-dialog
      :variables="variables"
      v-model="showVariables"
      v-if="showVariables"
      @submit="variablesCallback"
    />
    <edit-dialog
      title="Plugin Details"
      :content="json_content"
      :readonly="true"
      v-model="showDialog"
      v-if="showDialog"
      @submit="dialogCallback"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import VariablesDialog from '@/tools/CosmosAdmin/VariablesDialog'
import EditDialog from '@/tools/CosmosAdmin/EditDialog'

export default {
  components: {
    VariablesDialog,
    EditDialog
  },
  data() {
    return {
      file: null,
      loading: false,
      plugins: [],
      alert: '',
      alertType: 'success',
      showAlert: false,
      pluginId: null,
      variables: {},
      showVariables: false,
      json_content: '',
      showDialog: false,
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update() {
      Api.get('/cosmos-api/plugins')
        .then((response) => {
          //console.log(response.data)
          this.plugins = response.data
        })
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
        })
    },
    upload(existing = null) {
      const method = (existing) ? 'put' : 'post'
      const path = (existing) ? `/cosmos-api/plugins/${existing}` : '/cosmos-api/plugins'
      this.loading = true
      let formData = new FormData()
      formData.append('plugin', this.file, this.file.name)
      Api[method](path, { data: formData })
        .then((response) => {
          this.alert = 'Uploaded file ' + this.file.name
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
          //console.log(response.data.variables)
          this.pluginId = this.file.name
          this.variables = response.data.variables
          this.showVariables = true
          this.file = null
        })
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
        })
      this.loading = false
    },
    variablesCallback(updated_variables) {
      this.showVariables = false
      Api.post('/cosmos-api/plugins/install/' + this.pluginId, {
        data: {
          variables: JSON.stringify(updated_variables),
        },
      })
        .then((response) => {
          this.alert = 'Installed plugin ' + this.file.name
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
        })
    },
    showPlugin(name) {
      var self = this
      Api.get('/cosmos-api/plugins/' + name)
        .then((response) => {
          self.json_content = JSON.stringify(response.data, null, 1)
          self.showDialog = true
        })
        .catch((error) => {
          self.alert = error
          self.alertType = 'error'
          self.showAlert = true
          setTimeout(() => {
            self.showAlert = false
          }, 5000)
        })
    },
    dialogCallback(content) {
      this.showDialog = false
    },
    async upgradePlugin(plugin) {
      this.file = null
      this.$refs.fileInput.$refs.input.click()
      // Wait for the file to be set by the dialog so upload works
      while (this.file === null) {
        await new Promise((resolve) => setTimeout(resolve, 500))
      }
      this.upload(plugin)
    },
    deletePlugin(plugin) {
      var self = this
      this.$dialog
        .confirm('Are you sure you want to remove: ' + plugin, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          Api.delete('/cosmos-api/plugins/' + plugin)
            .then((response) => {
              self.alert = 'Removed plugin ' + plugin
              self.alertType = 'success'
              self.showAlert = true
              setTimeout(() => {
                self.showAlert = false
              }, 5000)
              self.update()
            })
            .catch((error) => {
              self.alert = error
              self.alertType = 'error'
              self.showAlert = true
            })
        })
    },
  },
}
</script>
