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
  <v-container class="c-chooser">
    <v-row>
      <v-col>
        <v-select
          label="Select Target"
          hide-details
          dense
          @change="targetNameChanged"
          :items="targetNames"
          item-text="label"
          item-value="value"
          v-model="selectedTargetName"
          data-test="select-target"
        />
      </v-col>
      <v-col>
        <v-select
          label="Select Packet"
          hide-details
          dense
          @change="packetNameChanged"
          :disabled="packetsDisabled"
          :items="packetNames"
          item-text="label"
          item-value="value"
          v-model="selectedPacketName"
          data-test="select-packet"
        />
      </v-col>
      <v-col v-if="chooseItem && !buttonDisabled">
        <v-select
          label="Select Item"
          hide-details
          dense
          @change="itemNameChanged($event)"
          :disabled="itemsDisabled"
          :items="itemNames"
          item-text="label"
          item-value="value"
          v-model="selectedItemName"
          data-test="select-item"
        />
      </v-col>
      <v-col v-if="buttonText">
        <v-btn
          color="primary"
          :disabled="buttonDisabled"
          @click="buttonPressed"
        >
          {{ actualButtonText }}
        </v-btn>
      </v-col>
    </v-row>
    <v-row no-gutters>
      <v-col>Description: {{ description }}</v-col>
    </v-row>
  </v-container>
</template>

