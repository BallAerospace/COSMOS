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
import GemsTab from '@/tools/CosmosAdmin/GemsTab'
import ToolsTab from '@/tools/CosmosAdmin/ToolsTab'
import TargetsTab from '@/tools/CosmosAdmin/TargetsTab'
import InterfacesTab from '@/tools/CosmosAdmin/InterfacesTab'
import RoutersTab from '@/tools/CosmosAdmin/RoutersTab'
import MicroservicesTab from '@/tools/CosmosAdmin/MicroservicesTab'
export default {
  components: {
    AppNav,
    PluginsTab,
    ScopesTab,
    GemsTab,
    ToolsTab,
    TargetsTab,
    InterfacesTab,
    RoutersTab,
    MicroservicesTab
  },
  data() {
    return {
      curTab: null,
      tabs: [
        { name: 'Plugins', component: 'PluginsTab' },
        { name: 'Targets', component: 'TargetsTab' },
        { name: 'Interfaces', component: 'InterfacesTab' },
        { name: 'Routers', component: 'RoutersTab' },
        { name: 'Microservices', component: 'MicroservicesTab' },
        { name: 'Tools', component: 'ToolsTab' },
        { name: 'Gems', component: 'GemsTab' },
        { name: 'Scopes', component: 'ScopesTab' }
      ]
    }
  },
  methods: {}
}
</script>
