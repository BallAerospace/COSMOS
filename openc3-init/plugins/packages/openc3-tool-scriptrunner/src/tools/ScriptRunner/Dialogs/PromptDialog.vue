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
  <v-dialog persistent v-model="show" width="600">
    <v-card>
      <v-system-bar>
        <v-spacer />
        <span v-text="title" />
        <v-spacer />
      </v-system-bar>
      <div class="pa-2">
        <v-card-text>
          <v-row v-if="subtitle">
            <v-card-subtitle>{{ subtitle }}</v-card-subtitle>
          </v-row>
          <v-row class="mt-1">
            <span v-text="message" />
          </v-row>
          <v-row v-if="details" class="mt-1">
            <span v-text="details" />
          </v-row>
        </v-card-text>
      </div>
      <div v-if="layout === 'combo'">
        <v-row class="ma-2">
          <v-select
            @change="selectOkDisabled = false"
            v-model="selectedItem"
            label="Select"
            color="secondary"
            class="ma-1"
            data-test="prompt-select"
            :items="buttons"
          />
        </v-row>
        <v-card-actions>
          <v-spacer />
          <v-btn
            @click="cancelHandler"
            outlined
            data-test="prompt-cancel"
            class="ma-1"
          >
            Cancel
          </v-btn>
          <v-btn
            @click="submitHandler"
            class="ma-1"
            color="primary"
            data-test="prompt-ok"
            :disabled="selectOkDisabled"
          >
            Ok
          </v-btn>
        </v-card-actions>
      </div>
      <div v-else>
        <v-card-actions :class="layoutClass">
          <v-spacer />
          <v-btn
            @click="cancelHandler"
            outlined
            data-test="prompt-cancel"
            class="ma-1"
          >
            Cancel
          </v-btn>
          <div v-for="(button, index) in buttons" :key="index">
            <v-btn
              @click="submitWrapper(button.value)"
              class="ma-1"
              :data-test="`prompt-${button.text}`"
              :color="button.value ? 'primary' : ''"
            >
              {{ button.text }}
            </v-btn>
          </div>
        </v-card-actions>
      </div>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    title: {
      type: String,
      default: 'Prompt Dialog',
    },
    subtitle: {
      type: String,
      default: '',
    },
    message: {
      type: String,
      required: true,
    },
    details: {
      type: String,
      default: '',
    },
    buttons: {
      type: Array,
      default: () => [],
    },
    layout: {
      type: String,
      default: 'horizontal', // Also 'vertical' or 'combo' when means ComboBox
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      selectOkDisabled: true,
      selectedItem: null,
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
    layoutClass() {
      let layout = 'd-flex align-start'
      if (this.layout === 'vertical') {
        return `${layout} flex-column`
      } else {
        return `${layout} flex-row`
      }
    },
  },
  methods: {
    submitWrapper: function (output) {
      this.selectedItem = output
      this.submitHandler()
    },
    submitHandler: function () {
      this.$emit('response', this.selectedItem)
    },
    cancelHandler: function () {
      this.$emit('response', 'Cancel')
    },
  },
}
</script>
