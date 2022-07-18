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
  <div>
    <v-dialog v-model="show" width="600">
      <v-card>
        <v-system-bar>
          <v-tooltip top>
            <template v-slot:activator="{ on, attrs }">
              <div v-on="on" v-bind="attrs">
                <v-icon
                  data-test="trigger-create-reset-icon"
                  @click="resetHandler"
                >
                  mdi-redo
                </v-icon>
              </div>
            </template>
            <span> Reset </span>
          </v-tooltip>
          <v-spacer />
          <span> Create New Trigger </span>
          <v-spacer />
          <v-tooltip top>
            <template v-slot:activator="{ on, attrs }">
              <div v-on="on" v-bind="attrs">
                <v-icon
                  data-test="trigger-create-close-icon"
                  @click="clearHandler"
                >
                  mdi-close-box
                </v-icon>
              </div>
            </template>
            <span> Close </span>
          </v-tooltip>
        </v-system-bar>
        <v-card-text class="pa-5">
          <v-row>
            <v-text-field
              v-model="groupName"
              label="Group Name"
              data-test="group-name-input"
              dense
              outlined
              readonly
              hide-details
            />
          </v-row>
        </v-card-text>

        <v-stepper v-model="dialogStep" vertical non-linear>
          <v-stepper-step editable step="1">
            Input Left Operand: {{ leftOperandText }}
          </v-stepper-step>
          <v-stepper-content step="1">
            <trigger-operand
              v-model="kind"
              order="left"
              :triggers="triggers"
              @set="(event) => operandChanged(event, 'left')"
            />
            <v-row class="ma-0">
              <v-spacer />
              <v-btn
                @click="dialogStep = 2"
                color="success"
                data-test="trigger-create-step-two-btn"
                :disabled="!leftOperand"
              >
                Continue
              </v-btn>
            </v-row>
          </v-stepper-content>

          <v-stepper-step editable step="2">
            Input Right Operand: {{ rightOperandText }}
          </v-stepper-step>
          <v-stepper-content step="2">
            <trigger-operand
              v-model="kind"
              order="right"
              :triggers="triggers"
              @set="(event) => operandChanged(event, 'right')"
            />
            <v-row class="ma-0">
              <v-spacer />
              <v-btn
                @click="dialogStep = 3"
                color="success"
                data-test="trigger-create-step-three-btn"
                :disabled="!rightOperand"
              >
                Continue
              </v-btn>
            </v-row>
          </v-stepper-content>

          <v-stepper-step editable step="3">
            Operator, Description, and Review
          </v-stepper-step>
          <v-stepper-content step="3">
            <v-row class="ma-0">
              <v-text-field
                v-model="evalDescription"
                label="Trigger Eval"
                data-test="trigger-create-eval"
                class="my-2"
                dense
                outlined
                readonly
                hide-details
              />
            </v-row>
            <v-row class="ma-0">
              <v-select
                v-model="operator"
                :items="operators"
                :disabled="operators.length <= 1"
                label="Operator"
                class="my-3"
                data-test="trigger-create-select-operator"
                dense
                hide-details
              >
                <template v-slot:item="{ item, attrs, on }">
                  <v-list-item
                    v-on="on"
                    v-bind="attrs"
                    :data-test="`trigger-create-select-operator-${item}`"
                  >
                    <v-list-item-content>
                      <v-list-item-title>{{ item }}</v-list-item-title>
                    </v-list-item-content>
                  </v-list-item>
                </template>
              </v-select>
            </v-row>
            <v-row class="ma-0">
              <v-text-field label="Trigger Description" v-model="description" />
            </v-row>
            <v-row class="ma-0">
              <span class="ma-2 red--text" v-show="error" v-text="error" />
            </v-row>
            <v-row class="ma-2">
              <v-spacer />
              <v-btn
                @click="clearHandler"
                outlined
                class="mr-4"
                data-test="trigger-create-cancel-btn"
              >
                Cancel
              </v-btn>
              <v-btn
                @click.prevent="submitHandler"
                type="submit"
                color="primary"
                data-test="trigger-create-submit-btn"
                :disabled="!!error"
              >
                Ok
              </v-btn>
            </v-row>
          </v-stepper-content>
        </v-stepper>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'

import TriggerOperand from '@/tools/Autonomic/Tabs/Triggers/TriggerOperand'

export default {
  components: {
    TriggerOperand,
  },
  props: {
    group: {
      type: String,
      required: true,
    },
    triggers: {
      type: Array,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      dialogStep: 1,
      rules: {
        required: (value) => !!value || 'Required',
      },
      kind: '',
      operator: '',
      description: '',
      leftOperand: null,
      rightOperand: null,
    }
  },
  created() {},
  computed: {
    groupName: function () {
      return this.group
    },
    leftOperandText: function () {
      const op = this.leftOperand
      if (!op) {
        return ''
      }
      if (op.type === 'item') {
        const valueType = op.raw ? 'RAW' : 'CONVERTED'
        return `${op.target} ${op.packet} ${op.item} (${valueType})`
      }
      return op[op.type]
    },
    rightOperandText: function () {
      const op = this.rightOperand
      if (!op) {
        return ''
      }
      if (op.type === 'item') {
        const valueType = op.raw ? 'RAW' : 'CONVERTED'
        return `${op.target} ${op.packet} ${op.item} (${valueType})`
      }
      return op[op.type]
    },
    evalDescription: function () {
      if (this.operator === '') {
        return ' '
      }
      return `${this.leftOperandText} ${this.operator} ${this.rightOperandText}`
    },
    operators: function () {
      switch (this.kind) {
        case 'FLOAT':
          return ['>', '<', '>=', '<=']
        case 'LIMIT':
        case 'STRING':
          return ['==', '!=']
        case 'TRIGGER':
          return ['AND', 'OR']
        default:
          return []
      }
    },
    event: function () {
      return {
        group: this.groupName,
        operator: this.operator,
        left: this.leftOperand,
        right: this.rightOperand,
        description: this.description,
      }
    },
    error: function () {
      if (this.operator === '') {
        return 'Trigger operator can not be blank.'
      }
      if (!this.leftOperand) {
        return 'Trigger left operand can not be blank.'
      }
      if (!this.rightOperand) {
        return 'Trigger right operand can not be blank.'
      }
      return null
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
  methods: {
    resetHandler: function () {
      this.kind = ''
      this.operator = ''
      this.leftOperand = null
      this.rightOperand = null
      this.dialogStep = 1
    },
    clearHandler: function () {
      this.show = !this.show
      this.resetHandler()
    },
    submitHandler(event) {
      Api.post(`/openc3-api/autonomic/${this.group}/trigger`, {
        data: this.event,
      }).then((response) => {})
      this.clearHandler()
    },
    operandChanged(event, operand) {
      // console.log(event)
      this[`${operand}Operand`] = event
    },
  },
}
</script>
