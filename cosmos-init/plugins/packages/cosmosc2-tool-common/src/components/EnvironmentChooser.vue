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
    <v-row no-gutters>
      <span> Select from Cosmos environment variables </span>
    </v-row>
    <v-row>
      <v-autocomplete
        v-model="selected"
        cache-items
        flat
        multiple
        hide-no-data
        hide-details
        solo-inverted
        class="mx-4"
        label="Environment Options"
        data-test="environment-autocomplete"
        :loading="loading"
        :items="environment"
      />
    </v-row>
    <v-row>
      <v-col>
        <v-text-field
          v-model="key"
          label="Key"
          data-test="tmp-environment-key-input"
        />
      </v-col>
      <v-col>
        <v-text-field
          v-model="keyValue"
          label="Value"
          data-test="tmp-environment-value-input"
        />
      </v-col>
    </v-row>
    <v-row class="mx-1 mb-2 mt-0">
      <v-btn
        block
        color="primary"
        data-test="add-temp-environment"
        @click="addTempEnv()"
        :disabled="!key || !keyValue"
      >
        Add a temporary environment variable
      </v-btn>
    </v-row>
  </div>
</template>

<script>
import Api from '../services/api'

export default {
  props: {
    value: Array, // value is the default prop when using v-model
  },
  data() {
    return {
      key: '',
      keyValue: '',
      selected: [],
      loading: false,
      environment: [],
      error: null,
    }
  },
  mounted() {
    this.loading = true
    Api.get('/cosmos-api/environment')
      .then((response) => {
        this.environment = response.data.map(
          (env) => `${env.key.toUpperCase()}=${env.value}`
        )
      })
      .catch((error) => {
        this.error = error
      })
    if (this.value) {
      this.selected = this.value
      this.environment = this.value
    }
    this.loading = false
  },
  watch: {
    selected(newVal, oldVal) {
      if (newVal !== oldVal) {
        this.$emit('selected', newVal)
      }
    },
  },
  methods: {
    addTempEnv: function () {
      const env = `${this.key.toUpperCase()}=${this.keyValue}`
      this.environment.push(env)
      this.selected.push(env)
      this.$emit('selected', this.selected)
      this.key = ''
      this.keyValue = ''
    },
  },
}
</script>
