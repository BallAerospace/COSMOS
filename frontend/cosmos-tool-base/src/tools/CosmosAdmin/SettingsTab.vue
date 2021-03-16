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
  <div>
    <v-card>
      <v-card-title> Reset suppressed warnings </v-card-title>
      <v-card-subtitle>
        This resets "don't show this again" dialogs on this browser
      </v-card-subtitle>
      <v-card-text class="pb-0 ml-2">
        <template v-if="suppressedWarnings.length">
          <v-checkbox
            v-model="selectAllSuppressedWarnings"
            label="Select all"
            class="mt-0"
          />
          <v-checkbox
            v-for="warning in suppressedWarnings"
            :key="warning.key"
            v-model="selectedSuppressedWarnings"
            :label="warning.text"
            :value="warning.key"
            class="mt-0"
            dense
          />
        </template>
        <template v-else> No warnings to reset </template>
      </v-card-text>
      <v-card-actions>
        <v-btn
          :disabled="!selectedSuppressedWarnings.length"
          @click="resetSuppressedWarnings"
          color="warning"
          text
          class="ml-2"
        >
          Reset
        </v-btn>
      </v-card-actions>
    </v-card>
    <v-divider />
    <v-card>
      <v-card-title> Forget recent configs </v-card-title>
      <v-card-subtitle>
        This forgets the most recently saved/loaded tool configs on this browser
      </v-card-subtitle>
      <v-card-text class="pb-0 ml-2">
        <template v-if="lastConfigs.length">
          <v-checkbox
            v-model="selectAllLastConfigs"
            label="Select all"
            class="mt-0"
          />
          <v-checkbox
            v-for="config in lastConfigs"
            :key="config.key"
            v-model="selectedLastConfigs"
            :label="`${config.text} (${config.value})`"
            :value="config.key"
            class="mt-0"
            dense
          />
        </template>
        <template v-else> No configs to forget </template>
      </v-card-text>
      <v-card-actions>
        <v-btn
          :disabled="!selectedLastConfigs.length"
          @click="forgetLastConfigs"
          color="warning"
          text
          class="ml-2"
        >
          Forget
        </v-btn>
      </v-card-actions>
    </v-card>
    <v-divider />
    <classification-banner-settings />
  </div>
</template>

<script>
import ClassificationBannerSettings from './ClassificationBannerSettings.vue'

export default {
  components: {
    ClassificationBannerSettings,
  },
  data() {
    return {
      suppressedWarnings: [],
      selectedSuppressedWarnings: [],
      selectAllSuppressedWarnings: false,
      lastConfigs: [],
      selectedLastConfigs: [],
      selectAllLastConfigs: false,
    }
  },
  watch: {
    selectAllSuppressedWarnings: function (val) {
      if (val) {
        this.selectedSuppressedWarnings = this.suppressedWarnings.map(
          (warning) => warning.key
        )
      } else {
        this.selectedSuppressedWarnings = []
      }
    },
    selectAllLastConfigs: function (val) {
      if (val) {
        this.selectedLastConfigs = this.lastConfigs.map((config) => config.key)
      } else {
        this.selectedLastConfigs = []
      }
    },
  },
  created() {
    this.loadSuppressedWarnings()
    this.loadLastConfigs()
  },
  methods: {
    loadSuppressedWarnings: function () {
      this.suppressedWarnings = Object.keys(localStorage)
        .filter((key) => {
          return key.startsWith('suppresswarning__')
        })
        .map(this.localStorageKeyToDisplayObject)
      this.selectedSuppressedWarnings = []
    },
    resetSuppressedWarnings: function () {
      this.deleteLocalStorageKeys(this.selectedSuppressedWarnings)
      this.loadSuppressedWarnings()
    },
    loadLastConfigs: function () {
      this.lastConfigs = Object.keys(localStorage)
        .filter((key) => {
          return key.startsWith('lastconfig__')
        })
        .map(this.localStorageKeyToDisplayObject)
      this.selectedLastConfigs = []
    },
    forgetLastConfigs: function () {
      this.deleteLocalStorageKeys(this.selectedLastConfigs)
      this.loadLastConfigs()
    },
    deleteLocalStorageKeys: function (keys) {
      for (const key of keys) {
        delete localStorage[key]
      }
    },
    localStorageKeyToDisplayObject: function (key) {
      const name = key.split('__')[1].replaceAll('_', ' ')
      return {
        key,
        text: name.charAt(0).toUpperCase() + name.slice(1),
        value: localStorage[key],
      }
    },
  },
}
</script>
