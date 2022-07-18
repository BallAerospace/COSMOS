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
      <v-form v-model="valid" v-on:submit.prevent="submitHandler">
        <v-system-bar>
          <v-spacer />
          <span> File Dialog </span>
          <v-spacer />
        </v-system-bar>
        <div class="pa-2">
          <v-card-text>
            <v-row>
              <v-card-title>{{ title }}</v-card-title>
            </v-row>
            <v-row v-if="message">
              <span class="ma-3" v-text="message" />
            </v-row>
            <v-row class="my-1">
              <v-file-input
                label="Choose File"
                v-model="inputValue"
                autofocus
                data-test="file-input"
                :accept="filter"
                small-chips
                :multiple="multiple"
              />
            </v-row>
          </v-card-text>
        </div>
        <v-card-actions>
          <v-spacer />
          <v-btn
            @click="cancelHandler"
            outlined
            class="mx-1"
            data-test="file-cancel"
          >
            Cancel
          </v-btn>
          <v-btn
            @click.prevent="submitHandler"
            class="mx-1"
            color="primary"
            type="submit"
            data-test="file-ok"
            :disabled="!valid"
          >
            Ok
          </v-btn>
        </v-card-actions>
      </v-form>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    title: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      default: null,
    },
    filter: {
      type: String,
      default: '*',
    },
    multiple: {
      type: Boolean,
      default: false,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      inputValue: null,
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
  },
  methods: {
    submitHandler: function () {
      // Ensure we send back an array of file names even in the single case
      // to make it easier to deal with a consistent result
      if (!Array.isArray(this.inputValue)) {
        this.inputValue = [this.inputValue]
      }
      this.$emit('response', this.inputValue)
    },
    cancelHandler: function () {
      this.$emit('response', 'Cancel')
    },
  },
}
</script>
