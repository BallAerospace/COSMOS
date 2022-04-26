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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
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
              <v-card-title v-text="message" />
            </v-row>
            <v-row class="my-1">
              <v-file-input
                label="Choose File"
                v-model="inputValue"
                autofocus
                data-test="file-input"
                :accept="filter"
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
    message: {
      type: String,
      required: true,
    },
    directory: {
      type: String,
      required: true,
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
      inputValue: '',
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
      this.$emit('response', this.inputValue)
    },
    cancelHandler: function () {
      this.$emit('response', 'Cancel')
    },
  },
}
</script>
