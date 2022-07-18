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
    <v-row no-gutters>
      <span> Select from OpenC3 environment variables </span>
    </v-row>
    <v-row class="ma-0">
      <v-select
        v-model="deadSelect"
        @change="addEnvironmentItem"
        persistent-hint
        return-object
        label="Select Environment Options"
        hint="Inject Environment Variables"
        :items="environmentItems"
      >
        <template>
          <div>
            <span> Select Environment Options </span>
          </div>
        </template>
        <template v-slot:item="{ item }">
          <div>
            <span v-text="`${item.key}=${item.value}`" />
          </div>
        </template>
      </v-select>
    </v-row>
    <div class="mt-2" />
    <v-simple-table dense>
      <tbody>
        <tr>
          <th class="text-left">Key</th>
          <th class="text-left">Value</th>
          <th class="text-right">
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-icon data-test="new-metadata-icon" @click="newEnvironment">
                    mdi-plus
                  </v-icon>
                </div>
              </template>
              <span> Add Environment </span>
            </v-tooltip>
          </th>
        </tr>
        <template v-for="(env, i) in selected">
          <tr :key="`tr-${i}`">
            <td>
              <v-text-field
                v-model="env.key"
                dense
                type="text"
                :readonly="env.readonly"
                :data-test="`key-${i}`"
              />
            </td>
            <td>
              <v-text-field
                v-model="env.value"
                dense
                type="text"
                :readonly="env.readonly"
                :data-test="`value-${i}`"
              />
            </td>
            <td>
              <v-tooltip top>
                <template v-slot:activator="{ on, attrs }">
                  <div v-on="on" v-bind="attrs">
                    <v-icon :data-test="`remove-env-icon-${i}`" @click="rm(i)">
                      mdi-delete
                    </v-icon>
                  </div>
                </template>
                <span> Delete Environment </span>
              </v-tooltip>
            </td>
          </tr>
        </template>
      </tbody>
    </v-simple-table>
  </div>
</template>

<script>
import Api from '../services/api'

export default {
  props: {
    value: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      deadSelect: null,
      environmentOptions: [],
    }
  },
  mounted() {
    this.getEnvironment()
  },
  computed: {
    selected: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
    environmentItems: function () {
      return this.environmentOptions.filter(
        (env) => !this.selected.find((s) => s.key === env.key)
      )
    },
  },
  methods: {
    getEnvironment: function () {
      Api.get('/openc3-api/environment').then((response) => {
        this.environmentOptions = response.data
      })
    },
    addEnvironmentItem: function (event) {
      this.selected.push({
        key: event.key,
        value: event.value,
        readonly: true,
      })
      const envIndex = this.environmentOptions.findIndex(
        (env) => env.key === event.key && env.value === event.value
      )
      this.environmentOptions.splice(envIndex, envIndex >= 0 ? 1 : 0)
      this.deadSelect = null
    },
    newEnvironment: function () {
      this.selected.push({
        key: '',
        value: '',
        readonly: false,
      })
    },
    rm: function (index) {
      const env = this.selected.splice(index, 1)[0]
      if (env && env.readonly) {
        this.environmentOptions.push(env)
      }
    },
  },
}
</script>
