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
