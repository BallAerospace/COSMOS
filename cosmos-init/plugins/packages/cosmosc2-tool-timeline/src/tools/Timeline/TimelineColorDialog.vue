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

    <v-dialog v-model="show" width="600">
      <v-card>
        <form v-on:submit.prevent="submitHandler">

          <v-system-bar>
            <v-spacer />
            <span> Timeline: {{ timeline.name }} </span>
            <v-spacer />
          </v-system-bar>

          <v-card-text>
            <div class="pa-3">
              <v-row dense>
                <v-sheet dark class="pa-4">
                  <pre v-text="showColor" />
                </v-sheet>
              </v-row>
              <v-row dense align="center" justify="center">
                <v-color-picker
                  v-model="color"
                  hide-canvas
                  hide-mode-switch
                  show-swatches
                  :swatches="swatches"
                  mode="rgb"
                  width="100%"
                  swatches-max-height="100"
                />
              </v-row>
              <v-row>
                <v-btn
                  @click.prevent="submitHandler"
                  type="submit"
                  color="success"
                  data-test="color-submit-btn"
                >
                  Ok
                </v-btn>
                <v-spacer />
                <v-btn
                  @click="show = false"
                  color="primary"
                  data-test="color-cancel-btn"
                >
                  Cancel
                </v-btn>
              </v-row>
            </div>
          </v-card-text>

        </form>
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
      swatches: [
        ['#FF0000', '#AA0000', '#550000'],
        ['#FFFF00', '#AAAA00', '#555500'],
        ['#00FF00', '#00AA00', '#005500'],
        ['#00FFFF', '#00AAAA', '#005555'],
        ['#0000FF', '#0000AA', '#000055'],
      ],
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
        return this.hex
      },
      set(v) {
        this.hex = v
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
        data: {
          color: this.hex,
        },
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
