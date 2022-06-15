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
  <v-container :id="target">
    <div class="text-h3 text-center">{{ target }}</div>
    <div class="text-h4">Commands</div>
    <v-divider></v-divider>
    <v-row v-for="packet in commands" :key="packet.packetName">
      <packet :packet="packet"></packet>
    </v-row>
    <div class="text-h4">Telemetry</div>
    <v-divider></v-divider>
    <v-row v-for="packet in telemetry" :key="packet.packetName">
      <packet :packet="packet"></packet>
    </v-row>
  </v-container>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import Packet from './Packet'

export default {
  components: {
    Packet,
  },
  props: {
    target: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      api: null,
      commands: [],
      telemetry: [],
    }
  },
  created() {
    this.api = new CosmosApi()
    // TODO: Test with large DB as this returns ALL commands
    this.api.get_all_commands(this.target).then((packets) => {
      this.commands = packets
    })
    this.api.get_all_telemetry(this.target).then((packets) => {
      this.telemetry = packets
    })
  },
}
</script>
