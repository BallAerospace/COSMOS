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
            data-test="select-all-suppressed-warnings"
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
          data-test="reset-suppressed-warnings"
        >
          Reset
        </v-btn>
      </v-card-actions>
    </v-card>
    <v-divider />
    <v-card>
      <v-card-title> Clear recent configs </v-card-title>
      <v-card-subtitle>
        This clears the most recently saved/loaded tool configs on this browser
      </v-card-subtitle>
      <v-card-text class="pb-0 ml-2">
        <template v-if="lastConfigs.length">
          <v-checkbox
            v-model="selectAllLastConfigs"
            label="Select all"
            class="mt-0"
            data-test="select-all-last-configs"
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
        <template v-else> No configs to clear </template>
      </v-card-text>
      <v-card-actions>
        <v-btn
          :disabled="!selectedLastConfigs.length"
          @click="clearLastConfigs"
          color="warning"
          text
          class="ml-2"
          data-test="clear-last-configs"
        >
          Clear
        </v-btn>
      </v-card-actions>
    </v-card>
    <v-divider />
    <classification-banner-settings />
    <v-divider />
    <v-card>
      <v-card-title> Source code URL </v-card-title>
      <v-card-subtitle>
        This sets the URL for the "Source" link in the footer. This is required
        under the AGPL license.
      </v-card-subtitle>
      <v-card-text class="pb-0 ml-2">
        <v-text-field
          label="Source URL"
          v-model="sourceUrl"
          data-test="source-url"
        />
      </v-card-text>
      <v-card-actions>
        <v-container class="pt-0">
          <v-row dense>
            <v-col class="pl-0">
              <v-btn
                @click="saveSourceUrl"
                color="success"
                text
                data-test="save-source-url"
              >
                Save
              </v-btn>
            </v-col>
          </v-row>
          <v-alert v-model="errorSaving" type="error" dismissible dense>
            Error saving
          </v-alert>
          <v-alert v-model="successSaving" type="success" dismissible dense>
            Saved! (Refresh the page to see changes)
          </v-alert>
        </v-container>
      </v-card-actions>
    </v-card>
    <v-divider />
    <v-card>
      <v-card-title> Rubygems URL </v-card-title>
      <v-card-subtitle>
        This sets the URL for installing dependency rubygems. Also used for
        rubygem discovery.
      </v-card-subtitle>
      <v-card-text class="pb-0 ml-2">
        <v-text-field
          label="Rubygems URL"
          v-model="rubygemsUrl"
          data-test="rubygems-url"
        />
      </v-card-text>
      <v-card-actions>
        <v-container class="pt-0">
          <v-row dense>
            <v-col class="pl-0">
              <v-btn
                @click="saveRubygemsUrl"
                color="success"
                text
                data-test="save-rubygems-url"
              >
                Save
              </v-btn>
            </v-col>
          </v-row>
          <v-alert v-model="errorSaving" type="error" dismissible dense>
            Error saving
          </v-alert>
          <v-alert v-model="successSaving" type="success" dismissible dense>
            Saved! (Refresh the page to see changes)
          </v-alert>
        </v-container>
      </v-card-actions>
    </v-card>
  </div>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import ClassificationBannerSettings from '@/tools/CosmosAdmin/ClassificationBannerSettings.vue'

export default {
  components: {
    ClassificationBannerSettings,
  },
  data() {
    return {
      api: new CosmosApi(),
      suppressedWarnings: [],
      selectedSuppressedWarnings: [],
      selectAllSuppressedWarnings: false,
      lastConfigs: [],
      selectedLastConfigs: [],
      selectAllLastConfigs: false,
      sourceUrl: '',
      rubygemsUrl: '',
      errorSaving: false,
      successSaving: false,
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
    this.loadSourceUrl()
    this.loadRubygemsUrl()
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
    clearLastConfigs: function () {
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
    loadSourceUrl: function () {
      this.api
        .get_setting('source_url')
        .then((response) => {
          this.sourceUrl = response
        })
        .catch(() => {
          this.sourceUrl = 'https://github.com/BallAerospace/COSMOS'
        })
    },
    saveSourceUrl: function () {
      this.api
        .save_setting('source_url', this.sourceUrl)
        .then((response) => {
          this.errorSaving = false
          this.successSaving = true
        })
        .catch((error) => {
          this.errorSaving = true
        })
    },
    loadRubygemsUrl: function () {
      this.api
        .get_setting('rubygems_url')
        .then((response) => {
          this.rubygemsUrl = response
        })
        .catch(() => {
          this.rubygemsUrl = 'https://rubygems.org'
        })
    },
    saveRubygemsUrl: function () {
      this.api
        .save_setting('rubygems_url', this.rubygemsUrl)
        .then((response) => {
          this.errorSaving = false
          this.successSaving = true
        })
        .catch((error) => {
          this.errorSaving = true
        })
    },
  },
}
</script>
