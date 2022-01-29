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
  <v-dialog v-model="show" width="600">
    <v-system-bar>
      <v-spacer />
      <span>TlmGrapher Settings</span>
      <v-spacer />
    </v-system-bar>
    <v-card class="pa-3">
      <v-card-text>
        <div v-for="item in settings" :key="item.title">
          <v-row class="my-5">
            <v-text-field
              hide-details="auto"
              type="number"
              :rules="item.rules"
              :label="item.title"
              v-model.number="item.value"
            />
          </v-row>
        </div>
        <v-row>
          <span class="red--text">
            Increasing these values may cause issues
          </span>
        </v-row>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'

export default {
  props: {
    settings: {
      type: Object,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {}
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
  methods: {},
}
</script>
