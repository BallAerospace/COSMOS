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
    <v-select
      v-model="operandType"
      :items="operandTypes"
      label="OperandType"
      class="mt-1"
    />
    <div v-if="operandType == 'ITEM'">
      <v-row class="ma-0">
        <v-radio-group
          v-model="itemValue"
          class="px-2"
          row
          @change="itemValueSelected"
        >
          <v-radio label="RAW" value="RAW" />
          <v-radio label="CONVERTED" value="CONVERTED" />
        </v-radio-group>
      </v-row>
      <target-packet-item-chooser vertical choose-item @on-set="itemSelected" />
    </div>
    <div v-if="operandType === 'FLOAT'">
      <v-text-field
        :rules="[rules.required]"
        label="Input Float Value"
        type="number"
        @change="floatSelected"
      />
    </div>
    <div v-if="operandType === 'STRING'">
      <v-text-field
        :rules="[rules.required]"
        label="Input String Value"
        type="string"
        @change="stringSelected"
      />
    </div>
    <div v-if="operandType === 'LIMIT'">
      <v-select
        v-model="limitColor"
        :items="limitColors"
        label="Limit Color"
        class="mt-1"
        @change="limitSelected"
      />
      <v-select
        v-model="limitType"
        :items="limitTypes"
        label="Limit Type"
        class="mt-1"
        @change="limitSelected"
      />
    </div>
    <div v-if="operandType === 'TRIGGER'">
      <v-select
        :items="triggerItems"
        label="Dependent Trigger"
        class="mt-3"
        @change="triggerSelected"
      />
    </div>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import TargetPacketItemChooser from '@cosmosc2/tool-common/src/components/TargetPacketItemChooser'

export default {
  components: {
    TargetPacketItemChooser,
  },
  props: {
    value: {
      type: String,
      required: true,
    },
    triggers: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      api: null,
      limitType: '',
      limitColor: '',
      operandType: '',
      itemValue: 'RAW',
      operand: {},
      rules: {
        required: (value) => !!value || 'Required',
      },
    }
  },
  created() {},
  computed: {
    kind: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
    limitColors: function () {
      return ['RED', 'YELLOW', 'GREEN', 'BLUE']
    },
    limitTypes: function () {
      return [
        { text: '', value: '' },
        { text: 'LOW', value: '_LOW' },
        { text: 'HIGH', value: '_HIGH' },
      ]
    },
    operandTypes: function () {
      switch (this.kind) {
        case 'FLOAT':
          return ['ITEM', 'FLOAT']
        case 'STRING':
          return ['ITEM', 'STRING']
        case 'ITEM':
          return ['ITEM', 'FLOAT', 'STRING', 'LIMIT']
        case 'TRIGGER':
          return ['TRIGGER']
        default:
          return ['ITEM', 'FLOAT', 'STRING', 'LIMIT', 'TRIGGER']
      }
    },
    triggerItems: function () {
      return this.triggers.map((t) => {
        return { text: `${t.name} (${t.description})`, value: t.name }
      })
    },
  },
  watch: {
    // This is mainly used when a user resets the CreateDialog
    kind: function (newVal, oldVal) {
      if (newVal === '') {
        this.operandType = ''
      }
    },
    // This updates kind and will reset the operand if the operandType changes
    operandType: function (newVal, oldVal) {
      if (newVal === 'FLOAT' && !this.kind) {
        this.kind = 'FLOAT'
      } else if (newVal === 'LIMIT' && !this.kind) {
        this.kind = 'LIMIT'
      } else if (newVal === 'STRING' && !this.kind) {
        this.kind = 'STRING'
      } else if (newVal === 'TRIGGER' && !this.kind) {
        this.kind = 'TRIGGER'
      }
      if (newVal !== oldVal) {
        this.operand = {}
      }
    },
    // When the operand changes emit the new Value
    operand: function (newVal, oldVal) {
      this.$emit('set', newVal)
    },
  },
  methods: {
    itemValueSelected: function (event) {
      this.operand = {
        ...this.operand,
        raw: this.itemValue === 'RAW',
      }
    },
    itemSelected: function (event) {
      this.operand = {
        type: 'item',
        target: event.targetName,
        packet: event.packetName,
        item: event.itemName,
        raw: this.itemValue === 'RAW',
      }
    },
    floatSelected: function (event) {
      this.operand = {
        type: 'float',
        float: parseFloat(event),
      }
    },
    stringSelected: function (event) {
      this.operand = {
        type: 'string',
        string: event,
      }
    },
    limitSelected: function (event) {
      this.operand = {
        type: 'limit',
        limit: `${this.limitColor}${this.limitType}`,
      }
    },
    triggerSelected: function (event) {
      this.operand = {
        type: 'trigger',
        trigger: event,
      }
    },
  },
}
</script>

<style scoped>
input[type='number'] {
  -moz-appearance: textfield;
}

input::-webkit-outer-spin-button,
input::-webkit-inner-spin-button {
  -webkit-appearance: none;
}
</style>
