<!--
# Copyright 2022 Ball Aerospace & Technologies Corp.
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
    <v-row no-gutters align="center" class="px-2">
      <v-col>
        <v-file-input
          v-model="file"
          show-size
          accept=".gem"
          class="mx-2"
          label="Click to select plugin .gem file to install"
          ref="fileInput"
          @change="fileChange()"
          @mousedown="fileMousedown()"
        />
      </v-col>
    </v-row>
    <v-row no-gutters class="px-2 pb-2">
      <v-spacer />
      <v-btn
        @click="showDownloadDialog = true"
        class="mx-2"
        data-test="pluginDownload"
        :disabled="file !== null"
      >
        <v-icon left>mdi-cloud-download</v-icon>
        <span> Download </span>
      </v-btn>
    </v-row>
    <v-row no-gutters class="px-2 pb-2" style="margin-top:10px;">
      <v-checkbox
        v-model="showDefaultTools"
        label="Show Default Tools"
        class="mt-0"
        data-test="show-default-tools"
      />
    </v-row>
    <!-- TODO This alert shows both success and failure. Make consistent with rest of COSMOS. -->
    <v-alert
      dismissible
      transition="scale-transition"
      :type="alertType"
      v-model="showAlert"
      >{{ alert }}</v-alert
    >
    <v-list v-if="Object.keys(processes).length > 0" data-test="processList">
      <div v-for="process in processes" :key="process.name">
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title>
              <span
                v-text="`Installing: ${process.detail} - ${process.state}`"
              />
            </v-list-item-title>
            <v-list-item-subtitle>
              <span v-text="' Updated At: ' + formatDate(process.updated_at)"
            /></v-list-item-subtitle>
          </v-list-item-content>
          <v-list-item-icon>
            <div v-if="process.state === 'Running'">
              <v-progress-circular indeterminate color="primary" />
            </div>
            <v-tooltip v-else bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon @click="showOutput(process)" v-bind="attrs" v-on="on">
                  mdi-eye
                </v-icon>
              </template>
              <span>Show Output</span>
            </v-tooltip>
          </v-list-item-icon>
        </v-list-item>
        <v-divider />
      </div>
    </v-list>
    <v-list data-test="pluginList">
      <div v-for="(plugin, index) in shownPlugins" :key="index">
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title>{{ plugin }}</v-list-item-title>
          </v-list-item-content>
          <v-list-item-icon>
            <div class="mx-3">
              <v-tooltip bottom>
                <template v-slot:activator="{ on, attrs }">
                  <v-icon @click="editPlugin(plugin)" v-bind="attrs" v-on="on">
                    mdi-pencil
                  </v-icon>
                </template>
                <span>Edit Plugin Details</span>
              </v-tooltip>
            </div>
            <div class="mx-3">
              <v-tooltip bottom>
                <template v-slot:activator="{ on, attrs }">
                  <v-icon
                    @click="upgradePlugin(plugin)"
                    v-bind="attrs"
                    v-on="on"
                  >
                    mdi-update
                  </v-icon>
                </template>
                <span>Upgrade Plugin</span>
              </v-tooltip>
            </div>
            <div class="mx-3">
              <v-tooltip bottom>
                <template v-slot:activator="{ on, attrs }">
                  <v-icon
                    @click="deletePlugin(plugin)"
                    v-bind="attrs"
                    v-on="on"
                  >
                    mdi-delete
                  </v-icon>
                </template>
                <span>Delete Plugin</span>
              </v-tooltip>
            </div>
          </v-list-item-icon>
        </v-list-item>
        <v-divider v-if="index < plugins.length - 1" :key="index" />
      </div>
    </v-list>
    <plugin-dialog
      v-model="showPluginDialog"
      :plugin_name="plugin_name"
      :variables="variables"
      :plugin_txt="plugin_txt"
      :existing_plugin_txt="existing_plugin_txt"
      @submit="pluginCallback"
    />
    <download-dialog v-model="showDownloadDialog" />
    <simple-text-dialog
      v-model="showProcessOutput"
      title="Process Output"
      :text="processOutput"
    />
  </div>
</template>

<script>
import { toDate, format } from 'date-fns'
import Api from '@cosmosc2/tool-common/src/services/api'
import DownloadDialog from '@/tools/CosmosAdmin/DownloadDialog'
import EditDialog from '@/tools/CosmosAdmin/EditDialog'
import PluginDialog from '@/tools/CosmosAdmin/PluginDialog'
import SimpleTextDialog from '@cosmosc2/tool-common/src/components/SimpleTextDialog'

