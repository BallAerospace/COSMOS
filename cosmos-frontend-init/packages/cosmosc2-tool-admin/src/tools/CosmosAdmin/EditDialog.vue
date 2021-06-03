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
    <v-card class="pa-3">
      <v-card-title class="headline">{{ title }}</v-card-title>
      <v-card-text>
        <v-form ref="form" @submit.prevent="$emit('submit', json_content)">
          <v-textarea
            autofocus
            solo
            v-model="json_content"
            rows="20"
            :readonly="readonly"
          />
          <v-btn color="primary" type="submit">Ok</v-btn>
          &nbsp;&nbsp;
          <v-btn color="primary" type="submit" @click="json_content = null"
            >Cancel</v-btn
          >
        </v-form>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    content: {
      type: String,
      required: true,
    },
    title: String,
    value: Boolean, // value is the default prop when using v-model
    readonly: Boolean,
  },
  data() {
    return {
      json_content: this.content,
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
}
</script>

<style scoped>
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
</style>
