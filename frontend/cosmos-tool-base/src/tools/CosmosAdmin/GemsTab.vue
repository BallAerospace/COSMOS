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
          label="Click to Select .gem file to add to internal gem server"
        ></v-file-input>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="upload()">
          Upload
          <v-icon right dark>mdi-cloud-upload</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-list data-test="gemList">
      <v-list-item v-for="(gem, i) in gems" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="gem"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="deleteGem(gem)" v-bind="attrs" v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Gem</span>
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
  </div>
</template>

<script>
import Api from '@/services/api'
export default {
  components: {},
  data() {
    return {
      file: null,
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
      if (this.file !== null) {
        let formData = new FormData()
        formData.append('gem', this.file, this.file.name)
        Api.post('/cosmos-api/gems', formData)
          .then((response) => {
            this.alert = 'Uploaded gem ' + this.file.name
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
      } else {
        this.alert = 'Please Select A Gem File'
        this.alertType = 'warning'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      }
    },
    deleteGem(gem) {
      var self = this
      this.$dialog
        .confirm('Are you sure you want to remove: ' + gem, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          Api.delete('/cosmos-api/gems/' + gem)
            .then((response) => {
              self.alert = 'Removed gem ' + gem
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
