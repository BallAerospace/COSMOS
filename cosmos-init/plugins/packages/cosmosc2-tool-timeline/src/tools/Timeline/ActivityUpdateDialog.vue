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
                    data-test="startDate"
                  />
                  <v-text-field
                    v-model="startTime"
                    type="time"
                    step="1"
                    label="Start Time"
                    class="mx-1"
                    :rules="[rules.required]"
                    data-test="startTime"
                  />
                </v-row>
                <v-row dense>
                  <v-text-field
                    v-model="stopDate"
                    type="date"
                    label="End Date"
                    class="mx-1"
                    :rules="[rules.required]"
                    data-test="stopDate"
                  />
                  <v-text-field
                    v-model="stopTime"
                    type="time"
                    step="1"
                    label="End Time"
                    class="mx-1"
                    :rules="[rules.required]"
                    data-test="stopTime"
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
                <v-row class="mb-2">
                  <v-menu>
                    <template v-slot:activator="{ on, attrs }">
                      <v-btn
                        data-test="activityKind"
                        block
                        outlined
                        v-bind="attrs"
                        v-on="on"
                      >
                        <span>{{ kindToLabel[kind] }}</span>
                        <v-icon right> mdi-menu-down </v-icon>
                      </v-btn>
                    </template>
                    <v-list>
                      <v-list-item data-test="cmd" @click="changeKind('cmd')">
                        <v-list-item-title>COMMAND</v-list-item-title>
                      </v-list-item>
                      <v-list-item
                        data-test="script"
                        @click="changeKind('script')"
                      >
                        <v-list-item-title>SCRIPT</v-list-item-title>
                      </v-list-item>
                      <v-list-item
                        data-test="reserve"
                        @click="changeKind('reserve')"
                      >
                        <v-list-item-title>RESERVE</v-list-item-title>
                      </v-list-item>
                    </v-list>
                  </v-menu>
                </v-row>
                <div v-if="kind === 'cmd'">
                  <v-text-field
                    v-model="activityData"
                    type="text"
                    label="Command Input"
                    placeholder="INST COLLECT with TYPE 0, DURATION 1, OPCODE 171, TEMP 0"
                    prefix="cmd('"
                    suffix="')"
                    hint="Timeline run commands with cmd_no_hazardous_check"
                    data-test="cmd"
                  />
                </div>
                <div v-else-if="kind === 'script'">
                  <script-chooser
                    class="my-1"
                    v-model="activityData"
                    @file="fileHandeler"
                  />
                  <environment-chooser
                    class="my-2"
                    v-model="activityEnvironment"
                    @selected="selectedHandeler"
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
                    data-test="update-cancel-btn"
                  >
                    Cancel
                  </v-btn>
                  <v-btn
                    @click.prevent="updateActivity"
                    class="mx-2"
                    color="primary"
                    type="submit"
                    data-test="update-submit-btn"
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
import Api from '@cosmosc2/tool-common/src/services/api'
import EnvironmentChooser from '@cosmosc2/tool-common/src/components/EnvironmentChooser'
import ScriptChooser from '@cosmosc2/tool-common/src/components/ScriptChooser'
import TimeFilters from './util/timeFilters.js'

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
    displayTimeInUtc: {
      type: Boolean,
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
      kind: 'cmd',
      kindToLabel: {
        cmd: 'COMMAND',
        script: 'SCRIPT',
        reserve: 'RESERVE',
      },
      activityData: '',
      activityEnvironment: [],
      rules: {
        required: (value) => !!value || 'Required',
      },
    }
  },
  mounted: function () {
    this.updateValues()
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
      if (this.kind !== 'reserve' && !this.activityData) {
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
      this.kind = this.activity.kind
      this.activityData = this.activity.data[this.activity.kind]
      this.activityEnvironment = this.activity.data.environment
    },
    fileHandeler: function (event) {
      this.activityData = event ? event : null
    },
    selectedHandeler: function (event) {
      this.activityEnvironment = event ? event : null
    },
    cancelActivity: function () {
      this.show = !this.show
    },
    updateActivity: function () {
      // Call the api to create a new activity to add to the activities array
      const path = `/cosmos-api/timeline/${this.activity.name}/activity/${this.activity.start}`
      const startString = this.toIsoString(
        Date.parse(`${this.startDate}T${this.startTime}`)
      )
      const stopString = this.toIsoString(
        Date.parse(`${this.stopDate}T${this.stopTime}`)
      )
      let data = { environment: this.activityEnvironment }
      data[this.kind] = this.activityData
      Api.put(path, {
        data: {
          start: startString,
          stop: stopString,
          kind: this.kind,
          data,
        },
      })
        .then((response) => {
          const activityTime = this.generateDateTime(response.data)
          const alertObject = {
            text: `Updated activity ${activityTime} (${response.data.start}) on timeline: ${response.data.name}`,
            type: 'success',
          }
          this.$emit('alert', alertObject)
          this.$emit('close', response.data)
          this.show = false
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              error: error,
              text: 'Failed to create activity.',
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
.v-stepper--vertical .v-stepper__content {
  width: auto;
  margin: 0px 0px 0px 36px;
  padding: 0px;
}
</style>
