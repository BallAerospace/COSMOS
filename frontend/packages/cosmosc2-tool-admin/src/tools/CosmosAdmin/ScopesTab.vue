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
      <v-col cols="4">
        <v-text-field v-model="scope" label="Scope Name"></v-text-field>
      </v-col>
      <v-col cols="1" class="pl-2">
        <v-btn color="primary" class="mr-4" @click="add()">
          Add
          <v-icon right dark>$astro-add-small</v-icon>
        </v-btn>
      </v-col>
    </v-row>
    <v-list data-test="scopeList">
      <v-list-item v-for="(scope, i) in scopes" :key="i">
        <v-list-item-content>
          <v-list-item-title v-text="scope"></v-list-item-title>
        </v-list-item-content>
        <v-list-item-icon v-if="scopes.length > 1">
          <v-tooltip bottom>
            <template v-slot:activator="{ on, attrs }">
              <v-icon @click="deleteScope(scope)" v-bind="attrs" v-on="on"
                >mdi-delete</v-icon
              >
            </template>
            <span>Delete Scope</span>
          </v-tooltip>
        </v-list-item-icon>
      </v-list-item>
    </v-list>
    <v-alert
      :type="alertType"
      v-model="showAlert"
      dismissible
      transition="scale-transition"
      >{{ alert }}</v-alert
    >
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
export default {
  components: {},
  data() {
    return {
      scope: null,
      scopes: [],
      alert: '',
      alertType: 'success',
      showAlert: false,
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update() {
      Api.get('/cosmos-api/scopes')
        .then((response) => {
          this.scopes = response.data
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
      if (this.scope !== null) {
        Api.post('/cosmos-api/scopes', {
          scope: this.scope,
          json: JSON.stringify({ name: this.scope }),
        })
          .then((response) => {
            this.alert = 'Added scope ' + this.scope
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
        this.alert = 'Please Name the Scope'
        this.alertType = 'warning'
        this.showAlert = true
        setTimeout(() => {
          this.showAlert = false
        }, 5000)
      }
    },
    deleteScope(scope) {
      var self = this
      this.$dialog
        .confirm('Are you sure you want to remove: ' + scope, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then(function (dialog) {
          Api.delete('/cosmos-api/scopes/' + scope)
            .then((response) => {
              self.alert = 'Removed scope ' + scope
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
