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
  <v-row justify="center">
    <v-dialog persistent v-model="show" width="400">
      <v-card>
        <v-card-title>{{ title }}</v-card-title>
        <v-card-text>
          {{ message }}
        </v-card-text>
        <v-divider></v-divider>
        <v-card-actions :class="layoutClass">
          <template v-if="layout === 'combo'">
            <v-select
              v-model="selectedItem"
              label="Select"
              class="ma-1"
              @change="selectOkDisabled = false"
              :items="computedButtons"
              data-test="select"
            ></v-select>
            <v-btn
              class="ma-1"
              color="secondary"
              :disabled="selectOkDisabled"
              @click="$emit('submit', selectedItem)"
              >Ok</v-btn
            >
            <v-btn
              class="ma-1"
              color="secondary"
              @click="$emit('submit', 'Cancel')"
              >Cancel</v-btn
            >
          </template>
          <template v-else>
            <v-btn
              class="ma-1"
              v-for="(button, index) in computedButtons"
              :key="index"
              color="secondary"
              @click="$emit('submit', button.value)"
              >{{ button.text }}</v-btn
            >
            <v-btn
              class="ma-1"
              color="secondary"
              @click="$emit('submit', 'Cancel')"
              >Cancel</v-btn
            >
          </template>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-row>
</template>

<script>
export default {
  props: {
    title: {
      type: String,
      default: 'Prompt Dialog',
    },
    message: {
      type: String,
      required: true,
    },
    buttons: {
      type: Array,
      default: () => [],
    },
    layout: {
      type: String,
      default: 'horizontal', // Also 'vertical' or 'combo' when means ComboBox
    },
  },
  data() {
    return {
      show: true,
      selectOkDisabled: true,
      selectedItem: null,
    }
  },
  computed: {
    computedButtons() {
      if (this.buttons.length === 0) {
        return [
          { text: 'Yes', value: true },
          { text: 'No', value: false },
        ]
      } else {
        return this.buttons
      }
    },
    layoutClass() {
      let layout = 'd-flex align-start'
      if (this.layout === 'vertical') {
        return layout + ' flex-column'
      } else {
        return layout + ' flex-row'
      }
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
