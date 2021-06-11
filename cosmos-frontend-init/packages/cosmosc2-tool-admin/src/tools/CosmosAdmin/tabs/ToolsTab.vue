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
        <v-text-field v-model="name" label="Tool Name" />
      </v-col>
      <v-col cols="2">
        <v-text-field v-model="icon" label="Tool Icon" />
      </v-col>
      <v-col cols="3">
        <v-text-field v-model="url" label="Tool Url" />
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="add()">
          Add
          <v-icon right dark>$astro-add-small</v-icon>
        </v-btn>
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
      <v-list-item v-for="tool in tools" :key="tool">
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
      :content="json_content"
      title="Edit Tool"
      v-model="showDialog"
      v-if="showDialog"
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
      json_content: '',
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
      Api.post('/cosmos-api/tools/position/' + this.tools[evt.oldIndex], {
        position: evt.newIndex,
      })
        .then((response) => {
          this.alert = 'Reordered tool ' + this.tools[evt.oldIndex]
          this.alertType = 'success'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
          this.update()
        })
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
        })
    },
    update() {
      Api.get('/cosmos-api/tools')
        .then((response) => {
          this.tools = response.data
        })
        .catch((error) => {
          this.alert = error
          this.alertType = 'error'
          this.showAlert = true
          setTimeout(() => {
            this.showAlert = false
          }, 5000)
        })
    },
    add() {
      if (this.name !== null && this.icon !== null && this.url !== null) {
        Api.post('/cosmos-api/tools', {
          id: this.name,
          json: JSON.stringify({
            name: this.name,
            icon: this.icon,
            url: this.url,
            window: 'NEW',
          }),
        })
          .then((response) => {
            this.alert = 'Added tool ' + this.name
            this.alertType = 'success'
            this.showAlert = true
            setTimeout(() => {
              this.showAlert = false
            }, 5000)
            this.update()
          })
          .catch((error) => {
            this.alert = error
            this.alertType = 'error'
            this.showAlert = true
            setTimeout(() => {
              this.showAlert = false
            }, 5000)
          })
      } else {
        this.alert = 'Please Fill All Fields'
        this.alertType = 'warning'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      }
    },
    editTool(name) {
      var self = this
      Api.get('/cosmos-api/tools/' + name)
        .then((response) => {
          self.tool_id = name
          self.json_content = JSON.stringify(response.data, null, 1)
          self.showDialog = true
        })
        .catch((error) => {
          self.alert = error
          self.alertType = 'error'
          self.showAlert = true
          setTimeout(() => {
            self.showAlert = false
          }, 5000)
        })
    },
    dialogCallback(content) {
      this.showDialog = false
      if (content !== null) {
        let parsed = JSON.parse(content)
        let method = 'put'
        let url = '/cosmos-api/tools/' + this.tool_id
        if (parsed['name'] !== this.tool_id) {
          method = 'post'
          url = '/cosmos-api/tools'
        }

        Api[method](url, {
          json: content,
        })
          .then((response) => {
            this.alert = 'Modified Tool'
            this.alertType = 'success'
            this.showAlert = true
            setTimeout(() => {
              this.showAlert = false
            }, 5000)
            this.update()
          })
          .catch((error) => {
            this.alert = error
            this.alertType = 'error'
            this.showAlert = true
          })
      }
    },
    deleteTool(name) {
      var self = this
      this.$dialog
        .confirm('Are you sure you want to remove: ' + name, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          Api.delete('/cosmos-api/tools/' + name)
            .then((response) => {
              self.alert = 'Removed tool ' + name
              self.alertType = 'success'
              self.showAlert = true
              setTimeout(() => {
                self.showAlert = false
              }, 5000)
              self.update()
            })
            .catch((error) => {
              self.alert = error
              self.alertType = 'error'
              self.showAlert = true
              setTimeout(() => {
                self.showAlert = false
              }, 5000)
            })
        })
    },
  },
}
</script>
