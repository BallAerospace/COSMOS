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
    <v-alert
      :type="alertType"
      v-model="showAlert"
      dismissible
      transition="scale-transition"
    >
      {{ alert }}
    </v-alert>
    <v-list data-test="microserviceList">
      <div v-for="(microservice, index) in microservices" :key="microservice">
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title v-text="microservice" />
            <v-list-item-subtitle v-if="microservice_status[microservice]">
              Updated: {{ microservice_status[microservice].updated_at }},
              State: {{ microservice_status[microservice].state }}, Count:
              {{ microservice_status[microservice].count }}
            </v-list-item-subtitle>
          </v-list-item-content>
          <div v-show="!!microservice_status[microservice].error">
            <v-list-item-icon>
              <v-tooltip bottom>
                <template v-slot:activator="{ on, attrs }">
                  <v-icon
                    @click="showMicroserviceError(microservice)"
                    v-bind="attrs"
                    v-on="on"
                  >
                    mdi-alert
                  </v-icon>
                </template>
                <span>View Error</span>
              </v-tooltip>
            </v-list-item-icon>
          </div>
          <v-list-item-icon>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon
                  @click="editMicroservice(microservice)"
                  v-bind="attrs"
                  v-on="on"
                >
                  mdi-pencil
                </v-icon>
              </template>
              <span>Edit Microservice</span>
            </v-tooltip>
          </v-list-item-icon>
          <v-list-item-icon>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon
                  @click="deleteMicroservice(microservice)"
                  v-bind="attrs"
                  v-on="on"
                >
                  mdi-delete
                </v-icon>
              </template>
              <span>Delete Microservice</span>
            </v-tooltip>
          </v-list-item-icon>
        </v-list-item>
        <v-divider v-if="index < microservices.length - 1" :key="index" />
      </div>
    </v-list>
    <v-alert
      dismissible
      v-model="showAlert"
      :type="alertType"
      transition="scale-transition"
    >
      {{ alert }}
    </v-alert>
    <edit-dialog
      v-model="showDialog"
      v-if="showDialog"
      :content="jsonContent"
      :title="`Microservice: ${dialogTitle}`"
      @submit="dialogCallback"
    />
    <text-box-dialog
      v-model="showError"
      v-if="showError"
      :text="jsonContent"
      :title="dialogTitle"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import EditDialog from '@/tools/CosmosAdmin/EditDialog'
import TextBoxDialog from '@cosmosc2/tool-common/src/components/TextBoxDialog'

export default {
  components: {
    EditDialog,
    TextBoxDialog,
  },
  data() {
    return {
      microservices: [],
      microservice_status: {},
      microservice_id: null,
      alert: '',
      alertType: 'success',
      showAlert: false,
      jsonContent: '',
      dialogTitle: '',
      showDialog: false,
      showError: false,
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update: function () {
      Api.get('/cosmos-api/microservice_status/all').then((response) => {
        this.microservice_status = response.data
      })
      Api.get('/cosmos-api/microservices').then((response) => {
        this.microservices = response.data
      })
    },
    editMicroservice: function (name) {
      Api.get(`/cosmos-api/microservices/${name}`).then((response) => {
        this.microservice_id = name
        this.dialogTitle = name
        this.jsonContent = JSON.stringify(response.data, null, '\t')
        this.showDialog = true
      })
    },
    showMicroserviceError: function (name) {
      this.dialogTitle = name
      const e = this.microservice_status[name].error
      this.jsonContent = JSON.stringify(e, null, '\t')
      this.showError = true
    },
    dialogCallback: function (content) {
      this.showDialog = false
      if (content !== null) {
        let parsed = JSON.parse(content)
        let method = 'put'
        let url = `/cosmos-api/microservices/${this.microservice_id}`
        if (parsed['name'] !== this.microservice_id) {
          method = 'post'
          url = '/cosmos-api/microservices'
        }

        Api[method](url, {
          data: {
            json: content,
          },
        }).then((response) => {
          this.alert = 'Modified Microservice'
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
      }
    },
    deleteMicroservice: function (name) {
      this.$dialog
        .confirm(`Are you sure you want to remove: ${name}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          return Api.delete(`/cosmos-api/microservices/${name}`)
        })
        .then((response) => {
          this.alert = `Removed microservice ${name}`
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
    },
  },
}
</script>
