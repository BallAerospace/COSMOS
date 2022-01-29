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
  <v-dialog v-model="show" width="600">
    <v-card>
      <v-system-bar>
        <v-spacer />
        <span> Timeline: {{ activity.name }}/{{ activity.start }} </span>
        <v-spacer />
      </v-system-bar>
      <v-card-text>
        <div class="pa-3">
          <v-row>
            <v-col :cols="12">
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
                    <th class="text-left" v-text="activity.kind" />
                    <td v-text="activity.data[activity.kind]" />
                  </tr>
                  <tr v-if="showEnv">
                    <th class="text-left">ENV</th>
                    <td v-text="activity.data.environment" />
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
        </div>
      </v-card-text>
    </v-card>
  </v-dialog>
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
    showEnv: function () {
      return (
        this.activity.data.environment &&
        this.activity.data.environment.length > 0
      )
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
}
</script>

<style scoped>
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
</style>
