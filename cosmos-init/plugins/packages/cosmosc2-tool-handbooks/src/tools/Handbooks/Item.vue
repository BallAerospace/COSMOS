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
  <v-card class="mx-auto" outlined>
    <v-card-title>
      {{ item.name }}
    </v-card-title>
    <v-card-subtitle>{{ item.description }}</v-card-subtitle>
    <v-card-text>
      <div>Bit Offset: {{ item.bit_offset }}</div>
      <div>Bit Size: {{ item.bit_size }}</div>
      <div>Data Type: {{ item.data_type }}</div>
      <div>Endianness: {{ item.endianness }}</div>
      <div>Overflow: {{ item.overflow }}</div>
    </v-card-text>
  </v-card>
</template>

<script>
export default {
  props: {
    item: {
      type: Object,
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
  },
  created() {
    console.log(this.item)
  },
}
</script>
