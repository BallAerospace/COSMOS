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
    <v-row no-gutters align="center">
      <v-col cols="4">
        <v-file-input
          v-model="file"
          show-size
          label="Click to Select Plugin .gem File"
        ></v-file-input>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="upload()">
          Upload
          <v-icon right dark>mdi-cloud-upload</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-list data-test="pluginList">
      <v-list-item v-for="(plugin, i) in plugins" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="plugin"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="deletePlugin(plugin)" v-bind="attrs" v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Item</span>
          </v-tooltip>
        </v-list-item-icon>
      </v-list-item>
    </v-list>
    <v-alert
      :type="alertType"
      v-model="showAlert"
      dismissible
      transition="scale-transition"
      >{{ alert }}</v-alert
    >
    <VariablesDialog
      :variables="variables"
      v-model="showVariables"
      v-if="showVariables"
      @submit="variablesCallback"
    />
  </div>
</template>

<script>
import axios from 'axios'
import VariablesDialog from '@/tools/CosmosAdmin/VariablesDialog'
export default {
  components: { VariablesDialog },
  data() {
    return {
      file: null,
      plugins: [],
      alert: '',
      alertType: 'success',
      showAlert: false,
      pluginId: null,
      variables: {},
      showVariables: false,
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update() {
      axios
        .get('/cosmos-api/plugins', {
          params: { scope: 'DEFAULT', token: localStorage.getItem('token') },
        })
        .then((response) => {
          //console.log(response.data)
          this.plugins = response.data
        })
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
        })
    },
    upload() {
      if (this.file !== null) {
        let formData = new FormData()
        formData.append('plugin', this.file, this.file.name)
        formData.append('scope', 'DEFAULT')
        formData.append('token', localStorage.getItem('token'))
        axios
          .post('/cosmos-api/plugins', formData)
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
          })
          .catch((error) => {
            this.alert = error
            this.alertType = 'error'
            this.showAlert = true
            setTimeout(() => {
              this.showAlert = false
            }, 5000)
          })
      } else {
        this.alert = 'Please Select A Plugin File'
        this.alertType = 'warning'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      }
    },
    variablesCallback(updated_variables) {
      this.showVariables = false
      let formData = new FormData()
      formData.append('variables', JSON.stringify(updated_variables))
      formData.append('scope', 'DEFAULT')
      formData.append('token', localStorage.getItem('token'))
      axios
        .post('/cosmos-api/plugins/install/' + this.pluginId, formData)
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
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
        })
    },
    deletePlugin(plugin) {
      var self = this
      this.$dialog
        .confirm('Are you sure you want to remove: ' + plugin, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          axios
            .delete('/cosmos-api/plugins/' + plugin, {
              params: {
                scope: 'DEFAULT',
                token: localStorage.getItem('token'),
              },
            })
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
              setTimeout(() => {
                self.showAlert = false
              }, 5000)
            })
        })
    },
  },
}
</script>
