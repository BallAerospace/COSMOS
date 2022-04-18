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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <div>
    <v-dialog persistent v-model="show" width="600">
      <v-card>
        <form @submit.prevent="createMetadata">
          <v-system-bar>
            <v-spacer />
            <span>Create Chronicle Metadata</span>
            <v-spacer />
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-icon data-test="close-metadata-icon" @click="show = !show">
                    mdi-close-box
                  </v-icon>
                </div>
              </template>
              <span> Close </span>
            </v-tooltip>
          </v-system-bar>
          <v-stepper v-model="dialogStep" vertical non-linear>
            <v-stepper-step editable step="1">
              Input start time
            </v-stepper-step>
            <v-stepper-content step="1">
              <v-card-text>
                <div class="pa-2">
                  <v-select v-model="target" :items="targets" label="Target" />
                  <color-select-form v-model="color" />
                  <v-row dense>
                    <v-checkbox
                      v-model="userProvidedTime"
                      label="Input Metadata Time"
                    />
                  </v-row>
                  <div v-show="userProvidedTime">
                    <v-row dense>
                      <v-text-field
                        v-model="startDate"
                        type="date"
                        label="Start Date"
                        class="mx-1"
                        :rules="[rules.required]"
                        data-test="metadata-start-date"
                      />
                      <v-text-field
                        v-model="startTime"
                        type="time"
                        step="1"
                        label="Start Time"
                        class="mx-1"
                        :rules="[rules.required]"
                        data-test="metadata-start-time"
                      />
                    </v-row>
                    <v-row class="mx-2 mb-2">
                      <v-radio-group
                        v-model="utcOrLocal"
                        row
                        hide-details
                        class="mt-0"
                      >
                        <v-radio
                          label="LST"
                          value="loc"
                          data-test="lst-radio"
                        />
                        <v-radio
                          label="UTC"
                          value="utc"
                          data-test="utc-radio"
                        />
                      </v-radio-group>
                    </v-row>
                  </div>
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
                      data-test="create-metadata-step-two-btn"
                      color="success"
                      :disabled="!!timeError"
                    >
                      Continue
                    </v-btn>
                  </v-row>
                </div>
              </v-card-text>
            </v-stepper-content>
            <v-stepper-step editable step="2"> Metadata input </v-stepper-step>
            <v-stepper-content step="2">
              <v-card-text>
                <div class="pa-2">
                  <div style="min-height: 200px">
                    <metadata-input-form v-model="metadata" />
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
                      data-test="create-metadata-cancel-btn"
                    >
                      Cancel
                    </v-btn>
                    <v-btn
                      @click.prevent="createMetadata"
                      class="mx-2"
                      color="primary"
                      type="submit"
                      data-test="create-metadata-submit-btn"
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
import Api from '@cosmosc2/tool-common/src/services/api'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'

import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'
import ColorSelectForm from '@/tools/Calendar/Forms/ColorSelectForm'
import MetadataInputForm from '@/tools/Calendar/Forms/MetadataInputForm'

export default {
  components: {
    ColorSelectForm,
    MetadataInputForm,
  },
  props: {
    value: Boolean, // value is the default prop when using v-model
  },
  mixins: [TimeFilters],
  data() {
    return {
      scope: localStorage.scope,
      dialogStep: 1,
      target: '',
      targets: [],
      startDate: '',
      startTime: '',
      utcOrLocal: 'loc',
      userProvidedTime: false,
      color: '#003784',
      metadata: [],
      rules: {
        required: (value) => !!value || 'Required',
      },
    }
  },
  mounted: function () {
    this.updateValues()
    this.updateTargets()
  },
  computed: {
    timeError: function () {
      if (!this.target) {
        return 'Metadata must be associated with a target.'
      }
      if (!this.color) {
        return 'A color is required.'
      }
      if (!this.userProvidedTime) {
        return null
      }
      const now = new Date()
      const start = Date.parse(`${this.startDate}T${this.startTime}`)
      if (now < start) {
        return 'Invalid start time. Can not be in the future'
      }
      return null
    },
    typeError: function () {
      if (this.metadata.length < 1) {
        return 'Please enter a value in the metadata table.'
      }
      const emptyKeyValue = this.metadata.find(
        (meta) => meta.key === '' || meta.value === ''
      )
      if (emptyKeyValue) {
        return 'Missing or empty key, value in the metadata table.'
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
      this.metadata = []
      this.color = '#003784'
    },
    updateTargets: function () {
      new CosmosApi().get_target_list().then((data) => {
        this.targets = data
        this.targets.unshift(localStorage.scope)
        this.target = this.targets[0]
      })
    },
    createMetadata: function () {
      const color = this.color
      const metadata = this.metadata.reduce((result, element) => {
        result[element.key] = element.value
        return result
      }, {})
      const target = this.target
      const data = { color, target, metadata }
      if (this.userProvidedTime) {
        data.start = this.toIsoString(
          Date.parse(`${this.startDate}T${this.startTime}`)
        )
      }
      Api.post('/cosmos-api/metadata', {
        data,
      }).then((response) => {
        this.$notify.normal({
          title: 'Created new Metadata',
          body: `Metadata: (${response.data.start})`,
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
