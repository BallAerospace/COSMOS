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
  <v-dialog v-model="show" @keydown.esc="cancel" width="600">
    <v-card>
      <form v-on:submit.prevent="success">
        <v-system-bar>
          <v-spacer />
          <span>Open Configuration</span>
          <v-spacer />
        </v-system-bar>

        <v-card-text>
          <div class="pa-3">
            <v-row dense>
              <v-text-field
                label="search"
                v-model="search"
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
              show-select
              single-select
              item-key="configId"
              :search="search"
              :headers="headers"
              :items="configs"
              :items-per-page="5"
              :footer-props="{ 'items-per-page-options': [5] }"
              @item-selected="itemSelected"
              @click:row="(item, slot) => slot.select(item)"
            >
              <template v-slot:item.actions="{ item }">
                <v-btn
                  class="mt-1"
                  data-test="item-delete"
                  icon
                  @click="deleteConfig(item)"
                >
                  <v-icon>mdi-delete</v-icon>
                </v-btn>
              </template>
            </v-data-table>
            <v-row dense>
              <span class="ma-2 red--text" v-show="error" v-text="error" />
            </v-row>
            <v-row>
              <v-btn
                @click.prevent="success"
                type="submit"
                color="success"
                data-test="open-config-submit-btn"
                :disabled="!!error"
              >
                Ok
              </v-btn>
              <v-spacer />
              <v-btn
                @click="cancel"
                color="primary"
                data-test="open-config-cancel-btn"
              >
                Cancel
              </v-btn>
            </v-row>
          </div>
        </v-card-text>
      </form>
    </v-card>
  </v-dialog>
</template>

<script>
import { OpenC3Api } from '../services/openc3-api.js'

export default {
  props: {
    tool: String,
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      configs: [],
      headers: [
        {
          text: 'Configuration',
          value: 'config',
        },
        {
          text: 'Actions',
          value: 'actions',
          align: 'end',
          sortable: false,
        },
      ],
      search: null,
      selectedItem: null,
    }
  },
  computed: {
    error: function () {
      if (this.selectedItem === '' || this.selectedItem === null) {
        return 'Must select a config'
      }
      return null
    },
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
    let configId = -1
    new OpenC3Api()
      .list_configs(this.tool)
      .then((response) => {
        this.configs = response.map((config) => {
          configId += 1
          return { configId, config }
        })
      })
      .catch((error) => {
        this.$emit('warning', `Failed to connect to OpenC3. ${error}`)
      })
  },
  methods: {
    itemSelected: function (item) {
      if (item.value) {
        this.selectedItem = item.item
      } else {
        this.selectedItem = null
      }
    },
    success: function () {
      this.$emit('success', this.selectedItem.config)
      this.show = false
      this.search = null
      this.selectedItem = null
    },
    cancel: function () {
      this.show = false
      this.search = null
      this.selectedItem = null
    },
    deleteConfig: function (item) {
      this.$dialog
        .confirm(`Are you sure you want to delete: ${item.config}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          if (this.selectedItem.config === item.config) {
            this.selectedItem = null
          }
          this.configs.splice(this.configs.indexOf(item), 1)
          new OpenC3Api().delete_config(this.tool, item.config)
        })
        .catch((error) => {
          if (error) {
            this.$emit(
              'warning',
              `Failed to delete config ${item.config} Error: ${error}`
            )
          }
        })
    },
  },
}
</script>

<style scoped></style>
