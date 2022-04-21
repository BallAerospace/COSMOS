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
      label="OperandType"
      class="mt-1"
      :data-test="`trigger-operand-${order}-type`"
      :items="operandTypes"
    >
      <template v-slot:item="{ item, on, attrs }">
        <v-list-item
          v-on="on"
          v-bind="attrs" 
          :data-test="`trigger-operand-${order}-type-${item}`"
        >
          <v-list-item-content>
            <v-list-item-title v-text="item" />
          </v-list-item-content>
        </v-list-item>
      </template>
    </v-select>
    <div v-if="operandType === 'ITEM'">
      <v-row class="ma-0">
        <v-radio-group
          v-model="itemValue"
          class="px-2"
          row
          @change="itemValueSelected"
        >
          <v-radio
            label="RAW"
            value="RAW"
            :data-test="`trigger-operand-${order}-raw`"
          />
          <v-radio
            label="CONVERTED"
            value="CONVERTED"
            :data-test="`trigger-operand-${order}-converted`"
          />
        </v-radio-group>
      </v-row>
      <target-packet-item-chooser vertical choose-item @on-set="itemSelected" />
    </div>
    <div v-if="operandType === 'FLOAT'">
      <v-text-field
        label="Input Float Value"
        type="number"
        :data-test="`trigger-operand-${order}-float`"
        :rules="[rules.required]"
        @change="floatSelected"
      />
    </div>
    <div v-if="operandType === 'STRING'">
      <v-text-field
        label="Input String Value"
        type="string"
        :data-test="`trigger-operand-${order}-string`"
        :rules="[rules.required]"
        @change="stringSelected"
      />
    </div>
    <div v-if="operandType === 'LIMIT'">
      <v-select
        v-model="limitColor"
        label="Limit Color"
        class="mt-1"
        :data-test="`trigger-operand-${order}-color`"
        :items="limitColors"
        @change="limitSelected"
      >
        <template v-slot:item="{ item, on, attrs }">
          <v-list-item
            v-on="on"
            v-bind="attrs" 
            :data-test="`trigger-operand-${order}-color-${item}`"
          >
            <v-list-item-content>
              <v-list-item-title v-text="item" />
            </v-list-item-content>
          </v-list-item>
        </template>
      </v-select>
      <v-select
        v-model="limitType"
        class="mt-1"
        label="Limit Type"
        :data-test="`trigger-operand-${order}-limit`"
        :items="limitTypes"
        @change="limitSelected"
      >
        <template v-slot:item="{ item, on, attrs }">
          <v-list-item
            v-on="on"
            v-bind="attrs" 
            :data-test="`trigger-operand-${order}-limit-${item.text}`"
          >
            <v-list-item-content>
              <v-list-item-title v-text="item.text" />
            </v-list-item-content>
          </v-list-item>
        </template>
      </v-select>
    </div>
    <div v-if="operandType === 'TRIGGER'">
      <v-select
        class="mt-3"
        label="Dependent Trigger"
        :data-test="`trigger-operand-${order}-trigger`"
        :items="triggerItems"
        @change="triggerSelected"
      >
        <template v-slot:item="{ item, on, attrs }">
          <v-list-item
            v-on="on"
            v-bind="attrs" 
            :data-test="`trigger-operand-${order}-trigger-${item}`"
          >
            <v-list-item-content>
              <v-list-item-title v-text="item" />
            </v-list-item-content>
          </v-list-item>
        </template>
      </v-select>
    </div>
    <div v-if="operandType === ''">
      <v-row class="ma-0">
        <span class="ma-2 red--text">
          To continue select an operand type.
        </span>
      </v-row>
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
    order: {
      type: String,
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
    kind: {
      immediate: true,
      handler: function (newVal, oldVal) {
        if (newVal === '') {
          this.operandType = ''
        }
      },
    },
    // This updates kind and will reset the operand if the operandType changes
    operandType: {
      immediate: true,
      handler: function (newVal, oldVal) {
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
    },
    // When the operand changes emit the new Value
    operand: {
      immediate: true,
      handler: function (newVal, oldVal) {
        this.$emit('set', newVal)
      },
    }
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
