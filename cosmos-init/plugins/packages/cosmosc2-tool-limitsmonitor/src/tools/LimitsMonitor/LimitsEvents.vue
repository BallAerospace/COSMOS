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
  <v-card class="card-height">
    <v-card-title>
      Limits Events
      <v-spacer />
      <v-text-field
        v-model="search"
        append-icon="mdi-magnify"
        label="Search"
        single-line
        hide-details
      />
    </v-card-title>
    <v-data-table
      :headers="headers"
      :items="data"
      :search="search"
      calculate-widths
      disable-pagination
      hide-default-footer
      multi-sort
      dense
      :height="calcTableHeight()"
      data-test="limits-events"
    >
      <template v-slot:item.time_nsec="{ item }">
        <span>{{ formatDate(item.time_nsec) }}</span>
      </template>
      <template v-slot:item.message="{ item }">
        <span :class="getColorClass(item.message)">{{ item.message }}</span>
      </template>
    </v-data-table>
  </v-card>
</template>

<script>
import { toDate, format } from 'date-fns'

export default {
  props: {
    history_count: {
      type: Number,
      default: 1000,
    },
  },
  data() {
    return {
      data: [],
      search: '',
      headers: [
        { text: 'Time', value: 'time_nsec', width: 250 },
        { text: 'Message', value: 'message' },
      ],
    }
  },
  methods: {
    handleMessages(messages) {
      for (let i = 0; i < messages.length; i++) {
        this.data.unshift(messages[i])
      }
      if (this.data.length > this.history_count) {
        this.data.length = this.history_count
      }
    },
    formatDate(nanoSecs) {
      return format(
        toDate(parseInt(nanoSecs) / 1_000_000),
        'yyyy-MM-dd HH:mm:ss.SSS'
      )
    },
    getColorClass(message) {
      if (message.includes('GREEN')) {
        return 'cosmos-green'
      } else if (message.includes('YELLOW')) {
        return 'cosmos-yellow'
      } else if (message.includes('RED')) {
        return 'cosmos-red'
      } else if (message.includes('BLUE')) {
        return 'cosmos-blue'
      }
      if (this.$vuetify.theme.dark) {
        return 'cosmos-white'
      } else {
        return 'cosmos-black'
      }
    },
    calcTableHeight() {
      // TODO: 250 is a magic number but seems to work well
      return window.innerHeight - 250
    },
  },
}
</script>

<style lang="scss" scoped>
.card-height {
  // TODO: 150 is a magic number but seems to work well
  // Can this be calculated by the size of the table search box?
  height: calc(100vh - 150px);
}
</style>
