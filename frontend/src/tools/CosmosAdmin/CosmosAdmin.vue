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
    <app-nav app />
    <h1>COSMOS Administrator Console</h1>
    <v-card>
      <v-tabs v-model="curTab" fixed-tabs>
        <v-tab v-for="(tab, index) in tabs" :key="index" :to="tab.url">{{
          tab.name
        }}</v-tab>
      </v-tabs>
      <router-view />
    </v-card>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
export default {
  components: {
    AppNav,
  },
  data() {
    return {
      curTab: null,
      tabs: [
        { name: 'Plugins', component: 'PluginsTab', url: '/admin/plugins' },
        { name: 'Targets', component: 'TargetsTab', url: '/admin/targets' },
        {
          name: 'Interfaces',
          component: 'InterfacesTab',
          url: '/admin/interfaces',
        },
        { name: 'Routers', component: 'RoutersTab', url: '/admin/routers' },
        {
          name: 'Microservices',
          component: 'MicroservicesTab',
          url: '/admin/microservices',
        },
        { name: 'Tools', component: 'ToolsTab', url: '/admin/tools' },
        { name: 'Gems', component: 'GemsTab', url: '/admin/gems' },
        { name: 'Scopes', component: 'ScopesTab', url: '/admin/scopes' },
      ],
    }
  },
  methods: {},
}
</script>
