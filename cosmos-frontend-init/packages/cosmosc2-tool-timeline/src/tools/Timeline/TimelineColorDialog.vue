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
    <v-dialog v-model="show" width="500">
      <v-card class="pa-3">
        <v-toolbar>
          <v-toolbar-title>Timeline: {{ timeline.name }}</v-toolbar-title>
          <v-spacer />
          <v-sheet dark class="pa-4">
            <pre>{{ showColor }}</pre>
          </v-sheet>
        </v-toolbar>
        <v-row dense class="mt-2" align="center" justify="center">
          <v-color-picker v-model="color" width="450" />
        </v-row>
        <v-row dense class="mt-2">
          <v-btn color="success" @click="submitHandler">Ok</v-btn>
          <v-spacer />
          <v-btn color="primary" @click="show = false">Cancel</v-btn>
        </v-row>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'

export default {
  props: {
    timeline: Object,
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      type: 'hex',
      hex: '#000000',
    }
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
    color: {
      get() {
        return this[this.type]
      },
      set(v) {
        this[this.type] = v
      },
    },
    showColor() {
      if (typeof this.color === 'string') return this.color

      return JSON.stringify(
        Object.keys(this.color).reduce((color, key) => {
          color[key] = Number(this.color[key].toFixed(2))
          return color
        }, {}),
        null,
        2
      )
    },
  },
  methods: {
    submitHandler(event) {
      const path = `/cosmos-api/timeline/${this.timeline.name}/color`
      Api.post(path, {
        color: this.hex,
      })
        .then((response) => {
          const alertObject = {
            text: `Updated color on timeline: ${this.timeline.name}`,
            type: 'success',
          }
          this.$emit('alert', alertObject)
          this.show = false
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to update color on timeline: ${this.timeline.name}, ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
    },
  },
}
</script>

<style scoped>
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
</style>
