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
  <div>
    <v-tooltip v-if="icon" top>
      <template v-slot:activator="{ on, attrs }">
        <div v-on="on" v-bind="attrs">
          <v-btn icon data-test="viewActivityIcon" @click="show = !show">
            <v-icon> mdi-eye </v-icon>
          </v-btn>
        </div>
      </template>
      <span> View Activity </span>
    </v-tooltip>
    <v-list-item v-else data-test="viewActivity" @click.stop="show = !show">
      <v-list-item-title> View Activity </v-list-item-title>
    </v-list-item>
    <v-dialog v-model="show" width="55%">
      <v-card class="pa-3" max-height="70%">
        <v-toolbar>
          <v-toolbar-title>Timeline: {{ activity.name }}</v-toolbar-title>
        </v-toolbar>
        <v-row dense class="mt-2">
          <v-col>
            <v-simple-table dense>
              <tbody>
                <tr>
                  <th class="text-left" width="100">Fulfilled</th>
                  <td v-text="activity.fulfillment" />
                </tr>
                <tr>
                  <th class="text-left" width="100">Start Time</th>
                  <td>
                    {{ activity.start | dateTime(displayTimeInUtc) }}
                  </td>
                </tr>
                <tr>
                  <th class="text-left">Stop Time</th>
                  <td>
                    {{ activity.stop | dateTime(displayTimeInUtc) }}
                  </td>
                </tr>
                <tr>
                  <th class="text-left">Kind</th>
                  <td v-text="activity.kind" />
                </tr>
                <tr>
                  <th class="text-left">Data</th>
                  <td v-text="activity.data[activity.kind]" />
                </tr>
              </tbody>
            </v-simple-table>
          </v-col>
          <v-col>
            <event-timeline
              :events="activity.events"
              :display-time-in-utc="displayTimeInUtc"
            />
          </v-col>
        </v-row>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import EventTimeline from '@/tools/Timeline/EventTimeline'
import TimeFilters from './util/timeFilters.js'

export default {
  components: {
    EventTimeline,
  },
  mixins: [TimeFilters],
  props: {
    icon: Boolean,
    activity: {
      type: Object,
      required: true,
    },
    displayTimeInUtc: {
      type: Boolean,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  computed: {
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
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
