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
    <v-overlay :value="showUserMenu" class="overlay" />
    <v-menu
      v-model="showUserMenu"
      transition="slide-y-transition"
      offset-y
      :close-on-content-click="false"
      :nudge-width="120"
      :nudge-bottom="20"
    >
      <template v-slot:activator="{ on, attrs }">
        <v-btn v-bind="attrs" v-on="on" icon>
          <v-icon :size="size"> mdi-account </v-icon>
        </v-btn>
      </template>

      <v-card>
        <v-card-text class="text-center">
          <div v-if="authenticated">
            <v-btn block @click="logout" color="primary"> Logout </v-btn>
          </div>
          <div v-else>
            <v-btn block @click="login" color="primary"> Login </v-btn>
          </div>
          <div>
            <v-switch label="Colorblind mode" v-model="colorblindMode" />
          </div>
        </v-card-text>
      </v-card>
    </v-menu>
  </div>
</template>

<script>
export default {
  props: {
    size: {
      type: [String, Number],
      default: 26,
    },
  },
  data: function () {
    return {
      showUserMenu: false,
      authenticated: !!localStorage.token,
    }
  },
  computed: {
    colorblindMode: {
      get: function () {
        return localStorage.colorblindMode === 'true'
      },
      set: function (val) {
        localStorage.colorblindMode = val
      },
    },
  },
  methods: {
    logout: function () {
      CosmosAuth.logout()
    },
    login: function () {
      CosmosAuth.login(location.href)
    },
  },
}
</script>

<style scoped>
.overlay {
  height: 100vh;
  width: 100vw;
}
</style>
