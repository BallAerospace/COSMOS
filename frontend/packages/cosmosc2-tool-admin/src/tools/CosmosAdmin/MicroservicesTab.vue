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
    <v-list data-test="microserviceList">
      <v-list-item v-for="microservice in microservices" :key="microservice">
        <v-list-item-content>
          <v-list-item-title v-text="microservice"></v-list-item-title>
          <v-list-item-subtitle v-if="microservice_status[microservice]"
            >Updated: {{ microservice_status[microservice].updated_at }}, State:
            {{ microservice_status[microservice].state }}, Count:
            {{ microservice_status[microservice].count }}, Error:
            {{ microservice_status[microservice].error }}
          </v-list-item-subtitle>
        </v-list-item-content>
        <v-list-item-icon>
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon
                @click="deleteMicroservice(microservice)"
                v-bind="attrs"
                v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Microservice</span>
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
import Api from '@cosmosc2/tool-common/src/services/api'
export default {
  components: {},
  data() {
    return {
      microservices: [],
      microservice_status: {},
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
      Api.get('/cosmos-api/microservice_status/all')
        .then((response) => {
          this.microservice_status = response.data
          Api.get('/cosmos-api/microservices')
            .then((response) => {
              this.microservices = response.data
            })
            .catch((error) => {
              this.alert = error
              this.alertType = 'error'
              this.showAlert = true
              setTimeout(() => {
                this.showAlert = false
              }, 5000)
            })
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
    add() {},
    deleteMicroservice(name) {
      var self = this
      this.$dialog
        .confirm('Are you sure you want to remove: ' + name, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          Api.delete('/cosmos-api/microservices/' + name)
            .then((response) => {
              self.alert = 'Removed microservice ' + name
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
