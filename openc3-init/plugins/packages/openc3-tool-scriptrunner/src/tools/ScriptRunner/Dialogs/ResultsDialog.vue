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
  <v-dialog v-model="show" width="600">
    <v-card>
      <v-system-bar>
        <v-spacer />
        <span> Script Results </span>
        <v-spacer />
      </v-system-bar>
      <div class="pa-2">
        <v-card-text>
          <v-textarea readonly hide-details dense auto-grow :value="text" />
        </v-card-text>
      </div>
      <v-card-actions>
        <v-spacer />
        <v-btn class="mx-2" outlined @click="downloadResults"> Download </v-btn>
        <v-btn class="mx-2" color="primary" @click="show = !show"> Ok </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
import { format } from 'date-fns'

export default {
  components: {},
  props: {
    value: {
      type: Boolean,
      required: true,
    },
    text: {
      type: String,
      required: true,
    },
  },
  computed: {
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  methods: {
    downloadResults() {
      const blob = new Blob([this.text], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_suite_results.txt'
      )
      link.click()
    },
  },
}
</script>
