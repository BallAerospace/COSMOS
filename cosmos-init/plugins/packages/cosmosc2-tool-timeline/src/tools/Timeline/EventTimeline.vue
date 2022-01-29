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
  <v-timeline align-top dense>
    <v-timeline-item
      v-for="event in events"
      :key="event.event + event.time"
      :color="genColor(event)"
      small
    >
      <v-row>
        <v-col cols="11">
          <div class="text-uppercase h6" v-text="event.event" />
          <div class="">{{ event.time | dateTime(displayTimeInUtc) }}</div>
          <div v-if="event.message" v-text="event.message" />
        </v-col>
        <v-col>
          <v-icon v-if="event.commit && showIcon" v-text="'mdi-content-save'" />
        </v-col>
      </v-row>
    </v-timeline-item>
  </v-timeline>
</template>

<script>
import TimeFilters from './util/timeFilters.js'

const STATES = {
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

export default {
  mixins: [TimeFilters],
  props: {
    events: {
      type: Array,
      required: true,
    },
    showIcon: {
      type: Boolean,
      default: false,
    },
    displayTimeInUtc: {
      type: Boolean,
      default: false,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      show: false,
    }
  },
  methods: {
    genColor(event) {
      if (!this.events) return ''
      return STATES[event.event].color
    },
    genIcon(event) {
      if (!this.events) return ''
      return STATES[event.event].icon
    },
  },
}
</script>

<style scoped>
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
</style>
