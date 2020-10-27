<template>
  <div>
    <app-nav :menus="menus" />
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
import EditorTab from '@/tools/ScriptRunner/EditorTab'
import ScriptRunnerEditor from '@/tools/ScriptRunner/ScriptRunnerEditor'
import ScriptsTab from '@/tools/ScriptRunner/ScriptsTab'
import RunningScriptsTab from '@/tools/ScriptRunner/RunningScriptsTab'

export default {
  components: {
    AppNav,
    EditorTab,
    ScriptRunnerEditor,
    ScriptsTab,
    RunningScriptsTab
  },
  data() {
    return {
      title: 'ScriptRunner',
      curTab: null,
      tabs: [
        { name: 'Editor', component: 'EditorTab' },
        { name: 'Scripts', component: 'ScriptsTab' },
        { name: 'Running Scripts', component: 'RunningScriptsTab' }
      ],
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'New File',
              icon: 'mdi-file-plus',
              command: () => {
                this.$root.$refs.Editor.newFile()
              }
            },
            {
              label: 'Open File',
              icon: 'mdi-folder-open',
              command: () => {
                this.$root.$refs.Editor.openFile()
              }
            },
            {
              divider: true
            },
            {
              label: 'Save File',
              icon: 'mdi-content-save',
              command: () => {
                this.$root.$refs.Editor.saveFile()
              }
            },
            {
              label: 'Save As...',
              icon: 'mdi-content-save',
              command: () => {
                this.$root.$refs.Editor.saveAs()
              }
            },
            {
              divider: true
            },
            {
              label: 'Delete File',
              icon: 'mdi-delete',
              command: () => {
                this.$root.$refs.Editor.delete()
              }
            }
          ]
        }
      ]
    }
  }
}
</script>

<style scoped>
.v-card >>> .v-tabs-bar {
  background-color: var(--v-tertiary-darken2);
}
</style>
