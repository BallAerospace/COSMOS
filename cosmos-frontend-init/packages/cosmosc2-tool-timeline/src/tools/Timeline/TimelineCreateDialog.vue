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
    <v-tooltip top>
      <template v-slot:activator="{ on, attrs }">
        <v-btn
          icon
          data-test="createTimeline"
          @click="show = !show"
          v-bind="attrs"
          v-on="on"
        >
          <v-icon>mdi-calendar-plus</v-icon>
        </v-btn>
      </template>
      <span>Create Timelines</span>
    </v-tooltip>
    <v-dialog persistent v-model="show" width="500">
      <v-card class="pa-3">
        <v-toolbar>
          <v-toolbar-title> Create Timeline </v-toolbar-title>
          <v-spacer />
        </v-toolbar>
        <v-card-text>
          <v-row class="mt-3">
            Add a timeline to schedule activities on.
          </v-row>
          <v-row>
            <v-text-field
              v-model="timelineName"
              type="text"
              :rules="[rules.required]"
              label="Timeline Name"
              data-test="inputTimelineName"
            />
          </v-row>
          <v-row class="my-3">
            <span class="red--text" v-show="error" v-text="error" />
          </v-row>
          <v-row>
            <v-btn
              color="success"
              :disabled="!!error"
              @click="submit"
              data-test="create-submit-btn"
            >
              Ok
            </v-btn>
            <v-spacer />
            <v-btn color="primary" @click="clear" data-test="create-cancel-btn">
              Cancel
            </v-btn>
          </v-row>
        </v-card-text>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'

export default {
  props: {
    timelines: {
      type: Array,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      rules: {
        required: (value) => !!value || 'Required',
      },
      timelineName: '',
    }
  },
  computed: {
    error: function () {
      if (this.show === false) {
        return null
      }
      if (this.timelineName === '') {
        return 'Timeline name can not be blank.'
      }
      // Traditional for loop so we can return if we find a match
      this.timelines.forEach((timeline) => {
        if (timeline.name == this.timelineName) {
          return `Timeline must have a unique name. Duplicate timeline name found, ${timeline.name}`
        }
      })
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
    clear: function () {
      this.show = !this.show
      this.timelineName = ''
    },
    submit: function () {
      Api.post('/cosmos-api/timeline', {
        name: this.timelineName,
      })
        .then((response) => {
          const alertObject = {
            text: `Created new timeline: ${response.data.name}`,
            type: 'success',
          }
          this.$emit('alert', alertObject)
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to create timeline. ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
      this.clear()
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
