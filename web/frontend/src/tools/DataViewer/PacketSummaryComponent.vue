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
  <v-data-table
    :headers="headers"
    :items="rows"
    disable-pagination
    hide-default-footer
    dense
  />
</template>

<script>
export default {
  props: {
    packet: {
      type: Object,
      required: true,
    },
    receivedCount: {
      type: Number,
      required: true,
    },
  },
  data: function () {
    return {
      headers: [
        { text: 'Received', value: 'name' },
        { text: '', value: 'value' },
      ],
    }
  },
  computed: {
    rows: function () {
      const milliseconds = this.packet.time / 1000000
      return [
        {
          name: 'Seconds',
          value: milliseconds / 1000,
        },
        {
          name: 'Time',
          value: new Date(milliseconds).toISOString(),
        },
        {
          name: 'Count',
          value: this.receivedCount,
        },
      ]
    },
  },
}
</script>
