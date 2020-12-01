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
        ></v-select>
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
        ></v-select>
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
        ></v-select>
      </v-col>
      <v-col v-if="buttonText">
        <v-btn
          color="primary"
          :disabled="buttonDisabled"
          @click="buttonPressed"
          >{{ actualButtonText }}</v-btn
        >
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
    })
  },
  watch: {
    mode: function (val) {
      this.updatePackets()
      this.itemNames = []
    },
  },
  methods: {
    updatePackets() {
      this.internalDisabled = true
      if (this.mode == 'cmd') {
        this.api['get_all_commands'](this.selectedTargetName).then(
          (commands) => {
            this.packet_list_items = []
            this.packetNames = []
            if (this.allowAll) {
              this.packetNames.push(this.ALL)
            }
            commands.forEach((command) => {
              this.packet_list_items.push([
                command.packet_name,
                command.description,
              ])
              this.packetNames.push({
                label: command.packet_name,
                value: command.packet_name,
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
          }
        )
      } else {
        this.api['get_tlm_list'](this.selectedTargetName).then((packets) => {
          this.packet_list_items = packets
          this.packetNames = []
          if (this.allowAll) {
            this.packetNames.push(this.ALL)
          }
          var arrayLength = packets.length
          for (var i = 0; i < arrayLength; i++) {
            this.packetNames.push({
              label: packets[i][0],
              value: packets[i][0],
            })
          }
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
      }
    },

    updateItems() {
      this.internalDisabled = true
      let cmd = 'get_tlm_item_list'
      if (this.mode == 'cmd') {
        cmd = 'get_cmd_param_list'
      }
      this.api[cmd](this.selectedTargetName, this.selectedPacketName).then(
        (items) => {
          this.tlm_item_list_items = items
          this.itemNames = []
          if (this.allowAll) {
            this.itemNames.push(this.ALL)
          }
          var arrayLength = items.length
          for (var i = 0; i < arrayLength; i++) {
            this.itemNames.push({ label: items[i][0], value: items[i][0] })
          }
          if (!this.selectedItemName) {
            this.selectedItemName = this.itemNames[0].value
          }
          this.description = this.tlm_item_list_items[0][2]
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
        if (value === this.tlm_item_list_items[i][0]) {
          this.selectedItemName = this.tlm_item_list_items[i][0]
          this.description = this.tlm_item_list_items[i][2]
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
        this.packetNames.forEach((packet) => {
          if (packet === this.ALL) return
          let cmd = 'get_tlm_item_list'
          if (this.mode == 'cmd') {
            cmd = 'get_cmd_param_list'
          }
          this.api[cmd](this.selectedTargetName, packet.value).then((items) => {
            items.forEach((item) => {
              this.$emit('click', {
                targetName: this.selectedTargetName,
                packetName: packet.value,
                itemName: item[0],
              })
            })
          })
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
