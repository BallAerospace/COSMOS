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
    <v-row no-gutters align="center" style="padding-left: 10px">
      <v-col cols="3">
        <v-btn
          block
          color="primary"
          data-test="toolAdd"
          @click="add()"
          :disabled="!name || !url || !icon"
        >
          Add
          <v-icon right dark v-text="icon" />
        </v-btn>
      </v-col>
      <v-col cols="3">
        <v-text-field v-model="icon" label="Tool Icon" class="px-2" />
      </v-col>
      <v-col cols="3">
        <v-text-field v-model="name" label="Tool Name" class="px-2" />
      </v-col>
      <v-col cols="3" class="px-2">
        <v-text-field v-model="url" label="Tool Url" />
      </v-col>
    </v-row>
    <v-alert
      :type="alertType"
      v-model="showAlert"
      dismissible
      transition="scale-transition"
    >
      {{ alert }}
    </v-alert>
    <v-list data-test="toolList" id="toollist">
      <div v-for="(tool, index) in tools" :key="tool">
        <v-list-item>
          <v-list-item-icon>
            <v-icon> mdi-drag-horizontal </v-icon>
          </v-list-item-icon>
          <v-list-item-content>
            <v-list-item-title v-text="tool" />
          </v-list-item-content>
          <v-list-item-icon>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon @click="editTool(tool)" v-bind="attrs" v-on="on">
                  mdi-pencil
                </v-icon>
              </template>
              <span>Edit Tool</span>
            </v-tooltip>
          </v-list-item-icon>
          <v-list-item-icon>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon @click="deleteTool(tool)" v-bind="attrs" v-on="on">
                  mdi-delete
                </v-icon>
              </template>
              <span>Delete Tool</span>
            </v-tooltip>
          </v-list-item-icon>
        </v-list-item>
        <v-divider v-if="index < tools.length - 1" :key="index" />
      </div>
    </v-list>
    <v-alert
      :type="alertType"
      v-model="showAlert"
      dismissible
      transition="scale-transition"
    >
      {{ alert }}
    </v-alert>
    <edit-dialog
      v-model="showDialog"
      v-if="showDialog"
      :content="jsonContent"
      :title="`Tool: ${dialogTitle}`"
      @submit="dialogCallback"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import EditDialog from '@/tools/CosmosAdmin/EditDialog'
import Sortable from 'sortablejs'

export default {
  components: { EditDialog },
  data() {
    return {
      name: null,
      icon: '$astro-add-small',
      url: null,
      tools: [],
      alert: '',
      alertType: 'success',
      showAlert: false,
      jsonContent: '',
      dialogTitle: '',
      showDialog: false,
      tool_id: null,
    }
  },
  mounted() {
    this.update()
    var el = document.getElementById('toollist')
    var sortable = Sortable.create(el, { onUpdate: this.sortChanged })
  },
  methods: {
    sortChanged(evt) {
      Api.post(`/cosmos-api/tools/position/${this.tools[evt.oldIndex]}`, {
        data: {
          position: evt.newIndex,
        },
        params: { scope: 'DEFAULT' },
      }).then((response) => {
        this.alert = `Reordered tool ${this.tools[evt.oldIndex]}`
        this.alertType = 'success'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
        this.update()
      })
    },
    update() {
      Api.get('/cosmos-api/tools', { params: { scope: 'DEFAULT' } }).then(
        (response) => {
          this.tools = response.data
          this.name = ''
          this.url = ''
        }
      )
    },
    add() {
      Api.post('/cosmos-api/tools', {
        data: {
          id: this.name,
          json: JSON.stringify({
            name: this.name,
            icon: this.icon,
            url: this.url,
            window: 'NEW',
          }),
        },
        params: { scope: 'DEFAULT' },
      }).then((response) => {
        this.alert = `Added tool ${this.name}`
        this.alertType = 'success'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
        this.update()
      })
    },
    editTool(name) {
      Api.get(`/cosmos-api/tools/${name}`, {
        params: { scope: 'DEFAULT' },
      }).then((response) => {
        this.tool_id = name
        this.jsonContent = JSON.stringify(response.data, null, '\t')
        this.dialogTitle = name
        this.showDialog = true
      })
    },
    dialogCallback(content) {
      this.showDialog = false
      if (content !== null) {
        let parsed = JSON.parse(content)
        let method = 'put'
        let url = `/cosmos-api/tools/${this.tool_id}`
        if (parsed['name'] !== this.tool_id) {
          method = 'post'
          url = '/cosmos-api/tools'
        }

        Api[method](url, {
          data: {
            json: content,
          },
          params: { scope: 'DEFAULT' },
        }).then((response) => {
          this.alert = 'Modified Tool'
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
      }
    },
    deleteTool(name) {
      this.$dialog
        .confirm(`Are you sure you want to remove: ${name}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          return Api.delete(`/cosmos-api/tools/${name}`, {
            params: { scope: 'DEFAULT' },
          })
        })
        .then((response) => {
          this.alert = `Removed tool ${name}`
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
    },
  },
}
</script>
