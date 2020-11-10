<template>
  <div>
    <app-nav :menus="menus" />
    <v-card>
      <v-tabs v-model="curTab" fixed-tabs>
        <v-tab v-for="(tab, index) in tabs" :key="index">{{ tab.name }}</v-tab>
      </v-tabs>
      <v-tabs-items v-model="curTab">
        <v-tab-item v-for="(tab, index) in tabs" :key="index">
          <!-- Store a ref to the component for use in calling methods -->
          <component
            :ref="tab.component"
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
import EditorTab from '@/tools/ScriptRunner/EditorTab'
import RunningScriptsTab from '@/tools/ScriptRunner/RunningScriptsTab'

export default {
  components: {
    AppNav,
    EditorTab,
    RunningScriptsTab,
  },
  data() {
    return {
      title: 'ScriptRunner',
      curTab: null,
      tabs: [
        { name: 'Editor', component: 'EditorTab' },
        { name: 'Running Scripts', component: 'RunningScriptsTab' },
      ],
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'New File',
              icon: 'mdi-file-plus',
              command: () => {
                this.$refs.EditorTab[0].newFile()
              },
            },
            {
              label: 'Open File',
              icon: 'mdi-folder-open',
              command: () => {
                this.$refs.EditorTab[0].openFile()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Save File',
              icon: 'mdi-content-save',
              command: () => {
                this.$refs.EditorTab[0].saveFile()
              },
            },
            {
              label: 'Save As...',
              icon: 'mdi-content-save',
              command: () => {
                this.$refs.EditorTab[0].saveAs()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Download',
              icon: 'mdi-cloud-download',
              command: () => {
                this.$refs.EditorTab[0].download()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Delete File',
              icon: 'mdi-delete',
              command: () => {
                this.$refs.EditorTab[0].delete()
              },
            },
          ],
        },
        {
          label: 'Script',
          items: [
            {
              label: 'Ruby Syntax Check',
              icon: 'mdi-language-ruby',
              command: () => {
                this.$refs.EditorTab[0].rubySyntaxCheck()
              },
            },
            {
              label: 'Show Call Stack',
              icon: 'mdi-format-list-numbered',
              command: () => {
                this.$refs.EditorTab[0].showCallStack()
              },
            },
            {
              divider: true,
            },
            {
              label: 'Toggle Debug',
              icon: 'mdi-bug',
              command: () => {
                this.$refs.EditorTab[0].toggleDebug()
              },
            },
            {
              label: 'Toggle Disconnect',
              icon: 'mdi-connection',
              command: () => {
                this.$refs.EditorTab[0].toggleDisconnect()
              },
            },
          ],
        },
      ],
    }
  },
}
</script>

<style scoped>
.v-card >>> .v-tabs-bar {
  background-color: var(--v-tertiary-darken2);
}
</style>
