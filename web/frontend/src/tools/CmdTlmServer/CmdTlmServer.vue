<template>
  <div>
    <app-nav app :menus="menus" />
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
            v-bind:refreshInterval="refreshInterval"
          ></component>
        </v-tab-item>
      </v-tabs-items>

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
    <div style="height:20px;" />
    <LogMessages />
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import InterfacesTab from '@/tools/CmdTlmServer/InterfacesTab'
import TargetsTab from '@/tools/CmdTlmServer/TargetsTab'
import CmdPacketsTab from '@/tools/CmdTlmServer/CmdPacketsTab'
import TlmPacketsTab from '@/tools/CmdTlmServer/TlmPacketsTab'
import RoutersTab from '@/tools/CmdTlmServer/RoutersTab'
import LoggingTab from '@/tools/CmdTlmServer/LoggingTab'
import StatusTab from '@/tools/CmdTlmServer/StatusTab'
import LogMessages from '@/components/LogMessages'

export default {
  components: {
    AppNav,
    InterfacesTab,
    TargetsTab,
    CmdPacketsTab,
    TlmPacketsTab,
    RoutersTab,
    LoggingTab,
    StatusTab,
    LogMessages
  },
  data() {
    return {
      title: 'CmdTlmServer',
      curTab: null,
      tabs: [
        { name: 'Interfaces', component: 'InterfacesTab' },
        { name: 'Targets', component: 'TargetsTab' },
        { name: 'Cmd Packets', component: 'CmdPacketsTab' },
        { name: 'Tlm Packets', component: 'TlmPacketsTab' },
        { name: 'Routers', component: 'RoutersTab' },
        { name: 'Logging', component: 'LoggingTab' },
        { name: 'Status', component: 'StatusTab' }
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
              }
            }
          ]
        }
      ]
    }
  }
}
</script>

<style scoped></style>
