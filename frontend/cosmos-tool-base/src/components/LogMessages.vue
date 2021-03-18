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
  <v-card>
    <v-card-title>
      Log Messages
      <v-spacer></v-spacer>
      <v-text-field
        v-model="search"
        append-icon="$astro-search"
        label="Search"
        single-line
        hide-details
        data-test="search-log-messages"
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
      dense
      height="45vh"
      data-test="log-messages"
    >
      <template v-slot:item.timestamp="{ item }">
        <time :title="item.timestamp" :datetime="item.timestamp">
          {{ item.timestamp }}
        </time>
      </template>
      <template v-slot:item.severity="{ item }">
        <span :class="getColorClass(item.severity)">{{ item.severity }}</span>
      </template>
    </v-data-table>
  </v-card>
</template>

<script>
import * as ActionCable from 'actioncable'
import { parseISO, format } from 'date-fns'

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
        { text: 'Time', value: 'timestamp', width: 200 },
        { text: 'Severity', value: 'severity' },
        { text: 'Source', value: 'microservice_name' },
        { text: 'Message', value: 'log' },
      ],
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel,
    }
  },
  created() {
    this.cable = ActionCable.createConsumer('/cosmos-api/cable')
    this.subscription = this.cable.subscriptions.create(
      {
        channel: 'MessagesChannel',
        history_count: this.history_count,
        scope: 'DEFAULT',
      },
      {
        received: (data) => {
          let messages = JSON.parse(data)
          for (let i = 0; i < messages.length; i++) {
            messages[i]['timestamp'] = this.formatDate(
              messages[i]['@timestamp']
            )
            this.data.unshift(messages[i])
          }
          if (this.data.length > this.history_count) {
            this.data.length = this.history_count
          }
        },
      }
    )
  },
  destroyed() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    formatDate(timestamp) {
      // timestamp: 2021-01-20T21:08:49.784+00:00
      return format(parseISO(timestamp), 'yyyy-MM-dd HH:mm:ss.SSS')
    },
    getColorClass(severity) {
      if (severity === 'INFO') {
        return 'cosmos-green'
      } else if (severity === 'WARN') {
        return 'cosmos-yellow'
      } else if (severity === 'ERROR') {
        return 'cosmos-red'
      }
      if (this.$vuetify.theme.dark) {
        return 'cosmos-white'
      } else {
        return 'cosmos-black'
      }
    },
  },
}
</script>

<style scoped></style>
