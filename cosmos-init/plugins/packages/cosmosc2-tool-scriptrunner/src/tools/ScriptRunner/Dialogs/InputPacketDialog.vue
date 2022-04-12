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
        <span> Input Telemetry </span>
        <v-spacer />
      </v-system-bar>
      <div class="pa-2">
        <v-card-text>
          <v-row>
            <v-card-title> {{ target }} {{ packet }} </v-card-title>
          </v-row>
          <v-row v-show="description">
            <v-col>
              <span v-text="description" class="mb-2" />
            <v-col>
          </v-row>
          <v-simple-table dense>
            <tbody>
              <template v-for="(item, i) in telemetry">
                <tr :key="`tr-${i}`">
                  <td>
                    <v-text-field
                      v-model="item.key"
                      type="text"
                      dense
                      readonly
                      :data-test="`key-${i}`"
                    />
                  </td>
                  <td>
                    <v-text-field
                      v-model="item.value"
                      clearable
                      dense
                      :type="item.type"
                      :data-test="`value-${i}`"
                    />
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
          data-test="telemetry-dialog-cancel"
        >
          Cancel
        </v-btn>
        <v-btn
          @click="inputPacket"
          class="mx-2"
          color="primary"
          data-test="telemetry-dialog-save"
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
    packet: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      api: null,
      description: null,
      items: {},
      telemetry: [],
      lastUpdated: null,
    }
  },
  mounted: function () {
    this.api = new CosmosApi()
    this.getPacket()
  },
  computed: {
    inputError: function () {
      if (this.telemetry.length < 1) {
        return 'Packet must contain items.'
      }
      const emptyKeyValue = this.telemetry.find(
        (item) => item.key === '' || item.value === ''
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
  watch: {
    items: {
      immediate: true,
      handler: function () {
        this.getTelemetry()
      },
    },
  },
  methods: {
    inputPacket: function () {
      const item_hash = this.telemetry.reduce((result, element) => {
        result[element.key] = element.value
        return result
      }, {})
      this.api.inject_tlm(this.target, this.packet, item_hash).then((result) => {
        // console.log({ result })
        this.show = !this.show
      })
    },
    cancel: function () {
      this.show = !this.show
    },
    getPacket: function () {
      this.api.get_tlm_packet(this.target, this.packet).then((result) => {
        this.items = result.reduce((items, element) => {
          items[element[0]] = element[1]
          return items
        }, {})
      })
    },
    getTelemetry: function () {
      this.api.get_telemetry(this.target, this.packet).then((result) => {
        this.description = result.description
        this.telemetry = result.items
          .filter((item) => {
            return item.data_type !== 'DERIVED'
          })
          .map((item) => {
            return {
              key: item.name,
              value: this.items[item.name],
              type: this.getItemType(item.name),
            }
          })
      })
    },
    getItemType: function (itemName) {
      const value = this.items[itemName]
      const string = typeof value === 'string' || value instanceof String
      return string ? 'text' : 'number'
    },
  },
}
</script>
