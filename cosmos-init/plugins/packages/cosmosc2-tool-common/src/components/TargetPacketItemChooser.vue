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
  <v-container class="c-chooser px-0">
    <v-row>
      <v-col :cols="colSize" data-test="select-target">
        <v-autocomplete
          label="Select Target"
          hide-details
          dense
          @change="targetNameChanged"
          :items="targetNames"
          item-text="label"
          item-value="value"
          v-model="selectedTargetName"
        />
      </v-col>
      <v-col :cols="colSize" data-test="select-packet">
        <v-autocomplete
          label="Select Packet"
          hide-details
          dense
          @change="packetNameChanged"
          :disabled="packetsDisabled || buttonDisabled"
          :items="packetNames"
          item-text="label"
          item-value="value"
          v-model="selectedPacketName"
        />
      </v-col>
      <v-col
        v-if="chooseItem && !buttonDisabled"
        :cols="colSize"
        data-test="select-item"
      >
        <v-autocomplete
          label="Select Item"
          hide-details
          dense
          @change="itemNameChanged($event)"
          :disabled="itemsDisabled || buttonDisabled"
          :items="itemNames"
          item-text="label"
          item-value="value"
          v-model="selectedItemName"
        />
      </v-col>
      <v-col v-if="buttonText" :cols="colSize">
        <v-btn
          :disabled="buttonDisabled"
          block
          color="primary"
          data-test="select-send"
          @click="buttonPressed"
        >
          {{ actualButtonText }}
        </v-btn>
      </v-col>
    </v-row>
    <v-row no-gutters>
      <v-col :cols="colSize">Description: {{ description }}</v-col>
    </v-row>
  </v-container>
</template>

