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
    <v-menu offset-y>
      <template v-slot:activator="{ on, attrs }">
        <div v-bind="attrs" v-on="on">
          <v-btn icon :data-test="`${name}-options`">
            <v-icon>mdi-dots-vertical</v-icon>
          </v-btn>
        </div>
      </template>
      <v-card>
        <div style="background-color: var(--v-primary-darken2)">
          <v-row
            dense
            v-for="(colors, ii) in swatches"
            :key="`colors-${ii}`"
            class="p-2"
          >
            <v-col
              dense
              v-for="(color, jj) in colors"
              :key="`color-${jj}`"
              align="center"
              justify="center"
            >
              <v-btn
                icon
                :data-test="`${name}-color-${color}`"
                @click="updateColor(color)"
              >
                <v-badge inline :color="color" />
              </v-btn>
            </v-col>
          </v-row>
        </div>
        <v-btn tile :data-test="`${name}-delete`" @click="deleteTimeline">
          <v-icon left> mdi-delete </v-icon>
          <span> Delete Timeline </span>
        </v-btn>
      </v-card>
    </v-menu>
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'

export default {
  props: {
    timeline: Object,
  },
  data() {
    return {}
  },
  computed: {
    name: function () {
      return this.timeline ? this.timeline.name : ''
    },
    swatches: function () {
      return [
        ['#005a8f', '#003784', '#ff4081', '#df1368'],
        ['#ff5252', '#df323b', '#9f0010', '#2d9437'],
        ['#004700', '#db7200', '#802700', '#0f2941'],
      ]
    },
  },
  methods: {
    deleteTimeline: function () {
      this.$dialog
        .confirm(`Are you sure you want to remove: ${this.name}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          return Api.delete(`/openc3-api/timeline/${this.name}`)
        })
        .then((response) => {
          this.$notify.normal({
            title: 'Deleted Timeline',
            body: `${this.name} has been deleted.`,
          })
        })
        .catch((error) => {})
    },
    updateColor: function (color) {
      Api.post(`/openc3-api/timeline/${this.name}/color`, {
        data: { color },
      }).then((response) => {
        this.$notify.normal({
          title: `Color updated on Timeline`,
          body: `Timeline: ${this.name} color update to ${color}`,
        })
      })
    },
  },
}
</script>
