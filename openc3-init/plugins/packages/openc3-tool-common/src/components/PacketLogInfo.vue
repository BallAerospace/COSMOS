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
  <v-card>
    <v-card-title>{{ log.name }}</v-card-title>
    <v-container>
      <v-row no-gutters>
        <v-col cols="2">Interfaces: </v-col>
        <v-col>{{ log.interfaces.join(', ') }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Cmd Logging: </v-col>
        <v-col>{{ log.cmdLogging }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Cmd Queue Size: </v-col>
        <v-col>{{ log.cmdQueueSize }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Cmd Filename: </v-col>
        <v-col>{{ log.cmdFilename }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Cmd File Size: </v-col>
        <v-col>{{ log.cmdFileSize }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Tlm Logging: </v-col>
        <v-col>{{ log.tlmLogging }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Tlm Queue Size: </v-col>
        <v-col>{{ log.tlmQueueSize }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Tlm Filename: </v-col>
        <v-col>{{ log.tlmFilename }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Tlm File Size: </v-col>
        <v-col>{{ log.tlmFileSize }} </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col cols="2">Logging Actions: </v-col>
        <v-col>
          <v-btn color="primary" @click="startCmdLogging(log.name)">
            Log Cmds
          </v-btn>
        </v-col>
        <v-col>
          <v-btn color="primary" @click="startTlmLogging(log.name)">
            Log Tlm
          </v-btn>
        </v-col>
        <v-col>
          <v-btn color="primary" @click="stopCmdLogging(log.name)">
            Stop Cmds
          </v-btn>
        </v-col>
        <v-col>
          <v-btn color="primary" @click="stopTlmLogging(log.name)">
            Stop Tlm
          </v-btn>
        </v-col>
      </v-row>
    </v-container>
  </v-card>
</template>

<script>
import { OpenC3Api } from '../services/openc3-api.js'

export default {
  props: {
    log: {
      type: Object,
      required: true,
    },
  },
  created() {
    this.api = new OpenC3Api()
  },
  methods: {
    startTlmLogging(logWriterName) {
      this.api.start_tlm_log(logWriterName)
    },
    stopTlmLogging(logWriterName) {
      this.api.stop_tlm_log(logWriterName)
    },
    startCmdLogging(logWriterName) {
      this.api.start_cmd_log(logWriterName)
    },
    stopCmdLogging(logWriterName) {
      this.api.stop_cmd_log(logWriterName)
    },
  },
}
</script>

<style lang="scss" scoped>
.container {
  background-color: var(--v-tertiary-darken2);
}
</style>
