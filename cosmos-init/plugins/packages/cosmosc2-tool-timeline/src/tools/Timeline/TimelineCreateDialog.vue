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
  <v-dialog persistent v-model="show" width="600">
    <v-card>
      <form v-on:submit.prevent="submit">
        <v-system-bar>
          <v-spacer />
          <span>Create Timeline</span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <div class="pa-3">
            <v-row> Add a timeline to schedule activities on. </v-row>
            <v-row>
              <v-text-field
                v-model="timelineName"
                autofocus
                type="text"
                label="Timeline Name"
                data-test="inputTimelineName"
                :rules="[rules.required]"
              />
            </v-row>
            <v-row class="my-3">
              <span class="red--text" v-show="error" v-text="error" />
            </v-row>
            <v-row>
              <v-spacer />
              <v-btn
                @click="clear"
                outlined
                class="mx-2"
                data-test="create-cancel-btn"
              >
                Cancel
              </v-btn>
              <v-btn
                @click.prevent="submit"
                class="mx-2"
                type="submit"
                color="primary"
                data-test="create-submit-btn"
                :disabled="!!error"
              >
                Ok
              </v-btn>
            </v-row>
          </div>
        </v-card-text>
      </form>
    </v-card>
  </v-dialog>
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
        data: {
          name: this.timelineName,
        },
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
