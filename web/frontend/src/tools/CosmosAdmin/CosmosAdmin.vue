<template>
  <div>
    <app-nav app />
    <h1>COSMOS Administrator Console</h1>
    <v-card>
      <v-tabs v-model="curTab" fixed-tabs>
        <v-tab v-for="(tab, index) in tabs" :key="index">{{ tab.name }}</v-tab>
      </v-tabs>
      <v-tabs-items v-model="curTab">
        <v-tab-item v-for="(tab, index) in tabs" :key="index">
          <component
            :is="tab.component"
            v-bind:tabId="index"
            v-bind:curTab="curTab"
          ></component>
        </v-tab-item>
      </v-tabs-items>
    </v-card>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import PluginsTab from '@/tools/CosmosAdmin/PluginsTab'
import ScopesTab from '@/tools/CosmosAdmin/ScopesTab'
export default {
  components: {
    AppNav,
    PluginsTab,
    ScopesTab
  },
  data() {
    return {
      curTab: null,
      tabs: [
        { name: 'Plugins', component: 'PluginsTab' },
        { name: 'Targets', component: 'PluginsTab' },
        { name: 'Interfaces', component: 'PluginsTab' },
        { name: 'Routers', component: 'PluginsTab' },
        { name: 'Microservices', component: 'PluginsTab' },
        { name: 'Tools', component: 'PluginsTab' },
        { name: 'Gems', component: 'PluginsTab' },
        { name: 'Scopes', component: 'ScopesTab' }
      ]
    }
  },
  methods: {}
}
</script>
