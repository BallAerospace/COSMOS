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
  <v-card class="mx-auto" outlined>
    <v-card-title class="justify-center">
      {{ item.name }}
    </v-card-title>
    <v-card-subtitle>{{ item.description }}</v-card-subtitle>
    <v-card-text class="text--primary">
      <div>Bit Offset: {{ item.bit_offset }}</div>
      <div>Bit Size: {{ item.bit_size }}</div>
      <div>Data Type: {{ item.data_type }}</div>
      <div>Endianness: {{ item.endianness }}</div>
      <div>Overflow: {{ item.overflow }}</div>
      <div v-if="Object.hasOwn(item, 'minimum')">
        Minimum: {{ item.minimum }}
      </div>
      <div v-if="Object.hasOwn(item, 'maximum')">
        Maximum: {{ item.maximum }}
      </div>
      <div v-if="Object.hasOwn(item, 'default')">
        Default: {{ item.default }}
      </div>
      <div v-if="readConversion">Read Conversion: {{ readConversion }}</div>
      <div v-if="writeConversion">Write Conversion: {{ writeConversion }}</div>
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
  computed: {
    readConversion() {
      if (Object.hasOwn(this.item, 'read_conversion')) {
        let result = `${this.item.read_conversion.class}`
        if (this.item.read_conversion.params) {
          result += ` with ${this.item.read_conversion.params.join(', ')}`
        }
        return result
      } else {
        return false
      }
    },
    writeConversion() {
      if (Object.hasOwn(this.item, 'write_conversion')) {
        let result = `${this.item.write_conversion.class}`
        if (this.item.write_conversion.params) {
          result += ` with ${this.item.write_conversion.params.join(', ')}`
        }
        return result
      } else {
        return false
      }
    },
  },
}
</script>
