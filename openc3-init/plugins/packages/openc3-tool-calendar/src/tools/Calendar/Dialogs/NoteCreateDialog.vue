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
        <form @submit.prevent="createNote">
          <v-system-bar>
            <v-spacer />
            <span>Create Note</span>
            <v-spacer />
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-icon data-test="close-note-icon" @click="show = !show">
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
                  <v-row dense>
                    <v-text-field
                      v-model="startDate"
                      type="date"
                      label="Start Date"
                      class="mx-1"
                      :rules="[rules.required]"
                      data-test="note-start-date"
                    />
                    <v-text-field
                      v-model="startTime"
                      type="time"
                      step="1"
                      label="Start Time"
                      class="mx-1"
                      :rules="[rules.required]"
                      data-test="note-start-time"
                    />
                  </v-row>
                  <v-row dense>
                    <v-text-field
                      v-model="stopDate"
                      type="date"
                      label="End Date"
                      class="mx-1"
                      :rules="[rules.required]"
                      data-test="note-stop-date"
                    />
                    <v-text-field
                      v-model="stopTime"
                      type="time"
                      step="1"
                      label="End Time"
                      class="mx-1"
                      :rules="[rules.required]"
                      data-test="note-stop-time"
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
                      data-test="create-note-step-two-btn"
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
              Input Description
            </v-stepper-step>
            <v-stepper-content step="2">
              <v-card-text>
                <div class="pa-2">
                  <div>
                    <color-select-form v-model="color" />
                  </div>
                  <div>
                    <v-text-field
                      v-model="description"
                      type="text"
                      label="Note Description"
                      data-test="create-note-description"
                    />
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
                      data-test="create-note-cancel-btn"
                    >
                      Cancel
                    </v-btn>
                    <v-btn
                      @click.prevent="createNote"
                      class="mx-2"
                      color="primary"
                      type="submit"
                      data-test="create-note-submit-btn"
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
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'
import ColorSelectForm from '@/tools/Calendar/Forms/ColorSelectForm'

export default {
  components: {
    ColorSelectForm,
  },
  props: {
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
      description: '',
      color: '#8F3400',
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
        return 'Invalid start, stop time. Notes must have different start and stop times.'
      }
      if (start > stop) {
        return 'Invalid start time. Notes start before stop.'
      }
      return null
    },
    typeError: function () {
      if (!this.color) {
        return 'A color is required.'
      }
      if (!this.description) {
        return 'A description is required for a valid note.'
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
    updateValues: function () {
      this.dialogStep = 1
      this.startDate = format(new Date(), 'yyyy-MM-dd')
      this.startTime = format(new Date(), 'HH:mm:ss')
      this.stopDate = format(new Date(), 'yyyy-MM-dd')
      this.stopTime = format(new Date(), 'HH:mm:ss')
      this.utcOrLocal = 'loc'
      this.color = '#8F3400'
      this.description = ''
    },
    createNote: function () {
      const start = this.toIsoString(
        Date.parse(`${this.startDate}T${this.startTime}`)
      )
      const stop = this.toIsoString(
        Date.parse(`${this.stopDate}T${this.stopTime}`)
      )
      const color = this.color
      const description = this.description
      Api.post('/openc3-api/notes', {
        data: { start, stop, color, description },
      }).then((response) => {
        const desc =
          response.data.description.length > 16
            ? `${response.data.description.substring(0, 16)}...`
            : response.data.description
        this.$notify.normal({
          title: 'Created new Note',
          body: `Note: (${response.data.start}) created: "${desc}"`,
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
