<!--
# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addstopums as found in the LICENSE.txt
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
    <v-dialog v-model="show" width="800">
      <v-card class="pa-3">
        <v-toolbar>
          <v-toolbar-title>Screens</v-toolbar-title>
          <v-spacer />
          <v-text-field
            class="pa-2"
            label="search"
            v-model="search"
            type="text"
            data-test="search"
            prepend-icon="mdi-magnify"
            clear-icon="mdi-close-circle-outline"
            clearable
            single-line
            hide-details
          />
        </v-toolbar>
        <v-card-text class="mt-2">
          <v-row dense>
            <v-select
              label="Select Target"
              hide-details
              dense
              @change="targetNameChanged"
              :items="targetNames"
              item-text="label"
              item-value="value"
              v-model="selectedTargetName"
              data-test="select-target"
            />
          </v-row>
          <v-row dense>
            <v-data-table
              single-expand
              show-expand
              item-key="name"
              class="elevation-1"
              :expanded.sync="expanded"
              :headers="screenHeaders"
              :items="screens"
              :search="search"
              :items-per-page="5"
              :footer-props="{
                'items-per-page-options': [5],
              }"
            >
              <template v-slot:item.actions="{ item }">
                <v-tooltip top>
                  <template v-slot:activator="{ on, attrs }">
                    <div v-on="on" v-bind="attrs">
                      <v-btn
                        icon
                        data-test="deleteScreenIcon"
                        @click="() => deleteScreen(item)"
                      >
                        <v-icon> mdi-delete </v-icon>
                      </v-btn>
                    </div>
                  </template>
                  <span> Delete Screen </span>
                </v-tooltip>
              </template>
              <template v-slot:expanded-item="{ headers, item }">
                <td :colspan="headers.length">
                  <v-textarea
                    readonly
                    rows="8"
                    :value="item"
                  />
                </td>
              </template>
              <template v-slot:no-data>
                <span>Currently no screens found for this Target</span>
              </template>
            </v-data-table>
          </v-row>
          <v-row>
            <span class="ma-2 red--text" v-show="text" v-text="text" />
          </v-row>
        </v-card-text>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'

export default {
  props: {
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      rules: {
        required: (value) => !!value || 'Required',
      },
      ScreenHeaders: [
        { text: 'Name', align: 'start', value: 'name' },
        { text: 'Type', value: 'type' },
        { text: 'Actions', value: 'actions', sortable: false },
        { text: '', value: 'data-table-expand', sortable: false },
      ],
      targetNames: [],
      selectedTargetName: '',
      screens: [],
      search: null,
      expanded: [],
      text: null,
    }
  },
  created: function () {
    const api = new CosmosApi()
    api.get_target_list({ params: { scope: localStorage.scope } })
      .then((data) => {
        for (let target of data) {
          this.targets.push({ label: target, value: target })
        }
        if (!this.selectedTarget) {
          this.selectedTarget = this.targets[0].value
        }
        this.updateScreens()
      }).catch((error) => {
        if (error) {
          const alertObject = {
            text: `Failed to get targets. Error: ${error}`,
            type: 'error',
          }
          this.$emit('alert', alertObject)
        }
      })
  },
  computed: {
    error: function () {
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
    listData: function () {
      if (!this.screens) return []
      let screenId = 0
      return this.screen.map((screen) => {
        screenId += 1
        return {
          ...screen,
          screenId,
        }
      })
    },
  },
  methods: {
    updateScreens() {
      this.screens = []
      Api.get('/cosmos-api/screen/' + this.selectedTargetName).then((response) => {
        for (let screen of response.data) {
          this.screens.push(screen)
        }
      })
    },
    deleteScreen: function (screen) {
      // console.log(Screen)
      this.$dialog
        .confirm(`Remove ${screen.name}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          const updateObject = {
            screenName: screen.name,
            screenType: screen.type,
            type: 'delete',
          }
          this.$emit('update', updateObject)
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to delete screen ${screen.name} Error: ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
    },
  },
}
</script>

<style scoped>
</style>
