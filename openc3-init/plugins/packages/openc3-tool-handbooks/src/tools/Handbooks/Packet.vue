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
  <v-card>
    <v-card-title class="text-h4 justify-center"
      >{{ packet.target_name }} {{ packet.packet_name }}</v-card-title
    >
    <v-card-subtitle
      >{{ packet.description }}
      <div class="float-right">{{ packet.endianness }}</div>
    </v-card-subtitle>
    <v-card-text>
      <v-container fluid>
        <v-row dense>
          <v-col v-for="item in items" :key="item.name" :cols="columns">
            <item :item="item"></item>
          </v-col>
        </v-row>
      </v-container>
    </v-card-text>
  </v-card>
</template>

<script>
import Item from './Item'

export default {
  components: {
    Item,
  },
  props: {
    packet: {
      type: Object,
      required: true,
    },
    columns: {
      type: Number,
      required: true,
    },
    hideIgnored: {
      type: Boolean,
      required: true,
    },
    hideDerived: {
      type: Boolean,
      required: true,
    },
    ignored: {
      type: Object,
    },
  },
  computed: {
    items() {
      let items = this.packet.items
      if (this.hideIgnored) {
        items = items.filter((item) => !this.ignored.includes(item.name))
      }
      if (this.hideDerived) {
        items = items.filter((item) => item.data_type !== 'DERIVED')
      }
      return items
    },
  },
}
</script>
