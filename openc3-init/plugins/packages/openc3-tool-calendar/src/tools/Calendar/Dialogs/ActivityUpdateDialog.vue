<!--
# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
-->

<template>
  <v-dialog v-model="show" width="600">
    <v-card>
      <form v-on:submit.prevent="updateActivity">
        <v-system-bar>
          <v-spacer />
          <span>
            Update activity: {{ activity.name }}/{{ activity.start }}
          </span>
          <v-spacer />
          <v-tooltip top>
            <template v-slot:activator="{ on, attrs }">
              <div v-on="on" v-bind="attrs">
                <v-icon data-test="close-activity-icon" @click="cancelActivity">
                  mdi-close-box
                </v-icon>
              </div>
            </template>
            <span> Close </span>
          </v-tooltip>
        </v-system-bar>
        <v-stepper v-model="dialogStep" vertical non-linear>
          <v-stepper-step editable step="1">
            Input start time, stop time
          </v-stepper-step>
          <v-stepper-content step="1">
            <v-card-text>
              <div class="pa-3">
                <v-row dense>
                  <v-text-field
                    v-model="startDate"
                    type="date"
                    label="Start Date"
                    class="mx-1"
                    :rules="[rules.required]"
                    data-test="activity-start-date"
                  />
                  <v-text-field
                    v-model="startTime"
                    type="time"
                    step="1"
                    label="Start Time"
                    class="mx-1"
                    :rules="[rules.required]"
                    data-test="activity-start-time"
                  />
                </v-row>
                <v-row dense>
                  <v-text-field
                    v-model="stopDate"
                    type="date"
                    label="End Date"
                    class="mx-1"
                    :rules="[rules.required]"
                    data-test="activity-stop-date"
                  />
                  <v-text-field
                    v-model="stopTime"
                    type="time"
                    step="1"
                    label="End Time"
                    class="mx-1"
                    :rules="[rules.required]"
                    data-test="activity-stop-time"
                  />
                </v-row>
                <v-row class="mx-2 mb-2">
                  <v-radio-group
                    v-model="utcOrLocal"
                    row
                    hide-details
                    class="mt-0"
                  >
                    <v-radio label="LST" value="loc" data-test="lst-radio" />
                    <v-radio label="UTC" value="utc" data-test="utc-radio" />
                  </v-radio-group>
                </v-row>
                <v-row>
                  <span
                    class="ma-2 red--text"
                    v-show="timeError"
                    v-text="timeError"
                  />
                </v-row>
                <v-row>
                  <v-spacer />
                  <v-btn
                    @click="dialogStep = 2"
                    data-test="update-activity-step-two-btn"
                    color="success"
                    :disabled="!!timeError"
                  >
                    Continue
                  </v-btn>
                </v-row>
              </div>
            </v-card-text>
          </v-stepper-content>

          <v-stepper-step editable step="2">
            Activity type Input
          </v-stepper-step>
          <v-stepper-content step="2">
            <v-card-text>
              <div class="pa-3">
                <v-select v-model="kind" :items="types" label="Activity Type" />
                <div v-if="kind === 'COMMAND'">
                  <v-text-field
                    v-model="activityData"
                    type="text"
                    label="Command Input"
                    placeholder="INST COLLECT with TYPE 0, DURATION 1, OPCODE 171, TEMP 0"
                    prefix="cmd('"
                    suffix="')"
                    hint="Timeline run commands with cmd_no_hazardous_check"
                    data-test="activity-cmd"
                  />
                </div>
                <div v-else-if="kind === 'SCRIPT'">
                  <script-chooser
                    class="my-1"
                    v-model="activityData"
                    @file="fileHandler"
                  />
                  <environment-chooser
                    class="my-2"
                    v-model="activityEnvironment"
                    @selected="selectedHandler"
                  />
                </div>
                <div v-else>
                  <span class="ma-2"> No required input </span>
                </div>
                <v-row v-show="typeError">
                  <span class="ma-2 red--text" v-text="typeError" />
                </v-row>
                <v-row>
                  <v-spacer />
                  <v-btn
                    @click="cancelActivity"
                    outlined
                    class="mx-2"
                    data-test="update-activity-cancel-btn"
                  >
                    Cancel
                  </v-btn>
                  <v-btn
                    @click.prevent="updateActivity"
                    class="mx-2"
                    color="primary"
                    type="submit"
                    data-test="update-activity-submit-btn"
                    :disabled="!!timeError || !!typeError"
                  >
                    Update
                  </v-btn>
                </v-row>
              </div>
            </v-card-text>
          </v-stepper-content>
        </v-stepper>
      </form>
    </v-card>
  </v-dialog>
