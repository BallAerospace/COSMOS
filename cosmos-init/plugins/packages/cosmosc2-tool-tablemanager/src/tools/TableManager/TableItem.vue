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
  <v-select v-if="dataItem.states" v-model="stateValue" :items="itemStates" />
  <v-text-field
    v-else
    solo
    dense
    single-line
    hide-no-data
    hide-details
    v-model="dataItem.value"
  />
</template>

<script>
export default {
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      dataItem: this.item,
      stateValue: null,
    }
  },
  created() {
    if (this.dataItem.states) {
      this.stateValue = this.dataItem.states[this.dataItem.value]
    }
  },
  computed: {
    itemStates: function () {
      let result = []
      for (const [text, value] of Object.entries(this.dataItem.states)) {
        result.push({ text: text, value: value })
      }
      return result
    },
  },
}
</script>
