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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
-->

<template>
  <div>
    <v-list data-test="interfaceList">
      <div
        v-for="(openc3_interface, index) in interfaces"
        :key="openc3_interface"
      >
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title>{{ openc3_interface }}</v-list-item-title>
          </v-list-item-content>
          <v-list-item-icon>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon
                  @click="showInterface(openc3_interface)"
                  v-bind="attrs"
                  v-on="on"
                >
                  mdi-eye
                </v-icon>
              </template>
              <span>Show Interface Details</span>
            </v-tooltip>
          </v-list-item-icon>
        </v-list-item>
        <v-divider v-if="index < interfaces.length - 1" :key="index" />
      </div>
    </v-list>
    <edit-dialog
      :content="jsonContent"
      :title="`Interface: ${dialogTitle}`"
      readonly
      v-model="showDialog"
      v-if="showDialog"
      @submit="dialogCallback"
    />
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'
import EditDialog from '@/tools/OpenC3Admin/EditDialog'
export default {
  components: { EditDialog },
  data() {
    return {
      interfaces: [],
      jsonContent: '',
      dialogTitle: '',
      showDialog: false,
    }
  },
  mounted() {
    this.update()
  },
  methods: {
    update() {
      Api.get('/openc3-api/interfaces').then((response) => {
        this.interfaces = response.data
      })
    },
    showInterface(name) {
      Api.get(`/openc3-api/interfaces/${name}`).then((response) => {
        this.jsonContent = JSON.stringify(response.data, null, '\t')
        this.dialogTitle = name
        this.showDialog = true
      })
    },
    dialogCallback(content) {
      this.showDialog = false
    },
  },
}
</script>
