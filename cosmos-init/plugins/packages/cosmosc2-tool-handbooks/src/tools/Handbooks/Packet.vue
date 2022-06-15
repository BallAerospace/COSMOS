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
  <v-container :id="packet.target_name + '_' + packet.packet_name">
    <div class="text-h5">{{ packet.target_name }} {{ packet.packet_name }}</div>
    <div>{{ packet.description }}</div>
    <div>{{ packet.endianness }}</div>
    <v-row v-for="item in packet.items" :key="item.name">
      <item :item="item"></item>
    </v-row>
  </v-container>
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
  },
}
</script>
