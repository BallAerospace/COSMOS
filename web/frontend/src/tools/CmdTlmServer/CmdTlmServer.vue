<template>
  <div>
    <app-nav app :menus="menus" />
    <v-card>
      <v-tabs v-model="curTab" fixed-tabs>
        <v-tab v-for="(tab, index) in tabs" :key="index" :to="tab.url">{{
          tab.name
        }}</v-tab>
      </v-tabs>
      <router-view :refreshInterval="refreshInterval" />
      <v-dialog v-model="optionsDialog" max-width="300">
        <v-card class="pa-3">
          <v-card-title class="headline">Options</v-card-title>
          <v-text-field
            min="0"
            max="10000"
            step="100"
            type="number"
            label="Refresh Interval (ms)"
            :value="refreshInterval"
            @change="refreshInterval = $event"
          ></v-text-field>
        </v-card>
      </v-dialog>
    </v-card>
    <div style="height: 20px" />
    <LogMessages />
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import LogMessages from '@/components/LogMessages'
export default {
  components: {
    AppNav,
    LogMessages,
  },
  data() {
    return {
      title: 'CmdTlmServer',
      curTab: null,
      tabs: [
        {
          name: 'Interfaces',
          url: '/cmd-tlm-server/interfaces',
        },
        {
          name: 'Targets',
          url: '/cmd-tlm-server/targets',
        },
        {
          name: 'Cmd Packets',
          url: '/cmd-tlm-server/cmd-packets',
        },
        {
          name: 'Tlm Packets',
          url: '/cmd-tlm-server/tlm-packets',
        },
        // TODO: Remove these until they work
        // { name: 'Routers', component: 'RoutersTab' },
        // { name: 'Logging', component: 'LoggingTab' },
        {
          name: 'Status',
          url: '/cmd-tlm-server/status',
        },
      ],
      updater: null,
      refreshInterval: 1000,
      optionsDialog: false,
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Options',
              command: () => {
                this.optionsDialog = true
              },
            },
          ],
        },
      ],
    }
  },
}
</script>

<style scoped></style>
