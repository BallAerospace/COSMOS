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
  <v-dialog v-model="show" width="600">
    <v-card>
      <v-system-bar>
        <v-spacer />
        <span>Events</span>
        <v-spacer />
      </v-system-bar>
      <v-data-table
        v-model="selected"
        item-key="eventId"
        class="mt-1"
        :headers="eventHeaders"
        :items="listData"
      >
        <template v-slot:no-data>
          <span> No events </span>
        </template>
      </v-data-table>
    </v-card>
  </v-dialog>
</template>

<script>
import { isValid, parse, format, getTime } from 'date-fns'
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'

export default {
  components: {},
  mixins: [TimeFilters],
  props: {
    events: {
      type: Array,
      required: true,
    },
    utc: {
      type: Boolean,
      default: true,
    },
    value: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      selected: [],
      eventHeaders: [
        { text: 'Name', value: 'name' },
        { text: 'Start', value: 'startStr' },
        { text: 'Stop', value: 'stopStr' },
        { text: 'Type', value: 'type' },
      ],
    }
  },
  computed: {
    listData: function () {
      if (!this.events) return []
      let eventId = 0
      return this.events.map((event) => {
        eventId += 1
        let startStr, stopStr
        if (this.utc) {
          startStr = event.start.toUTCString()
          stopStr = event.end.toUTCString()
        } else {
          startStr = event.start.toLocaleString()
          stopStr = event.end.toLocaleString()
        }
        return {
          ...event,
          startStr,
          stopStr,
          eventId,
        }
      })
    },
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  mounted: function () {
    // console.log(this.events)
  },
  methods: {},
}
</script>
