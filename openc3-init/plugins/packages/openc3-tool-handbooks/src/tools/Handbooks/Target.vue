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
  <v-container :id="target">
    <div class="text-h3 text-center">{{ target }}</div>
    <v-row class="mb-8">
      <div class="text-h4">Commands</div>
    </v-row>
    <v-row
      v-for="packet in commands"
      :key="packet.packetName"
      dense
      class="mb-4"
    >
      <v-col :cols="12">
        <packet
          :packet="packet"
          :columns="columns"
          :hideIgnored="hideIgnored"
          :hideDerived="hideDerived"
          :ignored="ignoredParams"
        ></packet>
      </v-col>
    </v-row>
    <v-row class="mb-8">
      <div class="text-h4">Telemetry</div>
    </v-row>
    <v-row
      v-for="packet in telemetry"
      :key="packet.packetName"
      dense
      class="mb-4"
    >
      <v-col :cols="12">
        <packet
          :packet="packet"
          :columns="columns"
          :hideIgnored="hideIgnored"
          :hideDerived="hideDerived"
          :ignored="ignoredItems"
        ></packet>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import { OpenC3Api } from '@openc3/tool-common/src/services/openc3-api'
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
    columns: {
      type: Number,
      required: true,
    },
    hideIgnored: {
      type: Boolean,
      required: true,
    },
    hideDerived: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      api: null,
      commands: [],
      telemetry: [],
      ignoredParams: [],
      ignoredItems: [],
    }
  },

  created() {
    this.api = new OpenC3Api()
    this.api.get_target(this.target).then((target) => {
      this.ignoredParams = target.ignored_parameters
      this.ignoredItems = target.ignored_items
    })
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
