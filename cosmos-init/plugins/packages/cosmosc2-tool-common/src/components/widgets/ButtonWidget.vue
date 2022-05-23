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
  <div>
    <v-btn class="ma-1" color="primary" :style="computedStyle" @click="onClick">
      {{ buttonText }}
    </v-btn>
    <v-dialog v-model="displaySendHazardous" max-width="300">
      <v-card class="pa-3">
        <v-card-title class="headline">Hazardous</v-card-title>
        <v-card-text> Warning: Command is Hazardous. Send? </v-card-text>
        <v-btn @click="sendHazardousCmd" class="primary mr-4">Yes</v-btn>
        <v-btn @click="cancelHazardousCmd" class="primary">No</v-btn>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import { CosmosApi } from '../../services/cosmos-api'
import Widget from './Widget'

export default {
  mixins: [Widget],
  data() {
    return {
      api: null,
      screen: null,
      displaySendHazardous: false,
      lastCmd: '',
    }
  },
  computed: {
    buttonText() {
      return this.parameters[0]
    },
    eval() {
      return this.parameters[1]
    },
  },
  created() {
    this.api = new CosmosApi()
    // Look through the settings and get a reference to the screen
    this.settings.forEach((setting) => {
      if (setting[0] === 'SCREEN') {
        this.screen = setting[1]
      }
    })
  },
  methods: {
    onClick() {
      const lines = this.eval.split('\n')
      // Create local references to variables so users don't need to use 'this'
      const self = this // needed for $emit
      const screen = this.screen
      const api = this.api
      lines.forEach((line) => {
        const result = eval(line.trim())
        if (result instanceof Promise) {
          result
            .then((success) => {})
            .catch((err) => {
              // This text is in top_level.rb HazardousError.to_s
              if (err.message.includes('is Hazardous')) {
                this.lastCmd = err.message.split('\n').pop()
                this.displaySendHazardous = true
              }
            })
        }
      })
    },
    sendHazardousCmd() {
      this.displaySendHazardous = false
      // TODO: This only handles basic cmd() calls in buttons, do we need to handle other? cmd_raw()?
      this.lastCmd = this.lastCmd.replace(
        'cmd(',
        'this.api.cmd_no_hazardous_check('
      )
      eval(this.lastCmd)
    },
    cancelHazardousCmd() {
      this.displaySendHazardous = false
    },
  },
}
</script>
