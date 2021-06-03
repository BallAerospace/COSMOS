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
  <v-dialog persistent v-model="show" width="400">
    <v-card class="pa-3">
      <v-card-title class="headline">Ask</v-card-title>
      <v-card-text>
        {{ question }}
        <v-form
          v-model="valid"
          ref="form"
          @submit.prevent="$emit('submit', value)"
        >
          <v-text-field
            autofocus
            :type="password ? 'password' : 'text'"
            v-model="value"
            :rules="rules"
          />
          <v-btn color="primary" :disabled="!valid" type="submit">Ok</v-btn>
          <v-btn
            class="ma-1"
            color="secondary"
            @click="$emit('submit', 'Cancel')"
          >
            Cancel
          </v-btn>
        </v-form>
      </v-card-text>
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
  },
  data() {
    return {
      show: true,
      value: '',
      valid: false,
      rules: [(v) => !!v || 'Required'],
    }
  },
  created() {
    if (this.default) {
      this.valid = true
      this.value = this.default
    }
    if (this.answerRequired === false) {
      this.valid = true
      this.rules = [(v) => true]
    }
  },
}
</script>

<style scoped>
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
</style>
