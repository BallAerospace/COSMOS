<!--
# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addstopums as found in the LICENSE.txt
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
    <!-- Dialog for adding a new component to a tab -->
    <v-dialog v-model="show" width="600">
      <v-card>
        <v-system-bar>
          <v-spacer />
          <span> DataViewer: Add A Packet </span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <v-row>
            <v-col class="my-2">
              <v-radio-group
                v-model="newPacketCmdOrTlm"
                row
                hide-details
                class="mt-0"
              >
                <v-radio
                  label="Command"
                  value="cmd"
                  data-test="command-packet-radio"
                />
                <v-radio
                  label="Telemetry"
                  value="tlm"
                  data-test="telemetry-packet-radio"
                />
              </v-radio-group>
            </v-col>
          </v-row>
          <v-row>
            <v-col>
              <target-packet-item-chooser
                :mode="newPacketCmdOrTlm"
                unknown
                @on-set="packetSelected"
              />
            </v-col>
          </v-row>
          <v-row>
            <v-col>
              <v-radio-group v-model="newPacketMode" row hide-details>
                <v-radio
                  label="Raw"
                  value="RAW"
                  data-test="new-packet-raw-radio"
                />
                <v-radio
                  label="Decom"
                  value="DECOM"
                  :disabled="disableRadioOptions"
                  data-test="new-packet-decom-radio"
                />
              </v-radio-group>
            </v-col>
            <v-col>
              <v-select
                v-if="newPacketMode === 'DECOM'"
                v-model="newPacketValueType"
                hide-details
                label="Value Type"
                data-test="add-packet-value-type"
                :items="valueTypes"
              />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn
            outlined
            class="mx-2"
            data-test="cancel-packet-button"
            @click="cancelAddComponent"
          >
            Cancel
          </v-btn>
          <v-btn
            color="primary"
            class="mx-2"
            data-test="add-packet-button"
            :disabled="!newPacket"
            @click="addComponent"
          >
            Add
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import TargetPacketItemChooser from '@openc3/tool-common/src/components/TargetPacketItemChooser'

export default {
  components: {
    TargetPacketItemChooser,
  },
  props: {
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      newPacket: null,
      newPacketCmdOrTlm: 'tlm',
      newPacketMode: 'RAW',
      valueTypes: ['CONVERTED', 'RAW', 'FORMATTED', 'WITH_UNITS'],
      newPacketValueType: 'WITH_UNITS',
    }
  },
  computed: {
    disableRadioOptions: function () {
      if (this.newPacket) {
        return this.newPacket.packet === 'UNKNOWN'
      }
      return false
    },
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  watch: {
    newPacketCmdOrTlm: {
      immediate: true,
      handler: function () {
        this.newPacket = null
      },
    },
  },
  methods: {
    packetSelected: function (event) {
      this.newPacket = {
        target: event.targetName,
        packet: event.packetName,
        cmdOrTlm: this.newPacketCmdOrTlm,
      }
      if (event.packetName == 'UNKNOWN') {
        this.newPacketMode = 'RAW'
      }
    },
    addComponent: function (event) {
      this.$emit('add', {
        ...this.newPacket,
        component: 'DumpComponent',
        config: {},
        mode: this.newPacketMode,
        valueType: this.newPacketValueType,
      })
    },
    cancelAddComponent: function () {
      this.$emit('cancel', {})
    },
  },
}
</script>