<script>
import { CosmosApi } from '../services/cosmos-api'
export default {
  props: {
    allowAll: {
      type: Boolean,
      default: false,
    },
    buttonText: {
      type: String,
      default: null,
    },
    chooseItem: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
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
        return ['cmd', 'tlm'].includes(propValue)
      },
    },
    reduced: {
      type: String,
      default: 'DECOM',
      validator: (propValue) => {
        return [
          'REDUCED_DAY',
          'REDUCED_HOUR',
          'REDUCED_MINUTE',
          'DECOM',
        ].includes(propValue)
      },
    },
    unknown: {
      type: Boolean,
      default: false,
    },
    vertical: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      targetNames: [],
      packetNames: [],
      itemNames: [],
      selectedTargetName: this.initialTargetName?.toUpperCase(),
      selectedPacketName: this.initialPacketName?.toUpperCase(),
      selectedItemName: this.initialItemName?.toUpperCase(),
      description: '',
      internalDisabled: false,
      packetsDisabled: false,
      itemsDisabled: false,
      api: null,
      ALL: {
        label: '[ ALL ]',
        value: 'ALL',
        description: 'ALL',
      }, // Constant to indicate all packets or items
      UNKNOWN: {
        label: '[ UNKNOWN ]',
        value: 'UNKNOWN',
        description: 'UNKNOWN',
      },
    }
  },
  created() {
    this.internalDisabled = true
    this.api = new CosmosApi()
    this.api.get_target_list().then((result) => {
      this.targetNames = result.map((target) => {
        return { label: target, value: target }
      })
      if (!this.selectedTargetName) {
        this.selectedTargetName = this.targetNames[0].value
        this.targetNameChanged(this.selectedTargetName)
      }
      this.updatePackets()
      if (this.unknown) {
        this.targetNames.push(this.UNKNOWN)
      }
    })
  },
  computed: {
    actualButtonText: function () {
      if (this.selectedPacketName === 'ALL') {
        return 'Add Target'
      }
      if (this.selectedItemName === 'ALL') {
        return 'Add Packet'
      }
      return this.buttonText
    },
    buttonDisabled: function () {
      return this.disabled || this.internalDisabled
    },
    targetChooserStyle: function () {
      if (this.chooseItem || this.buttonText) {
        return { width: '25%', float: 'left', 'margin-right': '5px' }
      } else {
        return { width: '49%', float: 'left' }
      }
    },
    packetChooserStyle: function () {
      if (this.chooseItem || this.buttonText) {
        return { width: '25%', float: 'left', 'margin-right': '5px' }
      } else {
        return { width: '50%', float: 'right' }
      }
    },
    colSize: function () {
      return this.vertical ? 12 : false
    },
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
    updatePackets: function () {
      if (this.selectedTargetName === 'UNKNOWN') {
        this.packetNames = [this.UNKNOWN]
        this.selectedPacketName = this.packetNames[0].value
        this.packetNameChanged(this.UNKNOWN.value)
        this.description = 'UNKNOWN'
        return
      }
      this.internalDisabled = true
      const cmd =
        this.mode === 'tlm'
          ? 'get_all_telemetry_names'
          : 'get_all_command_names'
      this.api[cmd](this.selectedTargetName).then((names) => {
        this.packetNames = names.map((name) => {
          return {
            label: name,
            value: name,
          }
        })
        if (this.allowAll) {
          this.packetNames.unshift(this.ALL)
        }
        if (!this.selectedPacketName) {
          this.selectedPacketName = this.packetNames[0].value
          this.packetNameChanged(this.selectedPacketName)
        }
        const item = this.packetNames.find((packet) => {
          return packet.value === this.selectedPacketName
        })
        if (this.chooseItem) {
          this.updateItems()
        }
        this.internalDisabled = false
      })
    },

    updateItems: function () {
      if (this.selectedPacketName === 'ALL') {
        return
      }
      this.internalDisabled = true
      const cmd = this.mode === 'tlm' ? 'get_telemetry' : 'get_command'
      this.api[cmd](this.selectedTargetName, this.selectedPacketName).then(
        (packet) => {
          this.itemNames = packet.items
            .map((item) => {
              if (this.reduced === 'DECOM') {
                return [
                  {
                    label: item.name,
                    value: item.name,
                    description: item.description,
                  },
                ]
              } else {
                return this.makeReducedItems(item)
              }
            })
            .reduce((result, item) => {
              return result.concat(item)
            }, [])
          if (this.allowAll) {
            this.itemNames.unshift(this.ALL)
          }
          if (!this.selectedItemName) {
            this.selectedItemName = this.itemNames[0].value
          }
          this.description = this.itemNames[0].description
          this.internalDisabled = false
          this.$emit('on-set', {
            targetName: this.selectedTargetName,
            packetName: this.selectedPacketName,
            itemName: this.selectedItemName,
            reduced: this.reduced,
          })
        }
      )
    },

    makeReducedItems: function (item) {
      const reducedOptions = !item.array_size && !item.states
      if (reducedOptions && ['UINT', 'INT', 'FLOAT'].includes(item.data_type)) {
        return ['MIN', 'MAX', 'AVG', 'STDDEV'].map((ext) => {
          return {
            label: `${item.name}_${ext}`,
            value: `${item.name}_${ext}`,
            description: `${ext} ${item.description}`,
          }
        })
      }
      return []
    },

    targetNameChanged: function (value) {
      this.selectedTargetName = value
      this.selectedPacketName = ''
      this.selectedItemName = ''
      this.updatePackets()
    },

    packetNameChanged: function (value) {
      if (value === 'ALL') {
        this.itemsDisabled = true
        this.internalDisabled = false
      } else {
        this.itemsDisabled = false
        const packet = this.packetNames.find((packet) => {
          return value === packet.value
        })
        this.selectedPacketName = packet.value
        const cmd = this.mode === 'tlm' ? 'get_telemetry' : 'get_command'
        this.api[cmd](this.selectedTargetName, this.selectedPacketName).then(
          (packet) => {
            this.description = packet.description
          }
        )
      }
      if (this.chooseItem) {
        this.selectedItemName = ''
        this.updateItems()
      } else {
        this.$emit('on-set', {
          targetName: this.selectedTargetName,
          packetName: this.selectedPacketName,
          reduced: this.reduced,
        })
      }
    },

    itemNameChanged: function (value) {
      const item = this.itemNames.find((item) => {
        return value === item.value
      })
      this.selectedItemName = item.value
      this.description = item.description
      this.$emit('on-set', {
        targetName: this.selectedTargetName,
        packetName: this.selectedPacketName,
        itemName: this.selectedItemName,
        reduced: this.reduced,
      })
    },

    buttonPressed: function () {
      if (this.selectedPacketName === 'ALL') {
        this.allTargetPacketItems()
      } else if (this.selectedItemName === 'ALL') {
        this.allPacketItems()
      } else if (this.chooseItem) {
        this.$emit('click', {
          targetName: this.selectedTargetName,
          packetName: this.selectedPacketName,
          itemName: this.selectedItemName,
          reduced: this.reduced,
        })
      } else {
        this.$emit('click', {
          targetName: this.selectedTargetName,
          packetName: this.selectedPacketName,
          reduced: this.reduced,
        })
      }
    },

    allTargetPacketItems: function () {
      this.packetNames.forEach((packetName) => {
        if (packetName === this.ALL) return
        const cmd = this.mode === 'tlm' ? 'get_telemetry' : 'get_command'
        this.api[cmd](this.selectedTargetName, packetName.value).then(
          (packet) => {
            packet.items.forEach((item) => {
              this.$emit('click', {
                targetName: this.selectedTargetName,
                packetName: packetName.value,
                itemName: item['name'],
                reduced: this.reduced,
              })
            })
          }
        )
      })
    },

    allPacketItems: function () {
      this.itemNames.forEach((item) => {
        if (item === this.ALL) return
        this.$emit('click', {
          targetName: this.selectedTargetName,
          packetName: this.selectedPacketName,
          itemName: item.value,
          reduced: this.reduced,
        })
      })
    },
  },
}
</script>
