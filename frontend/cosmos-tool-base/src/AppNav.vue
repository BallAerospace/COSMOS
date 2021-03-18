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
    <v-navigation-drawer v-model="drawer" app>
      <v-list>
        <v-list-item two-line>
          <v-list-item-icon>
            <img src="/img/logo.png" alt="COSMOS" />
          </v-list-item-icon>
          <v-list-item-content>
            <v-list-item-title>COSMOS</v-list-item-title>
            <!-- v-list-item-subtitle>Enterprise Edition</v-list-item-subtitle -->
          </v-list-item-content>
        </v-list-item>
        <v-divider></v-divider>
        <v-list-item v-for="(tool, name) in shownTools" :key="name">
          <router-link :to="tool.url">
            <v-list-item-icon>
              <v-icon>{{ tool.icon }}</v-icon>
            </v-list-item-icon>
          </router-link>

          <v-list-item-content>
            <router-link :to="tool.url">
              <v-list-item-title>{{ name }}</v-list-item-title>
            </router-link>
          </v-list-item-content>

          <v-list-item-icon>
            <a :href="tool.url" target="_blank"
              ><v-icon>mdi-arrow-top-right-thin-circle-outline</v-icon></a
            >
          </v-list-item-icon>
        </v-list-item>
      </v-list>

      <template v-slot:append>
        <div class="pa-2">
          <v-btn
            block
            small
            rounded
            color="primary"
            href="/admin"
            target="_blank"
            >Admin</v-btn
          >
        </div>
      </template>
    </v-navigation-drawer>

    <v-app-bar app color="tertiary darken-3">
      <v-app-bar-nav-icon @click="drawer = !drawer"></v-app-bar-nav-icon>
      <v-menu offset-y v-for="(menu, i) in menus" :key="i">
        <template v-slot:activator="{ on }">
          <v-btn icon v-on="on">{{ menu.label }}</v-btn>
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
              <v-divider v-if="option.divider" :key="j"></v-divider>
              <v-list-item v-else :key="j" @click="option.command">
                <v-list-item-action v-if="option.radio">
                  <v-radio
                    color="secondary"
                    :label="option.label"
                    :value="option.label"
                  ></v-radio>
                </v-list-item-action>
                <v-list-item-action v-if="option.checkbox">
                  <v-checkbox
                    color="secondary"
                    :label="option.label"
                    :value="option.label"
                    v-model="checked"
                  ></v-checkbox>
                </v-list-item-action>
                <v-list-item-icon v-if="option.icon">
                  <v-icon v-text="option.icon"></v-icon>
                </v-list-item-icon>
                <v-list-item-title
                  v-if="!option.radio && !option.checkbox"
                  style="cursor: pointer"
                  >{{ option.label }}</v-list-item-title
                >
              </v-list-item>
            </template>
          </v-radio-group>
        </v-list>
      </v-menu>
      <v-spacer />
      <v-toolbar-title>{{ $route.meta.title }}</v-toolbar-title>
      <v-spacer />
      <rux-clock />
    </v-app-bar>
  </div>
</template>

<script>
import '@astrouxds/rux-clock'
import '@astrouxds/rux-global-status-bar'
import Api from '@/services/api'

export default {
  props: {
    menus: {
      type: Array,
      default: () => [],
    },
  },
  data() {
    return {
      drawer: true,
      appNav: {},
      checked: [],
    }
  },
  computed: {
    // a computed getter
    shownTools: function () {
      let result = {}
      for (var key of Object.keys(this.appNav)) {
        if (this.appNav[key].shown) {
          result[key] = this.appNav[key]
        }
      }
      return result
    },
  },
  created() {
    // Determine if any of the checkboxes should be initially checked
    this.menus.forEach((menu) => {
      menu.items.forEach((item) => {
        if (item.checked) {
          this.checked.push(item.label)
        }
      })
    })
    Api.get('/cosmos-api/tools/all')
      .then((response) => {
        this.appNav = response.data
      })
      .catch((error) => {
        this.alert = error
        this.alertType = 'error'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      })
  },
}
</script>

<style scoped>
.v-list >>> .v-label {
  margin-left: 5px;
}
.theme--dark.v-navigation-drawer {
  background-color: var(--v-primary-darken2);
}
.v-list-item__icon {
  /* For some reason the default margin-right is huge */
  margin-right: 15px !important;
}
.v-list-item__title {
  color: white;
}
</style>
