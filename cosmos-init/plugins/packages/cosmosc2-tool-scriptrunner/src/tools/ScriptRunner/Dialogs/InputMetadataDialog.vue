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
  <v-dialog v-model="show" width="600">
    <v-card>
      <v-system-bar>
        <v-spacer />
        <span>Input Metadata</span>
        <v-spacer />
      </v-system-bar>
      <div class="pa-2">
        <v-card-text>
          <v-simple-table dense>
            <tbody>
              <tr>
                <th class="text-left">Key</th>
                <th class="text-left">Value</th>
                <th class="text-right">
                  <v-tooltip top>
                    <template v-slot:activator="{ on, attrs }">
                      <div v-on="on" v-bind="attrs">
                        <v-icon
                          data-test="new-metadata-icon"
                          @click="newMetadata"
                        >
                          mdi-plus
                        </v-icon>
                      </div>
                    </template>
                    <span> New Metadata </span>
                  </v-tooltip>
                </th>
              </tr>
              <template v-for="(meta, i) in metadata">
                <tr :key="`tr-${i}`">
                  <td>
                    <v-text-field
                      v-model="meta.key"
                      type="text"
                      dense
                      :data-test="`key-${i}`"
                    />
                  </td>
                  <td>
                    <v-text-field
                      v-model="meta.value"
                      type="text"
                      dense
                      :data-test="`value-${i}`"
                    />
                  </td>
                  <td>
                    <v-tooltip top>
                      <template v-slot:activator="{ on, attrs }">
                        <div v-on="on" v-bind="attrs">
                          <v-icon
                            data-test="delete-metadata-icon"
                            @click="rm(i)"
                          >
                            mdi-delete
                          </v-icon>
                        </div>
                      </template>
                      <span> Delete Metadata </span>
                    </v-tooltip>
                  </td>
                </tr>
              </template>
            </tbody>
          </v-simple-table>
          <v-row v-show="lastUpdated">
            <v-col>
              <span class="pt-3"> Last update: {{ lastUpdated }} </span>
            </v-col>
          </v-row>
          <v-row>
            <v-col>
              <span class="red--text" v-show="inputError" v-text="inputError" />
            </v-col>
          </v-row>
        </v-card-text>
      </div>
      <v-card-actions>
        <v-spacer />
        <v-btn
          @click="cancel"
          class="mx-2"
          outlined
          data-test="metadata-dialog-cancel"
        >
          Cancel
        </v-btn>
        <v-btn
          @click="updateMetadata"
          class="mx-2"
          color="primary"
          data-test="metadata-dialog-save"
          :disabled="!!inputError"
        >
          Update
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'

export default {
  components: {},
  props: {
    value: {
      type: Boolean,
      required: true,
    },
    target: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      lastUpdated: null,
      metadata: [],
    }
  },
  mounted: function () {
    this.getMetadata()
  },
  computed: {
    inputError: function () {
      if (this.metadata.length < 1) {
        return 'Please enter a value in the metadata table.'
      }
      const emptyKeyValue = this.metadata.find(
        (meta) => meta.key === '' || meta.value === ''
      )
      if (emptyKeyValue) {
        return 'Missing or empty key, value in the metadata table.'
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
  methods: {
    updateMetadata: function () {
      const metadata = this.metadata.reduce((result, element) => {
        result[element.key] = element.value
        return result
      }, {})
      const target = this.target
      const color = '#003784'
      Api.post('/cosmos-api/metadata', {
        data: { color, target, metadata },
      }).then((response) => {
        this.$emit('response', metadata)
      })
    },
    cancel: function () {
      this.show = !this.show
    },
    getMetadata: function () {
      Api.get(`/cosmos-api/metadata/_get/${this.target}`).then((response) => {
        if (response.status !== 200) {
          this.lastUpdated = null
          this.metadata = []
        } else {
          this.lastUpdated = new Date(response.data.updated_at / 1000000)
          this.updateValues(response.data.metadata)
        }
      })
    },
    updateValues: function (metaValues) {
      const targetMetadata = Object.keys(metaValues).map((k) => {
        return { key: k, value: metaValues[k] }
      })
      this.metadata = targetMetadata
    },
    newMetadata: function () {
      this.metadata.push({
        key: '',
        value: '',
      })
    },
    rm: function (index) {
      this.metadata.splice(index, 1)
    },
  },
}
</script>
