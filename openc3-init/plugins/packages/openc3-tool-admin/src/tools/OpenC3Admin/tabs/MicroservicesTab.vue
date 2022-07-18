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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
-->

<template>
  <div>
    <v-list data-test="microserviceList">
      <div v-for="(microservice, index) in microservices" :key="microservice">
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title>{{ microservice }}</v-list-item-title>
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
                  @click="showMicroservice(microservice)"
                  v-bind="attrs"
                  v-on="on"
                >
                  mdi-eye
                </v-icon>
              </template>
              <span>Edit Microservice</span>
            </v-tooltip>
          </v-list-item-icon>
        </v-list-item>
        <v-divider v-if="index < microservices.length - 1" :key="index" />
      </div>
    </v-list>
    <edit-dialog
      v-model="showDialog"
      v-if="showDialog"
      :content="jsonContent"
      :title="`Microservice: ${dialogTitle}`"
      readonly
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
import Api from '@openc3/tool-common/src/services/api'
import EditDialog from '@/tools/OpenC3Admin/EditDialog'
import TextBoxDialog from '@openc3/tool-common/src/components/TextBoxDialog'

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
      Api.get('/openc3-api/microservice_status/all').then((response) => {
        this.microservice_status = response.data
      })
      Api.get('/openc3-api/microservices').then((response) => {
        this.microservices = response.data
      })
    },
    showMicroservice: function (name) {
      Api.get(`/openc3-api/microservices/${name}`).then((response) => {
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
        let url = `/openc3-api/microservices/${this.microservice_id}`
        if (parsed['name'] !== this.microservice_id) {
          method = 'post'
          url = '/openc3-api/microservices'
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
  },
}
</script>
