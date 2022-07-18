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
  <mounting-portal mount-to="#openc3-menu" append>
    <div class="v-toolbar__content">
      <v-menu offset-y v-for="(menu, i) in menus" :key="i">
        <template v-slot:activator="{ on, attrs }">
          <v-btn
            outlined
            v-bind="attrs"
            v-on="on"
            class="mx-1"
            :data-test="formatDT(`${title} ${menu.label}`)"
          >
            <span v-text="menu.label" />
            <v-icon right> mdi-menu-down </v-icon>
          </v-btn>
        </template>
        <v-list>
          <!-- The radio-group is necessary in case the application wants radio buttons -->
          <v-radio-group
            :value="menu.radioGroup"
            hide-details
            dense
            class="ma-0 pa-0"
          >
            <template v-for="(option, j) in menu.items">
              <v-divider v-if="option.divider" />
              <v-list-item
                v-else
                @click="option.command"
                :disabled="option.disabled"
                :data-test="formatDT(`${title} ${menu.label} ${option.label}`)"
                :key="j"
              >
                <v-list-item-action v-if="option.radio">
                  <v-radio
                    color="secondary"
                    :label="option.label"
                    :value="option.label"
                  />
                </v-list-item-action>
                <v-list-item-action v-if="option.checkbox">
                  <v-checkbox
                    v-model="checked"
                    color="secondary"
                    :label="option.label"
                    :value="option.label"
                  />
                </v-list-item-action>
                <v-list-item-icon v-if="option.icon">
                  <v-icon :disabled="option.disabled">{{ option.icon }}</v-icon>
                </v-list-item-icon>
                <v-list-item-title
                  v-if="!option.radio && !option.checkbox"
                  :style="
                    'cursor: pointer;' + (option.disabled ? 'opacity: 0.2' : '')
                  "
                  >{{ option.label }}</v-list-item-title
                >
              </v-list-item>
            </template>
          </v-radio-group>
        </v-list>
      </v-menu>
      <v-spacer />
      <v-toolbar-title>{{ title }}</v-toolbar-title>
      <v-spacer />
    </div>
  </mounting-portal>
</template>

<script>
export default {
  props: {
    menus: {
      type: Array,
      default: function () {
        return []
      },
    },
    title: {
      type: String,
      default: '',
    },
  },
  methods: {
    // Convert the string to a standard data-test format
    formatDT: function (string) {
      return string.replaceAll(' ', '-').toLowerCase()
    },
  },
}
</script>

<style scoped>
.v-list >>> .v-label {
  margin-left: 5px;
}
.v-list-item__icon {
  /* For some reason the default margin-right is huge */
  margin-right: 15px !important;
}
.v-list-item__title {
  color: white;
}
</style>
