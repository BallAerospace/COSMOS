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
  <tr>
    <td class="text-start">{{ dataItems[0].index }}</td>
    <td class="text-start" v-if="oneDimensional">{{ dataItems[0].name }}</td>
    <table-item
      v-for="(item, index) in dataItems"
      :key="item.name"
      :item="item"
      @change="onChange(item, index, $event)"
    />
  </tr>
</template>

<script>
import TableItem from '@/tools/TableManager/TableItem'

export default {
  components: {
    TableItem,
  },
  props: {
    items: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      dataItems: this.items,
    }
  },
  computed: {
    oneDimensional() {
      if (this.dataItems.length === 1) {
        return true
      } else {
        return false
      }
    },
  },
  methods: {
    onChange: function (item, index, event) {
      this.$emit('change', { index: index, event: event })
    },
  },
}
</script>
