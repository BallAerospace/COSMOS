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
  <mounting-portal mount-to="#cosmos-menu" append>
    <div class="v-toolbar__content">
      <v-menu offset-y v-for="(menu, i) in menus" :key="i">
        <template v-slot:activator="{ on, attrs }">
          <v-btn
            outlined
            v-bind="attrs"
            v-on="on"
            class="mx-1"
            :data-test="`${title}-${menu.label}`"
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
              <v-divider v-if="option.divider" :key="j" />
              <v-list-item
                v-else
                @click="option.command"
                :key="j"
                :disabled="option.disabled"
                :data-test="`${title}-${menu.label}-${option.label}`"
              >
                <v-list-item-action
                  v-if="option.radio"
                  :disabled="option.disabled"
                >
                  <v-radio
                    color="secondary"
                    :label="option.label"
                    :value="option.label"
                  />
                </v-list-item-action>
                <v-list-item-action
                  v-if="option.checkbox"
                  :disabled="option.disabled"
                >
                  <v-checkbox
                    v-model="checked"
                    color="secondary"
                    :label="option.label"
                    :value="option.label"
                  />
                </v-list-item-action>
                <v-list-item-icon v-if="option.icon">
                  <v-icon v-text="option.icon" :disabled="option.disabled" />
                </v-list-item-icon>
                <v-list-item-title
                  v-if="!option.radio && !option.checkbox"
                  :style="
                    'cursor: pointer;' + (option.disabled ? 'opacity: 0.2' : '')
                  "
                  :disabled="option.disabled"
                  v-text="option.label"
                />
              </v-list-item>
            </template>
          </v-radio-group>
        </v-list>
      </v-menu>
      <v-spacer />
      <v-toolbar-title v-text="title" />
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
