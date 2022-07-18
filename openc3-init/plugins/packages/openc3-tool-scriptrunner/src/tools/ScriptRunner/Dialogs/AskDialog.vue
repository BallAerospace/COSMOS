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
          <span> User Input Required </span>
          <v-spacer />
        </v-system-bar>
        <div class="pa-2">
          <v-card-text>
            <v-row>
              <v-card-title>{{ question }}</v-card-title>
            </v-row>
            <v-row class="my-1">
              <v-text-field
                v-model="inputValue"
                autofocus
                data-test="ask-value-input"
                :type="password ? 'password' : 'text'"
                :rules="rules"
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
            data-test="ask-cancel"
          >
            Cancel
          </v-btn>
          <v-btn
            @click.prevent="submitHandler"
            class="mx-1"
            color="primary"
            type="submit"
            data-test="ask-ok"
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
    question: {
      type: String,
      required: true,
    },
    default: {
      type: String,
      default: null,
    },
    password: {
      type: Boolean,
      default: false,
    },
    answerRequired: {
      type: Boolean,
      default: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      inputValue: '',
      valid: false,
      rules: [(v) => !!v || 'Required'],
    }
  },
  created() {
    if (this.default) {
      this.valid = true
      this.inputValue = this.default
    }
    if (this.answerRequired === false) {
      this.valid = true
      this.rules = [(v) => true]
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