<script>
import { CosmosApi } from '../services/cosmos-api'
export default {
  props: {
    initialTargetName: {
      type: String,
      default: '',
    },
    initialPacketName: {
      type: String,
      default: '',
    },
    initialItemName: {
      type: String,
      default: '',
    },
    mode: {
      type: String,
      default: 'tlm',
      // TODO: add validators throughout
      validator: (propValue) => {
        const propExists = propValue === 'cmd' || propValue === 'tlm'
        return propExists
      },
    },
    chooseItem: {
      type: Boolean,
      default: false,
    },
    buttonText: {
      type: String,
      default: null,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    allowAll: {
      type: Boolean,
      default: false,
    },
    reduced: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    actualButtonText() {
      if (this.selectedPacketName === 'ALL') {
        return 'Add Target'
      }
      if (this.selectedItemName === 'ALL') {
        return 'Add Packet'
      }
      return this.buttonText
    },
    buttonDisabled() {
      return this.disabled || this.internalDisabled
    },
    targetChooserStyle() {
      if (this.chooseItem || this.buttonText) {
        return { width: '25%', float: 'left', 'margin-right': '5px' }
      } else {
        return { width: '49%', float: 'left' }
      }
    },
    packetChooserStyle() {
      if (this.chooseItem || this.buttonText) {
        return { width: '25%', float: 'left', 'margin-right': '5px' }
      } else {
        return { width: '50%', float: 'right' }
      }
    },
  },
  data() {
    return {
      targetNames: [],
      packetNames: [],
      itemNames: [],
      selectedTargetName: this.initialTargetName,
      selectedPacketName: this.initialPacketName,
      selectedItemName: this.initialItemName,
      description: '',
      packet_list_items: [],
      tlm_item_list_items: [],
      internalDisabled: false,
      packetsDisabled: false,
      itemsDisabled: false,
      api: null,
      ALL: { label: '[ ALL ]', value: 'ALL' }, // Constant to indicate all packets or items
    }
  },
  created() {
    this.internalDisabled = true
    this.api = new CosmosApi()
    this.api.get_target_list().then((data) => {
      var targetNames = []
      var arrayLength = data.length
      for (var i = 0; i < arrayLength; i++) {
        targetNames.push({ label: data[i], value: data[i] })
      }
      this.targetNames = targetNames
      if (!this.selectedTargetName) {
        this.selectedTargetName = targetNames[0].value
        this.targetNameChanged(this.selectedTargetName)
      }
      this.updatePackets()
      this.updateItems()
    })
  },
  watch: {
    mode: function (newVal, oldVal) {
      this.updatePackets()
      this.itemNames = []
    },
    reduced: function (newVal, oldVal) {
      this.updateItems()
    },
  },
  methods: {
    updatePackets() {
      this.internalDisabled = true
      let cmd = 'get_all_telemetry'
      if (this.mode == 'cmd') {
        cmd = 'get_all_commands'
      }
      this.api[cmd](this.selectedTargetName).then((packets) => {
        this.packet_list_items = []
        this.packetNames = []
        if (this.allowAll) {
          this.packetNames.push(this.ALL)
        }
        packets.forEach((packet) => {
          this.packet_list_items.push([
            packet['packet_name'],
            packet['description'],
          ])
          this.packetNames.push({
            label: packet['packet_name'],
            value: packet['packet_name'],
          })
        })
        if (!this.selectedPacketName) {
          this.selectedPacketName = this.packetNames[0].value
          this.packetNameChanged(this.selectedPacketName)
        }
        for (const item of this.packet_list_items) {
          if (this.selectedPacketName === item[0]) {
            this.description = item[1]
            break
          }
        }
        this.internalDisabled = false
      })
    },

    updateItems() {
      this.internalDisabled = true
      let cmd = 'get_telemetry'
      if (this.mode == 'cmd') {
        cmd = 'get_command'
      }
      this.api[cmd](this.selectedTargetName, this.selectedPacketName).then(
        (packet) => {
          this.tlm_item_list_items = packet.items
          this.itemNames = []
          if (this.allowAll) {
            this.itemNames.push(this.ALL)
          }
          var arrayLength = packet.items.length
          for (var i = 0; i < arrayLength; i++) {
            if (this.reduced) {
              // We're currently only reducing numeric data which means
              // no arrays, no states, and only UINT, INT, FLOAT
              if (
                !packet.items[i]['array_size'] &&
                !packet.items[i]['states'] &&
                (packet.items[i]['data_type'] === 'UINT' ||
                  packet.items[i]['data_type'] === 'INT' ||
                  packet.items[i]['data_type'] === 'FLOAT')
              ) {
                ;['__MIN', '__MAX', '__AVG', '__STDDEV'].forEach((ext) => {
                  this.itemNames.push({
                    label: `${packet.items[i]['name']}${ext}`,
                    value: `${packet.items[i]['name']}${ext}`,
                  })
                })
              }
            } else {
              this.itemNames.push({
                label: packet.items[i]['name'],
                value: packet.items[i]['name'],
              })
            }
          }
          if (!this.selectedItemName) {
            this.selectedItemName = this.itemNames[0].value
          }
          this.description = this.tlm_item_list_items[0]['description']
          this.internalDisabled = false
          this.$emit('on-set', {
            targetName: this.selectedTargetName,
            packetName: this.selectedPacketName,
            itemName: this.selectedItemName,
          })
        }
      )
    },

    targetNameChanged(value) {
      this.selectedTargetName = value
      this.selectedPacketName = ''
      this.selectedItemName = ''
      this.updatePackets()
    },

    packetNameChanged(value) {
      if (value === 'ALL') {
        this.itemsDisabled = true
        this.internalDisabled = false
      } else {
        this.itemsDisabled = false
        var arrayLength = this.packet_list_items.length
        for (var i = 0; i < arrayLength; i++) {
          if (value === this.packet_list_items[i][0]) {
            this.selectedPacketName = this.packet_list_items[i][0]
            this.description = this.packet_list_items[i][1]
            break
          }
        }
        if (!this.chooseItem) {
          this.$emit('on-set', {
            targetName: this.selectedTargetName,
            packetName: this.selectedPacketName,
          })
        }
        if (this.chooseItem) {
          this.selectedItemName = ''
          this.updateItems()
        }
      }
    },

    itemNameChanged(value) {
      var arrayLength = this.tlm_item_list_items.length
      for (var i = 0; i < arrayLength; i++) {
        if (value === this.tlm_item_list_items[i]['name']) {
          this.selectedItemName = this.tlm_item_list_items[i]['name']
          this.description = this.tlm_item_list_items[i]['description']
          break
        }
      }
      this.$emit('on-set', {
        targetName: this.selectedTargetName,
        packetName: this.selectedPacketName,
        itemName: this.selectedItemName,
      })
    },

    buttonPressed() {
      if (this.selectedPacketName === 'ALL') {
        this.packetNames.forEach((packetName) => {
          if (packetName === this.ALL) return
          let cmd = 'get_telemetry'
          if (this.mode == 'cmd') {
            cmd = 'get_command'
          }
          this.api[cmd](this.selectedTargetName, packetName.value).then(
            (packet) => {
              packet.items.forEach((item) => {
                this.$emit('click', {
                  targetName: this.selectedTargetName,
                  packetName: packetName.value,
                  itemName: item['name'],
                })
              })
            }
          )
        })
      } else if (this.selectedItemName === 'ALL') {
        this.itemNames.forEach((item) => {
          if (item === this.ALL) return
          this.$emit('click', {
            targetName: this.selectedTargetName,
            packetName: this.selectedPacketName,
            itemName: item.value,
          })
        })
      } else if (this.chooseItem) {
        this.$emit('click', {
          targetName: this.selectedTargetName,
          packetName: this.selectedPacketName,
          itemName: this.selectedItemName,
        })
      } else {
        this.$emit('click', {
          targetName: this.selectedTargetName,
          packetName: this.selectedPacketName,
        })
      }
    },
  },
}
</script>
