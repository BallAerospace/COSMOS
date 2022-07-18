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
      <span> Select OpenC3 script </span>
    </v-row>
    <v-row class="my-2">
      <v-autocomplete
        v-model="selected"
        cache-items
        flat
        hide-no-data
        hide-details
        solo-inverted
        class="mx-4"
        label="Select a script"
        :loading="loading"
        :items="items"
        :search-input.sync="search"
      />
    </v-row>
  </div>
</template>

<script>
import Api from '../services/api'

export default {
  props: {
    value: String, // value is the default prop when using v-model
  },
  data() {
    return {
      loading: false,
      search: '',
      selected: this.value,
      scripts: [],
      items: [],
    }
  },
  created() {
    this.loading = true
    Api.get('/script-api/scripts')
      .then((response) => {
        this.scripts = response.data
        this.items = response.data
      })
      .catch((error) => {
        this.$emit('error', {
          type: 'error',
          text: `Failed to connect to OpenC3. ${error}`,
          error: error,
        })
      })
    this.selected = this.value ? this.value : null
    this.loading = false
  },
  watch: {
    selected(newVal, oldVal) {
      if (newVal !== oldVal) {
        this.$emit('file', newVal)
      }
    },
    search(val) {
      val && val !== this.selected && this.querySelections(val)
    },
  },
  methods: {
    querySelections: function (v) {
      this.loading = true
      // Simulated ajax query
      setTimeout(() => {
        this.items = this.scripts.filter((e) => {
          return (e || '').toLowerCase().indexOf((v || '').toLowerCase()) > -1
        })
        this.loading = false
      }, 500)
    },
  },
}
</script>
