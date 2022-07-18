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
  <v-dialog v-model="show" :width="width">
    <v-card>
      <v-system-bar>
        <v-spacer />
        <span> {{ title }} </span>
        <v-spacer />
        <div class="mx-2">
          <v-tooltip top>
            <template v-slot:activator="{ on, attrs }">
              <div v-on="on" v-bind="attrs">
                <v-icon data-test="downloadIcon" @click="download">
                  mdi-download
                </v-icon>
              </div>
            </template>
            <span> Download </span>
          </v-tooltip>
        </div>
      </v-system-bar>
      <v-card-text>
        <div class="pa-3">
          <span style="white-space: pre-wrap">{{ text }}</span>
        </div>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn class="mx-2" color="primary" @click="show = !show"> Ok </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    value: Boolean, // value is the default prop when using v-model
    text: String,
    title: String,
    width: 800,
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
    download: function () {
      const blob = new Blob([this.text], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute('download', `${this.title}.txt`)
      link.click()
    },
  },
}
</script>
