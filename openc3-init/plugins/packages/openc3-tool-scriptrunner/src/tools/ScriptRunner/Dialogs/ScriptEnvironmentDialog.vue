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
  <v-dialog v-model="show" width="600">
    <v-card>
      <v-system-bar>
        <v-spacer />
        <span> Start Environment Configuration </span>
        <v-spacer />
      </v-system-bar>
      <div class="pa-2">
        <v-card-text>
          <environment-chooser v-model="selected" />
        </v-card-text>
      </div>
      <v-card-actions>
        <v-spacer />
        <v-btn
          @click="cancel"
          class="mx-2"
          outlined
          data-test="environment-dialog-cancel"
        >
          Cancel
        </v-btn>
        <v-btn
          @click="updateEnvironment"
          class="mx-2"
          color="primary"
          data-test="environment-dialog-save"
          :disabled="!!inputError"
        >
          Save
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
import EnvironmentChooser from '@openc3/tool-common/src/components/EnvironmentChooser'

export default {
  components: {
    EnvironmentChooser,
  },
  props: {
    value: {
      type: Boolean,
      required: true,
    },
    inputEnvironment: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      selected: [],
    }
  },
  mounted: function () {
    this.loadEnvironment()
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
    loadEnvironment: function () {
      this.selected = [...this.inputEnvironment]
    },
    updateEnvironment: function () {
      this.$emit('environment', this.selected)
      this.show = !this.show
    },
    cancel: function () {
      this.show = !this.show
    },
  },
}
</script>