</template>

<script>
import { isValid, parse, format, getTime } from 'date-fns'
import Api from '@openc3/tool-common/src/services/api'
import EnvironmentChooser from '@openc3/tool-common/src/components/EnvironmentChooser'
import ScriptChooser from '@openc3/tool-common/src/components/ScriptChooser'
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'

export default {
  components: {
    EnvironmentChooser,
    ScriptChooser,
  },
  props: {
    activity: {
      type: Object,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  mixins: [TimeFilters],
  data() {
    return {
      dialogStep: 1,
      startDate: '',
      startTime: '',
      stopDate: '',
      stopTime: '',
      utcOrLocal: 'loc',
      kind: '',
      types: ['COMMAND', 'SCRIPT', 'RESERVE'],
      activityData: '',
      activityEnvironment: [],
      rules: {
        required: (value) => !!value || 'Required',
      },
    }
  },
  watch: {
    show: function () {
      this.updateValues()
    },
  },
  computed: {
    timeError: function () {
      const now = new Date()
      const start = Date.parse(`${this.startDate}T${this.startTime}`)
      const stop = Date.parse(`${this.stopDate}T${this.stopTime}`)
      if (start === stop) {
        return 'Invalid start, stop time. Activity must have different start and stop times.'
      }
      if (now > start) {
        return 'Invalid start time. Activity must be in the future.'
      }
      if (start > stop) {
        return 'Invalid start time. Activity start before stop.'
      }
      return null
    },
    typeError: function () {
      if (this.kind !== 'RESERVE' && !this.activityData) {
        return 'No data is selected or inputted'
      }
      return null
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
  methods: {
    changeKind: function (inputKind) {
      if (inputKind === this.kind) {
        return
      }
      this.kind = inputKind
      this.activityData = ''
    },
    updateValues: function () {
      const sDate = new Date(this.activity.start * 1000)
      const eDate = new Date(this.activity.stop * 1000)
      this.startDate = format(sDate, 'yyyy-MM-dd')
      this.startTime = format(sDate, 'HH:mm:ss')
      this.stopDate = format(eDate, 'yyyy-MM-dd')
      this.stopTime = format(eDate, 'HH:mm:ss')
      this.kind = this.activity.kind.toUpperCase()
      this.activityData = this.activity.data[this.activity.kind]
      this.activityEnvironment = this.activity.data.environment
    },
    fileHandler: function (event) {
      this.activityData = event ? event : null
    },
    selectedHandler: function (event) {
      this.activityEnvironment = event ? event : null
    },
    cancelActivity: function () {
      this.show = !this.show
    },
    updateActivity: function () {
      // Call the api to update the activity
      const start = this.toIsoString(
        Date.parse(`${this.startDate}T${this.startTime}`)
      )
      const stop = this.toIsoString(
        Date.parse(`${this.stopDate}T${this.stopTime}`)
      )
      const kind = this.kind.toLowerCase()
      let data = { environment: this.activityEnvironment }
      data[kind] = this.activityData
      const tName = this.activity.name
      const aStart = this.activity.start
      Api.put(`/openc3-api/timeline/${tName}/activity/${aStart}`, {
        data: { start, stop, kind, data },
      }).then((response) => {
        const activityTime = this.generateDateTime(
          new Date(response.data.start * 1000)
        )
        this.$notify.normal({
          title: 'Updated Activity',
          body: `${activityTime} (${response.data.start}) on timeline: ${response.data.name}`,
        })
      })
      this.$emit('close')
      this.show = !this.show
    },
  },
}
</script>

<style scoped>
.v-stepper--vertical .v-stepper__content {
  width: auto;
  margin: 0px 0px 0px 36px;
  padding: 0px;
}
</style>
