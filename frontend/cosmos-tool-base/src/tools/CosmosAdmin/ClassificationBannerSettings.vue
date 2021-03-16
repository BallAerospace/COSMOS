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
  <v-card>
    <v-card-title>Classification Banner Settings</v-card-title>
    <v-card-text>
      <v-container>
        <v-row dense>
          <v-col>
            <v-text-field label="Text" v-model="text" />
          </v-col>
          <v-col>
            <v-select label="Color" :items="colors" v-model="selectedColor">
              <template v-slot:prepend-inner v-if="selectedColor">
                <v-icon :color="selectedColor"> mdi-square </v-icon>
              </template>
              <template slot="item" slot-scope="data">
                <v-icon
                  :color="data.item.value"
                  v-if="data.item.value"
                  class="pr-1"
                >
                  mdi-square
                </v-icon>
                {{ data.item.text }}
              </template>
            </v-select>
          </v-col>
          <v-col>
            <v-text-field
              label="Custom color"
              :hint="customColorHint"
              v-show="!selectedColor"
              v-model="customColor"
              :rules="[rules.customColor]"
            >
              <template v-slot:prepend-inner>
                <v-icon :color="customColor"> mdi-square </v-icon>
              </template>
            </v-text-field>
          </v-col>
        </v-row>
        <v-row>
          <v-col>
            <v-switch label="Display top banner" v-model="displayTopBanner" />
          </v-col>
          <v-col>
            <v-text-field
              label="Top height"
              :disabled="!displayTopBanner"
              type="number"
              suffix="px"
              v-model="topHeight"
            />
          </v-col>
          <v-col>
            <v-switch
              label="Display bottom banner"
              v-model="displayBottomBanner"
            />
          </v-col>
          <v-col>
            <v-text-field
              label="Bottom height"
              :disabled="!displayBottomBanner"
              type="number"
              suffix="px"
              v-model="bottomHeight"
            />
          </v-col>
        </v-row>
      </v-container>
    </v-card-text>
    <v-card-actions>
      <v-btn :disabled="!formValid" @click="save"> Save </v-btn>
    </v-card-actions>
  </v-card>
</template>

<script>
import axios from 'axios'
import { CosmosApi } from '@/services/cosmos-api'

const settingName = 'classification_banner'
export default {
  data() {
    return {
      api: null,
      text: '',
      displayTopBanner: false,
      displayBottomBanner: false,
      topHeight: 0,
      bottomHeight: 0,
      selectedColor: 'red',
      customColor: '',
      customColorHint: 'Enter a 3 or 6-digit hex color code',
      colors: [
        {
          text: 'Yellow',
          value: 'yellow',
        },
        {
          text: 'Orange',
          value: 'orange',
        },
        {
          text: 'Red',
          value: 'red',
        },
        {
          text: 'Purple',
          value: 'purple',
        },
        {
          text: 'Blue',
          value: 'blue',
        },
        {
          text: 'Green',
          value: 'green',
        },
        {
          text: 'Custom',
          value: false,
        },
      ],
      rules: {
        customColor: (value) => {
          return (
            /^#(?:[0-9a-fA-F]{3}){1,2}$/.test(value) || this.customColorHint
          )
        },
      },
    }
  },
  computed: {
    saveObj: function () {
      return JSON.stringify({
        text: this.text,
        color: this.selectedColor || this.customColor,
        topHeight: this.displayTopBanner ? this.topHeight : 0,
        bottomHeight: this.displayBottomBanner ? this.bottomHeight : 0,
      })
    },
    formValid: function () {
      return (
        this.selectedColor || this.rules.customColor(this.customColor) === true
      )
    },
  },
  watch: {
    customColor: function (val) {
      if (val && val.length && !val.startsWith('#')) {
        this.customColor = `#${val}`
      }
    },
  },
  created() {
    this.api = new CosmosApi()
    this.load()
  },
  methods: {
    load: function () {
      this.api.get_setting(settingName).then((response) => {
        if (response) {
          const parsed = JSON.parse(response)
          this.text = parsed.text
          this.topHeight = parsed.topHeight
          this.bottomHeight = parsed.bottomHeight
          this.displayTopBanner = parsed.topHeight !== 0
          this.displayBottomBanner = parsed.bottomHeight !== 0
          if (parsed.color.startsWith('#')) {
            this.customColor = parsed.color
            this.selectedColor = false
          } else {
            this.selectedColor = parsed.color
          }
        }
      }).catch((error) => {
        console.error('error loading:', error)
      })
    },
    save: function () {
      this.api.save_setting(settingName, this.saveObj).then((response) => {
        console.log('saved', response)
      }).catch((error) => {
        console.error('error saving:', error)
      })
    },
  },
}
</script>
