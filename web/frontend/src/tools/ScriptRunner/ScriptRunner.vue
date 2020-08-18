<template>
  <div>
    <app-nav />
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
import ScriptsTab from '@/tools/ScriptRunner/ScriptsTab'
import RunningScriptsTab from '@/tools/ScriptRunner/RunningScriptsTab'

export default {
  components: {
    AppNav,
    ScriptsTab,
    RunningScriptsTab
  },
  data() {
    return {
      title: 'ScriptRunner',
      curTab: null,
      tabs: [
        { name: 'Scripts', component: 'ScriptsTab' },
        { name: 'Running Scripts', component: 'RunningScriptsTab' }
      ]
    }
  },
  created() {},
  methods: {}
}
</script>

<style scoped>
.v-card >>> .v-tabs-bar {
  background-color: var(--v-tertiary-darken2);
}
</style>
