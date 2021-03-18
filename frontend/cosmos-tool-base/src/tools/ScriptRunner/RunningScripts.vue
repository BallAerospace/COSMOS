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
    <app-nav />
    <v-card>
      <v-card-title>
        <v-btn color="primary" @click="getRunningScripts">Refresh</v-btn>
        <v-spacer></v-spacer>
        <v-text-field
          v-model="search"
          append-icon="mdi-magnify"
          label="Search"
          single-line
          hide-details
        ></v-text-field>
      </v-card-title>
      <v-data-table
        :headers="headers"
        :items="data"
        :search="search"
        calculate-widths
        disable-pagination
        hide-default-footer
        multi-sort
      >
        <template v-slot:item.actions="{ item }">
          <v-btn color="primary" @click="connect(item.id)">Connect</v-btn>
        </template>
      </v-data-table>
    </v-card>
  </div>
</template>

<script>
import Api from '@/services/api'
import AppNav from '@/AppNav'

export default {
  components: {
    AppNav,
  },
  props: {
    tabId: Number,
    curTab: Number,
  },
  data() {
    return {
      search: '',
      data: [],
      headers: [
        { text: 'Id', value: 'id' },
        { text: 'Name', value: 'name' },
        { text: 'Bucket', value: 'bucket' },
        { text: 'Start Time', value: 'start_time' },
        {
          text: 'Actions',
          value: 'actions',
          sortable: false,
          filterable: false,
        },
      ],
    }
  },
  created() {
    this.getRunningScripts()
  },
  methods: {
    getRunningScripts() {
      Api.get('/script-api/running-script').then((response) => {
        this.data = response.data
      })
    },
    connect(id) {
      this.$router.push({ name: 'ScriptRunner', params: { id: id } })
    },
  },
}
</script>

<style scoped></style>