export default {
  components: {
    DownloadDialog,
    PluginDialog,
    SimpleTextDialog,
  },
  data() {
    return {
      file: null,
      pluginToUpgrade: null,
      plugins: [],
      processes: {},
      alert: '',
      alertType: 'success',
      showAlert: false,
      plugin_name: null,
      variables: {},
      plugin_txt: "",
      existing_plugin_txt: null,
      showDownloadDialog: false,
      showProcessOutput: false,
      processOutput: '',
      showPluginDialog: false,
      showDefaultTools: false,
      defaultPlugins: [
        'cosmosc2-tool-admin',
        'cosmosc2-tool-autonomic',
        'cosmosc2-tool-base',
        'cosmosc2-tool-calendar',
        'cosmosc2-tool-cmdsender',
        'cosmosc2-tool-cmdtlmserver',
        'cosmosc2-tool-dataextractor',
        'cosmosc2-tool-dataviewer',
        'cosmosc2-tool-limitsmonitor',
        'cosmosc2-tool-packetviewer',
        'cosmosc2-tool-scriptrunner',
        'cosmosc2-tool-tablemanager',
        'cosmosc2-tool-tlmgrapher',
        'cosmosc2-tool-tlmviewer',
      ]
    }
  },
  computed: {
    shownPlugins() {
      let result = []
      for (let plugin of this.plugins) {
        let plugin_name_first = plugin.split("__")[0]
        let plugin_name_split = plugin_name_first.split("-")
        plugin_name_split = plugin_name_split.slice(0, -1)
        let plugin_name = plugin_name_split.join("-")
        if ((!(this.defaultPlugins.includes(plugin_name))) || (this.showDefaultTools)) {
          result.push(plugin)
        }
      }
      return result
    }
  },
  mounted() {
    this.update()
    this.updateProcesses()
  },
  methods: {
    showOutput: function (process) {
      this.processOutput = process.output
      this.showProcessOutput = true
    },
    update: function () {
      Api.get('/cosmos-api/plugins').then((response) => {
        this.plugins = response.data
      })
    },
    updateProcesses: function () {
      Api.get('/cosmos-api/process_status/plugin_install').then((response) => {
        this.processes = response.data
        if (Object.keys(this.processes).length > 0) {
          setTimeout(() => {
            this.updateProcesses()
            this.update()
          }, 10000)
        }
      })
    },
    formatDate(nanoSecs) {
      return format(
        toDate(parseInt(nanoSecs) / 1_000_000),
        'yyyy-MM-dd HH:mm:ss.SSS'
      )
    },
    upload: function (existing = null) {
      const method = existing ? 'put' : 'post'
      const path = existing
        ? `/cosmos-api/plugins/${existing}`
        : '/cosmos-api/plugins'
      const formData = new FormData()
      formData.append('plugin', this.file, this.file.name)
      const promise = Api[method](path, { data: formData })
      promise.then((response) => {
          this.alert = 'Uploaded file'
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
          let existing_plugin_txt = null
          if (response.data.existing_plugin_txt_lines !== undefined) {
            existing_plugin_txt = response.data.existing_plugin_txt_lines.join("\n")
          }
          let plugin_txt = response.data.plugin_txt_lines.join("\n")
          this.plugin_name = response.data.name,
          this.variables = response.data.variables,
          this.plugin_txt = plugin_txt,
          this.existing_plugin_txt = existing_plugin_txt
          this.showPluginDialog = true
          this.file = undefined
        })
        .catch((error) => {
          this.pluginToUpgrade = null
          this.file = undefined
        })
    },
    pluginCallback: function (plugin_hash) {
      this.showPluginDialog = false
      if (this.pluginToUpgrade !== null) {
        plugin_hash['name'] = this.pluginToUpgrade
      }
      const promise = Api.post(`/cosmos-api/plugins/install/${this.plugin_name}`, {
          data: {
            plugin_hash: JSON.stringify(plugin_hash),
          },
        })
      promise.then((response) => {
          this.alert = "Started installing plugin"
          this.alertType = 'success'
          this.showAlert = true
          this.pluginToUpgrade = null
          this.file = undefined
          this.variables = {}
          this.plugin_txt = ""
          this.existing_plugin_txt = null
          setTimeout(() => {
            this.showAlert = false
            this.updateProcesses()
          }, 5000)
          this.update()
        })
    },
    editPlugin: function (name) {
      Api.get(`/cosmos-api/plugins/${name}`).then((response) => {
        let existing_plugin_txt = null
        if (response.data.existing_plugin_txt_lines !== undefined) {
          existing_plugin_txt = response.data.existing_plugin_txt_lines.join("\n")
        }
        let plugin_txt = response.data.plugin_txt_lines.join("\n")
        this.plugin_name = response.data.name,
        this.variables = response.data.variables,
        this.plugin_txt = plugin_txt,
        this.existing_plugin_txt = existing_plugin_txt
        this.showPluginDialog = true
      })
    },
    deletePlugin: function (plugin) {
      this.$dialog
        .confirm(`Are you sure you want to remove: ${plugin}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          return Api.delete(`/cosmos-api/plugins/${plugin}`)
        })
        .then((response) => {
          this.alert = `Removed plugin ${plugin}`
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
    },
    upgradePlugin(plugin) {
      this.file = undefined
      this.pluginToUpgrade = plugin
      this.$refs.fileInput.$refs.input.click()
    },
    fileMousedown() {
      this.pluginToUpgrade = null
    },
    fileChange() {
      if (this.file !== undefined) {
        if (this.pluginToUpgrade !== null) {
          this.upload(this.pluginToUpgrade)
        } else {
          this.upload()
        }
      }
    }
  },
}
</script>
