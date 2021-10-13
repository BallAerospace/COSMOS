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
          data-test="gemUpload"
          :disabled="!files.length"
          :loading="loadingGem"
          @click="upload"
        >
          Upload
          <template v-slot:loader>
            <span>Loading...</span>
          </template>
          <v-icon right dark>mdi-cloud-upload</v-icon>
        </v-btn>
      </v-col>
      <v-col cols="9">
        <div class="px-4">
          <v-file-input
            multiple
            show-size
            v-model="files"
            ref="fileInput"
            accept=".gem"
            label="Click to select .gem file(s) to add to internal gem server"
          />
        </div>
      </v-col>
    </v-row>
    <v-alert
      dismissible
      v-model="showAlert"
      v-text="alert"
      :type="alertType"
      transition="scale-transition"
    />
    <v-list data-test="gemList">
      <div v-for="(gem, i) in gems" :key="i">
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title v-text="gem" />
          </v-list-item-content>
          <v-list-item-icon>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon @click="deleteGem(gem)" v-bind="attrs" v-on="on">
                  mdi-delete
                </v-icon>
              </template>
              <span>Delete Gem</span>
            </v-tooltip>
          </v-list-item-icon>
        </v-list-item>
        <v-divider />
      </div>
    </v-list>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
export default {
  data() {
    return {
      files: [],
      loadingGem: false,
      gems: [],
      alert: '',
      alertType: 'success',
      showAlert: false,
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update() {
      Api.get('/cosmos-api/gems')
        .then((response) => {
          this.gems = response.data
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
      this.loadingGem = true
      const promises = this.files.map((file) => {
        const formData = new FormData()
        formData.append('gem', file, file.name)
        return Api.post('/cosmos-api/gems', { data: formData })
      })
      Promise.all(promises)
        .then((responses) => {
          this.alert = `Uploaded ${responses.length} gem${
            responses.length > 1 ? 's' : ''
          }`
          this.alertType = 'success'
          this.showAlert = true
          this.loadingGem = false
          this.files = []
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
        .catch((error) => {
          this.loadingPlugin = false
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
        })
    },
    deleteGem(gem) {
      var self = this
      this.$dialog
        .confirm(`Are you sure you want to remove: ${gem}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          Api.delete(`/cosmos-api/gems/${gem}`)
            .then((response) => {
              self.alert = `Removed gem ${gem}`
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
