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
  <div class="logging">
    <v-container>
      <v-row no-gutters>
        <v-col>
          <div class="title">System Wide Logging Actions</div>
        </v-col>
      </v-row>
      <v-row>
        <v-col>
          <v-btn block color="primary" @click="startLogging()">
            Start Logging On All
          </v-btn>
        </v-col>
        <v-col>
          <v-btn block color="primary" @click="stopLogging()">
            Stop Logging On All
          </v-btn>
        </v-col>
      </v-row>
      <v-row>
        <v-col>
          <v-btn block color="primary" @click="startTlmLogging('ALL')">
            Start Telemetry Logging on All
          </v-btn>
        </v-col>
        <v-col>
          <v-btn block color="primary" @click="stopTlmLogging('ALL')">
            Stop Telemetry Logging on All
          </v-btn>
        </v-col>
      </v-row>
      <v-row>
        <v-col>
          <v-btn block color="primary" @click="startCmdLogging('ALL')">
            Start Command Logging on All
          </v-btn>
        </v-col>
        <v-col>
          <v-btn block color="primary" @click="stopCmdLogging('ALL')">
            Stop Command Logging on All
          </v-btn>
        </v-col>
      </v-row>
    </v-container>
    <packet-log-info v-for="log in loggers" :log="log" :key="log.name" />
    <br />
    Note: Buffered IO operations cause file size to not reflect total logged
    data size until the log file is closed.
  </div>
</template>

<script>
import Updater from './Updater'
import PacketLogInfo from '@openc3/tool-common/src/components/PacketLogInfo.vue'

export default {
  components: {
    PacketLogInfo,
  },
  mixins: [Updater],
  props: {
    tabId: Number,
    curTab: Number,
  },
  data() {
    return {
      loggers: null,
    }
  },
  methods: {
    update() {
      if (this.tabId != this.curTab) return
      this.api.get_all_packet_logger_info().then((info) => {
        this.loggers = []
        for (let x of info) {
          var log = {}
          log.name = x[0]
          log.interfaces = x[1]
          log.cmdLogging = x[2]
          log.cmdQueueSize = x[3]
          log.cmdFilename = x[4]
          log.cmdFileSize = x[5]
          log.tlmLogging = x[6]
          log.tlmQueueSize = x[7]
          log.tlmFilename = x[8]
          log.tlmFileSize = x[9]
          this.loggers.push(log)
        }
      })
    },
    startLogging() {
      this.api.start_logging()
    },
    stopLogging() {
      this.api.stop_logging()
    },
    startTlmLogging(log_writer_name) {
      this.api.start_tlm_log(log_writer_name)
    },
    stopTlmLogging(log_writer_name) {
      this.api.stop_tlm_log(log_writer_name)
    },
    startCmdLogging(log_writer_name) {
      this.api.start_cmd_log(log_writer_name)
    },
    stopCmdLogging(log_writer_name) {
      this.api.stop_cmd_log(log_writer_name)
    },
  },
}
</script>

<style scoped>
.logging {
  background-color: var(--v-tertiary-base);
  padding: 10px;
}
.container {
  padding: 0px;
  margin-bottom: 12px;
}
.col {
  padding-top: 5px;
  padding-bottom: 5px;
}
</style>
