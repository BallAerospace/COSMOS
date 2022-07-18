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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
-->

<template>
  <div>
    <v-dialog v-model="show" width="600">
      <v-card>
        <form v-on:submit.prevent="submitHandler">
          <v-system-bar>
            <v-spacer />
            <span> Create New Trigger Group </span>
            <v-spacer />
          </v-system-bar>
          <v-card-text>
            <div class="pa-3">
              <v-text-field
                v-model="groupName"
                label="Group Name"
                data-test="group-input-name"
                autofocus
                dense
                outlined
                hide-details
              />
              <v-row dense>
                <v-sheet dark class="pa-4">
                  <pre v-text="color" />
                </v-sheet>
              </v-row>
              <v-row dense align="center" justify="center">
                <v-color-picker
                  v-model="color"
                  hide-canvas
                  hide-inputs
                  hide-mode-switch
                  show-swatches
                  :swatches="swatches"
                  width="100%"
                  swatches-max-height="100"
                />
              </v-row>
              <v-row class="my-3">
                <span class="red--text" v-show="error">{{ error }}</span>
              </v-row>
              <v-row>
                <v-spacer />
                <v-btn
                  @click="clearHandler"
                  outlined
                  class="mx-2"
                  data-test="group-create-cancel-btn"
                >
                  Cancel
                </v-btn>
                <v-btn
                  @click.prevent="submitHandler"
                  class="mx-2"
                  type="submit"
                  color="primary"
                  data-test="group-create-submit-btn"
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
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'

export default {
  props: {
    groups: {
      type: Array,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      groupName: '',
      color: '#FF0000',
      swatches: [
        ['#FF0000', '#AA0000', '#550000'],
        ['#FFFF00', '#AAAA00', '#555500'],
        ['#00FF00', '#00AA00', '#005500'],
        ['#00FFFF', '#00AAAA', '#005555'],
        ['#0000FF', '#0000AA', '#000055'],
      ],
      rules: {
        required: (value) => !!value || 'Required',
      },
    }
  },
  computed: {
    error: function () {
      if (this.groupName.trim() === '') {
        return 'TriggerGroup name can not be blank.'
      }
      if (this.groupName.includes('_')) {
        return `TriggerGroup name can not contain an underscore [ '_' ].`
      }
      // Traditional for loop so we can return if we find a match
      if (this.groups.includes(this.groupName)) {
        return `TriggerGroup must have a unique name. Duplicate name found, ${this.groupName}`
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
    clearHandler: function () {
      this.show = !this.show
      this.groupName = ''
      this.color = '#FF0000'
    },
    submitHandler(event) {
      const path = `/openc3-api/autonomic/group`
      Api.post(path, {
        data: {
          name: this.groupName,
          color: this.color,
        },
      }).then((response) => {})
      this.clearHandler()
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
