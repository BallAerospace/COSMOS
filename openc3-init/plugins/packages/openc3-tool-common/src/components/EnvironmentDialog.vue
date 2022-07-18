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
  <v-dialog v-model="show" width="600">
    <v-card>
      <form v-on:submit.prevent="addEnvironment">
        <v-system-bar>
          <v-spacer />
          <span>Environment Variables</span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <div class="pa-3">
            <v-row dense class="mb-2">
              <v-text-field
                v-model="search"
                label="search"
                type="text"
                data-test="search"
                prepend-icon="mdi-magnify"
                clear-icon="mdi-close-circle-outline"
                clearable
                autofocus
                single-line
                hide-details
              />
            </v-row>
            <v-data-table
              item-key="name"
              hide-default-header
              data-test="env-table"
              :search="search"
              :headers="headers"
              :items="environment"
              :items-per-page="5"
              :footer-props="{ 'items-per-page-options': [5] }"
            >
              <template v-slot:item.actions="{ item }">
                <v-btn
                  @click="deleteEnvironment(item)"
                  icon
                  class="mt-1"
                  data-test="item-delete"
                >
                  <v-icon>mdi-delete</v-icon>
                </v-btn>
              </template>
            </v-data-table>
            <v-row dense>
              <v-col>
                <v-text-field v-model="key" label="Key" data-test="env-key" />
              </v-col>
              <v-col>
                <v-text-field v-model="keyValue" label="Value" data-test="env-value" />
              </v-col>
            </v-row>
            <v-row dense>
              <v-btn
                @click.prevent="addEnvironment"
                block
                type="submit"
                color="primary"
                data-test="add-env"
                :disabled="!key || !keyValue"
              >
                Add
              </v-btn>
            </v-row>
          </div>
        </v-card-text>
      </form>
    </v-card>
  </v-dialog>
</template>

<script>
import Api from '../services/api'

export default {
  props: {
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      alert: '',
      alertType: 'success',
      showAlert: false,
      search: '',
      key: '',
      keyValue: '',
      environment: [],
      headers: [
        {
          text: 'Key',
          value: 'key',
        },
        {
          text: 'Value',
          value: 'value',
        },
        {
          text: 'Actions',
          value: 'actions',
          align: 'end',
          sortable: false,
        },
      ],
    }
  },
  computed: {
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  mounted() {
    this.update()
  },
  methods: {
    alertHandler: function (event) {
      // console.log('alertHandler', event)
      this.alert = event.text
      this.alertType = event.type
      this.showAlert = true
    },
    update: function () {
      Api.get('/openc3-api/environment')
        .then((response) => {
          this.environment = response.data
        })
        .catch((error) => {
          // TODO: $error.something
        })
    },
    addEnvironment: function () {
      Api.post('/openc3-api/environment', {
        data: {
          key: this.key.toUpperCase(),
          value: this.keyValue,
        },
      })
        .then((response) => {
          const alertEvent = {
            text: `New environment variable: ${response.data.name}`,
            type: 'success',
          }
          this.update()
        })
        .catch((error) => {
          const alertEvent = {
            text: `Failed to add environment variable: ${error}`,
            type: 'error',
          }
          this.alertHandler(alertEvent)
        })
      this.key = ''
      this.keyValue = ''
    },
    deleteEnvironment: function (env) {
      this.$dialog
        .confirm(`Are you sure you want to delete: ${env.key}=${env.value}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          return Api.delete(`/openc3-api/environment/${env.name}`)
        })
        .then((response) => {
          const alertEvent = {
            text: `Removed environment variable: ${env.name}`,
            type: 'success',
          }
          this.alertHandler(alertEvent)
          this.update()
        })
        .catch((error) => {
          const alertEvent = {
            text: `Failed to delete environment: ${error}`,
            type: 'error',
          }
          this.alertHandler(alertEvent)
        })
    },
  },
}
</script>
