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
    <v-card>
      <v-card-title>
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-btn
                icon
                class="mx-2"
                data-test="download-log"
                @click="downloadLog"
              >
                <v-icon> mdi-download </v-icon>
              </v-btn>
            </div>
          </template>
          <span> Download Log </span>
        </v-tooltip>
        Log Messages
        <v-spacer />
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-btn icon class="mx-2" data-test="clear-log" @click="clearLog">
                <v-icon> mdi-delete </v-icon>
              </v-btn>
            </div>
          </template>
          <span> Clear Log </span>
        </v-tooltip>
      </v-card-title>
      <v-card-subtitle>
        <v-text-field
          v-model="search"
          single-line
          hide-details
          autofocus
          label="Search"
          data-test="search-output-messages"
        />
      </v-card-subtitle>
      <v-data-table
        :headers="headers"
        :items="messages"
        :search="search"
        calculate-widths
        disable-pagination
        hide-default-footer
        multi-sort
        dense
        height="45vh"
        data-test="output-messages"
      />
    </v-card>
  </div>
</template>

<script>
import { format } from 'date-fns'

export default {
  props: {
    value: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      search: '',
      headers: [{ text: 'Message', value: 'message' }],
    }
  },
  computed: {
    messages: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  methods: {
    downloadLog() {
      const output = this.messages.map((message) => message.message).join('\n')
      const blob = new Blob([output], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_sr_message_log.txt'
      )
      link.click()
    },
    clearLog: function () {
      this.$dialog
        .confirm('Are you sure you want to clear the logs?', {
          okText: 'Clear',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          this.messages = []
        })
    },
  },
}
</script>
