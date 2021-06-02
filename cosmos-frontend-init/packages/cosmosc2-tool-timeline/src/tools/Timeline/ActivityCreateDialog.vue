<!--
# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addstopums as found in the LICENSE.txt
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
    <v-tooltip top>
      <template v-slot:activator="{ on, attrs }">
        <v-btn
          icon
          data-test="createActivity"
          @click="show = !show"
          v-bind="attrs"
          v-on="on"
        >
          <v-icon>mdi-alarm-plus</v-icon>
        </v-btn>
      </template>
      <span> Create activity</span>
    </v-tooltip>
    <v-dialog persistent v-model="show" width="600">
      <v-card class="pa-3">
        <v-toolbar>
          <v-toolbar-title>Create activity: {{ timeline }}</v-toolbar-title>
          <v-spacer />
          <v-menu>
            <template v-slot:activator="{ on, attrs }">
              <v-btn data-test="activityKind" outlined v-bind="attrs" v-on="on">
                <span>{{ kindToLabel[kind] }}</span>
                <v-icon right> mdi-menu-down </v-icon>
              </v-btn>
            </template>
            <v-list>
              <v-list-item data-test="cmd" @click="kind = 'cmd'">
                <v-list-item-title>CMD</v-list-item-title>
              </v-list-item>
              <v-list-item data-test="script" @click="kind = 'script'">
                <v-list-item-title>SCRIPT</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
        </v-toolbar>
        <v-card-text>
          <v-form ref="form" @submit.prevent="createActivity()">
            <v-sheet>
              <v-row dense>
                <v-text-field
                  v-model="startDate"
                  type="date"
                  label="Start Date"
                  :rules="[rules.required, rules.calendar]"
                  data-test="startDate"
                ></v-text-field>
                <v-text-field
                  v-model="startTime"
                  type="time"
                  label="Start Time"
                  :rules="[rules.required, rules.time]"
                  data-test="startTime"
                ></v-text-field>
              </v-row>
              <v-row dense>
                <v-text-field
                  v-model="stopDate"
                  type="date"
                  label="End Date"
                  :rules="[rules.required, rules.calendar]"
                  data-test="stopDate"
                />
                <v-text-field
                  v-model="stopTime"
                  type="time"
                  label="End Time"
                  :rules="[rules.required, rules.time]"
                  data-test="stopTime"
                />
              </v-row>
              <v-row dense>
                <v-radio-group
                  v-model="utcOrLocal"
                  row
                  hide-details
                  class="mt-0"
                >
                  <v-radio
                    label="Local"
                    value="loc"
                    data-test="local-radio"
                  ></v-radio>
                  <v-radio
                    label="UTC"
                    value="utc"
                    data-test="utc-radio"
                  ></v-radio>
                </v-radio-group>
              </v-row>
              <v-row dense>
                <v-text-field
                  v-model="activityData"
                  type="text"
                  label="Activity Data"
                  data-test="Activity Data"
                />
              </v-row>
              <v-row>
                <v-btn color="success" type="submit">Ok</v-btn>
                <v-spacer />
                <v-btn color="primary" @click="show = false">Cancel</v-btn>
              </v-row>
            </v-sheet>
          </v-form>
        </v-card-text>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import { isValid, parse, format, getTime } from 'date-fns'
import Api from '@cosmosc2/tool-common/src/services/api'
import TimeFilters from './util/timeFilters.js'

export default {
  props: {
    timeline: {
      type: String,
      required: true,
    },
    displayTimeInUtc: {
      type: Boolean,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  mixins: [TimeFilters],
  data() {
    return {
      startDate: format(new Date(), 'yyyy-MM-dd'),
      startTime: format(new Date(), 'HH:mm:ss'),
      stopDate: format(new Date(), 'yyyy-MM-dd'),
      stopTime: format(new Date(), 'HH:mm:ss'),
      utcOrLocal: 'loc',
      kind: 'cmd',
      kindToLabel: {
        cmd: 'CMD',
        script: 'SCRIPT',
      },
      activityData: '',
      rules: {
        required: (value) => !!value || 'Required',
        calendar: (value) => {
          try {
            return (
              isValid(parse(value, 'yyyy-MM-dd', new Date())) ||
              'Invalid date (YYYY-MM-DD)'
            )
          } catch (e) {
            return 'Invalid date (YYYY-MM-DD)'
          }
        },
        time: (value) => {
          try {
            let time_s = parse(value, 'HH:mm:ss', new Date())
            let time_m = parse(value, 'HH:mm', new Date())
            return (
              isValid(time_s) || isValid(time_m) || 'Invalid time (HH:MM:SS)'
            )
          } catch (e) {
            return 'Invalid time (HH:MM:SS)'
          }
        },
      },
    }
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
  methods: {
    createActivity() {
      // Call the api to create a new activity to add to the activities array
      const path = `/cosmos-api/timeline/${this.timeline}/activities`
      const sTime = this.toIsoString(
        Date.parse(`${this.startDate}T${this.startTime}`)
      )
      const eTime = this.toIsoString(
        Date.parse(`${this.stopDate}T${this.stopTime}`)
      )
      let data = {}
      data[this.kind] = this.activityData
      Api.post(path, {
        json: JSON.stringify({
          start: sTime,
          stop: eTime,
          kind: this.kind,
          data,
        }),
      })
        .then((response) => {
          const activityTime = this.generateDateTime(response.data)
          const alertObject = {
            text: `Created activity ${activityTime} (${response.data.start}) on timeline: ${response.data.name}`,
            type: 'success',
          }
          this.$emit('alert', alertObject)
          this.show = false
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to create activity. ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
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
