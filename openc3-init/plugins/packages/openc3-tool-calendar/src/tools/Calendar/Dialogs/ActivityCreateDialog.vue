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
  <div>
    <v-dialog persistent v-model="show" width="600">
      <v-card>
        <form @submit.prevent="createActivity">
          <v-system-bar>
            <v-spacer />
            <span>Create Activity</span>
            <v-spacer />
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-icon data-test="close-activity-icon" @click="show = !show">
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
                <div class="pa-2">
                  <v-select
                    v-model="timeline"
                    :items="timelineNames"
                    label="Timeline"
                    data-test="activity-select-timeline"
                  >
                    <template v-slot:item="{ item, attrs, on }">
                      <v-list-item
                        v-on="on"
                        v-bind="attrs"
                        :data-test="`activity-select-timeline-${item}`"
                      >
                        <v-list-item-content>
                          <v-list-item-title>{{ item }}</v-list-item-title>
                        </v-list-item-content>
                      </v-list-item>
                    </template>
                  </v-select>
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
                  <v-row class="mt-2">
                    <v-spacer />
                    <v-btn
                      @click="dialogStep = 2"
                      data-test="create-activity-step-two-btn"
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
              Activity type input
            </v-stepper-step>
            <v-stepper-content step="2">
              <v-card-text>
                <div class="pa-2">
                  <v-select
                    v-model="kind"
                    :items="types"
                    label="Activity Type"
                    data-test="activity-select-type"
                  >
                    <template v-slot:item="{ item, attrs, on }">
                      <v-list-item
                        v-on="on"
                        v-bind="attrs"
                        :data-test="`activity-select-type-${item}`"
                      >
                        <v-list-item-content>
                          <v-list-item-title>{{ item }}</v-list-item-title>
                        </v-list-item-content>
                      </v-list-item>
                    </template>
                  </v-select>
                  <div v-if="kind === 'COMMAND'">
                    <v-text-field
                      v-model="activityData"
                      type="text"
                      label="Command Input"
                      placeholder="INST COLLECT with TYPE 0, DURATION 1, OPCODE 171, TEMP 0"
                      prefix="cmd('"
                      suffix="')"
                      hint="Timeline runs commands with cmd_no_hazardous_check"
                      data-test="activity-cmd"
                    />
                  </div>
                  <div v-else-if="kind === 'SCRIPT'">
                    <script-chooser @file="fileHandler" />
                    <environment-chooser @selected="selectedHandler" />
                  </div>
                  <div v-else>
                    <span class="ma-2"> No required input </span>
                  </div>
                  <v-row v-show="typeError">
                    <span class="ma-2 red--text" v-text="typeError" />
                  </v-row>
                  <v-row class="mt-2">
                    <v-spacer />
                    <v-btn
                      @click="show = !show"
                      outlined
                      class="mx-2"
                      data-test="create-activity-cancel-btn"
                    >
                      Cancel
                    </v-btn>
                    <v-btn
                      @click.prevent="createActivity"
                      class="mx-2"
                      color="primary"
                      type="submit"
                      data-test="create-activity-submit-btn"
                      :disabled="!!timeError || !!typeError"
                    >
                      Ok
                    </v-btn>
                  </v-row>
                </div>
              </v-card-text>
            </v-stepper-content>
          </v-stepper>
        </form>
      </v-card>
    </v-dialog>
  </div>
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
    timelines: {
      type: Array,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  mixins: [TimeFilters],
  data() {
    return {
      timeline: null,
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
  mounted: function () {
    this.updateValues()
  },
  computed: {
    timeError: function () {
      if (!this.timeline) {
        return 'Activity must have a timeline selected.'
      }
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
    timelineNames: function () {
      return this.timelines.map((timeline) => {
        return timeline.name
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
  methods: {
    changeKind: function (inputKind) {
      if (inputKind === this.kind) {
        return
      }
      this.kind = inputKind
      this.activityData = ''
    },
    fileHandler: function (event) {
      this.activityData = event ? event : null
    },
    selectedHandler: function (event) {
      this.activityEnvironment = event ? event : null
    },
    updateValues: function () {
      this.dialogStep = 1
      this.startDate = format(new Date(), 'yyyy-MM-dd')
      this.startTime = format(new Date(), 'HH:mm:ss')
      this.stopDate = format(new Date(), 'yyyy-MM-dd')
      this.stopTime = format(new Date(), 'HH:mm:ss')
      this.utcOrLocal = 'loc'
      this.kind = ''
      this.activityData = ''
      this.activityEnvironment = []
    },
    createActivity: function () {
      // Call the api to create a new activity to add to the activities array
      const start = this.toIsoString(
        Date.parse(`${this.startDate}T${this.startTime}`)
      )
      const stop = this.toIsoString(
        Date.parse(`${this.stopDate}T${this.stopTime}`)
      )
      const kind = this.kind.toLowerCase()
      let data = { environment: this.activityEnvironment }
      data[kind] = this.activityData
      Api.post(`/openc3-api/timeline/${this.timeline}/activities`, {
        data: { start, stop, kind, data },
      }).then((response) => {
        const activityTime = this.generateDateTime(
          new Date(response.data.start * 1000)
        )
        this.$notify.normal({
          title: 'Created Activity',
          body: `${activityTime} (${response.data.start}) on timeline: ${response.data.name}`,
        })
      })
      this.show = !this.show
      this.updateValues()
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
