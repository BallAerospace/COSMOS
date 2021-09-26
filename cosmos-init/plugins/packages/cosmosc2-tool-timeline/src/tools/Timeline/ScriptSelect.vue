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
  <v-container class="mt-1 pa-0">
    <v-row>
      <v-text-field
        class="pa-2"
        label="search"
        v-model="search"
        type="text"
        data-test="search"
        append-icon="mdi-magnify"
        clear-icon="mdi-close-circle-outline"
        clearable
        single-line
        hide-details
      />
    </v-row>
    <v-row dense>
      <v-data-table
        show-select
        single-select
        hide-default-header
        item-key="scriptId"
        :search="search"
        :headers="headers"
        :items="items"
        :items-per-page="5"
        @item-selected="itemSelected"
      />
    </v-row>
  </v-container>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'

export default {
  data() {
    return {
      items: [],
      headers: [
        {
          text: 'Script',
          value: 'script',
        },
      ],
      search: null,
      selectedItem: null,
    }
  },
  watch: {
    'selected.length': function (val) {
      if (val === 0) {
        this.selectedItem = null
      }
    },
    selectedItem: function (val) {
      this.$emit('file', val)
    },
  },
  created() {
    let scriptId = -1
    Api.get('/script-api/scripts')
      .then((response) => {
        this.items = response.data.map((script) => {
          scriptId += 1
          return { scriptId, script }
        })
      })
      .catch((error) => {
        this.$emit('warning', `Failed to connect to Cosmos. ${error}`)
      })
  },
  methods: {
    itemSelected: function (itemData) {
      // console.log('itemData', itemData)
      if (itemData.value) {
        //this.$emit('file', itemData.item)
        this.selectedItem = itemData.item
      }
    },
  },
}
</script>
