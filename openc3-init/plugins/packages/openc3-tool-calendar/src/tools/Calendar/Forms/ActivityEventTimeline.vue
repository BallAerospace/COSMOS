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
  <v-timeline align-top dense>
    <div v-for="event in events" :key="event.event + event.time">
      <v-timeline-item small :color="genColor(event)" :icon="genIcon(event)">
        <v-row class="pt-1">
          <v-col>
            <strong v-text="event.event" />
            <i>
              {{ event.time | dateTime(utc) }}
            </i>
            <div v-show="event.message" class="text-caption">
              {{ event.message }}
            </div>
          </v-col>
        </v-row>
      </v-timeline-item>
    </div>
  </v-timeline>
</template>

<script>
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'

export default {
  mixins: [TimeFilters],
  props: {
    activityEvents: {
      type: Array,
      required: true,
    },
    utc: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      showUpdateDialog: false,
    }
  },
  computed: {
    events: function () {
      return this.activityEvents.map((e) => {
        return { event: e.event, time: new Date(e.time * 1000) }
      })
    },
    states: function () {
      return {
        completed: {
          icon: 'mdi-check-circle',
          color: 'success',
        },
        failed: {
          icon: 'mdi-alert',
          color: 'error',
        },
        updated: {
          icon: 'mdi-alert-circle',
          color: 'purple',
        },
        queued: {
          icon: 'mdi-alert-circle',
          color: 'warning',
        },
        created: {
          icon: 'mdi-check-circle',
          color: 'success',
        },
      }
    },
  },
  methods: {
    genColor(event) {
      return this.states[event.event].color
    },
    genIcon(event) {
      return event.commit ? 'mdi-content-save' : this.states[event.event].icon
    },
  },
}
</script>
