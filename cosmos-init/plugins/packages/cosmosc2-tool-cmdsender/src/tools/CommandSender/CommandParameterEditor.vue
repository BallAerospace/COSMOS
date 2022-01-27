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
    <v-text-field
      v-if="states === null"
      :value="value.val"
      hide-details
      dense
      @change="handleChange"
      data-test="cmd-param-value"
    />
    <v-container v-else>
      <v-row no-gutters>
        <v-col>
          <v-overflow-btn
            :items="states"
            v-model="value.selected_state"
            @change="handleStateChange"
            item-text="label"
            item-value="value"
            label="State"
            style="primary"
            class="mr-4"
            hide-details
            dense
            data-test="cmd-param-select"
          />
        </v-col>
        <v-col>
          <v-text-field
            :value="stateValue"
            @change="handleChange"
            hide-details
            dense
            data-test="cmd-param-value"
          />
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
export default {
  model: {
    prop: 'initialValue',
    event: 'input',
  },
  props: {
    statesInHex: {
      type: Boolean,
      default: false,
    },
    initialValue: {
      type: Object,
      default: () => ({
        val: '',
        states: null,
        selected_state: null,
        selected_state_label: '',
        manual_value: null,
      }),
    },
  },
  data() {
    return {
      value: this.initialValue,
    }
  },
  computed: {
    stateValue() {
      if (this.statesInHex) {
        return '0x' + this.value.val.toString(16)
      } else {
        return this.value.val
      }
    },
    states() {
      if (this.value.states != null) {
        var calcStates = []
        for (var key in this.value.states) {
          if (Object.prototype.hasOwnProperty.call(this.value.states, key)) {
            calcStates.push({ label: key, value: this.value.states[key].value })
          }
        }
        calcStates.push({
          label: 'MANUALLY ENTERED',
          value: 'MANUALLY ENTERED',
        })

        // TBD pick default better (use actual default instead of just first item in list)
        return calcStates
      } else {
        return null
      }
    },
  },
  methods: {
    handleChange(value) {
      this.value.val = value
      this.value.manual_value = value
      if (this.value.states) {
        var selected_state = 'MANUALLY ENTERED'
        var selected_state_label = 'MANUALLY_ENTERED'
        for (const state of this.states) {
          if (state.value === parseInt(value)) {
            selected_state = parseInt(value)
            selected_state_label = state.label
            break
          }
        }
        this.value.selected_state = selected_state
        this.value.selected_state_label = selected_state_label
      } else {
        this.value.selected_state = null
      }
      this.$emit('input', this.value)
    },

    handleStateChange(value) {
      var selected_state_label = null
      var selected_state = null
      for (var index = 0; index < this.states.length; index++) {
        if (value == this.states[index].value) {
          selected_state_label = this.states[index].label
          selected_state = value
          break
        }
      }
      this.value.selected_state_label = selected_state_label
      if (selected_state_label == 'MANUALLY ENTERED') {
        this.value.val = this.value.manual_value
        // Stop propagation of the click event so the editor stays active
        // to let the operator enter a manual value.
        // event.originalEvent.stopPropagation()
      } else {
        this.value.val = selected_state
        this.$emit('input', this.value)
      }
    },
  },
}
</script>
<style scoped>
.v-overflow-btn {
  margin-top: 0px;
}
.container {
  padding: 0px;
}
</style>
