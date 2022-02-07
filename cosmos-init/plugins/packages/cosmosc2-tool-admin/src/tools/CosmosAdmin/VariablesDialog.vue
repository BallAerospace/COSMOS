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
  <v-dialog persistent v-model="show" width="600">
    <v-card>
      <form v-on:submit.prevent="submit">
        <v-system-bar>
          <v-spacer />
          <span> Update Plugin Variables </span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <div class="pa-3">
            <template v-for="(plugin, index) of localVariables">
              <v-row class="mt-3" :key="index">
                <v-col cols="12">
                  <h3>{{ plugin.name }}</h3>
                </v-col>
              </v-row>
              <v-row class="mt-3" :key="plugin.name">
                <div v-for="(value, name) in plugin.variables" :key="name">
                  <v-col>
                    <v-text-field
                      clearable
                      type="text"
                      :label="name"
                      v-model="plugin.variables[name]"
                    />
                  </v-col>
                </div>
              </v-row>
              <v-divider
                :key="plugin.name"
                v-if="index != localVariables.length - 1"
              />
            </template>
            <v-row class="mt-1">
              <v-btn
                block
                color="primary"
                type="submit"
                data-test="variables-dialog-ok"
              >
                Ok
              </v-btn>
            </v-row>
          </div>
        </v-card-text>
      </form>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    variables: {
      type: Array,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      localVariables: [],
    }
  },
  computed: {
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
    value: {
      immediate: true,
      handler: function () {
        this.localVariables = JSON.parse(JSON.stringify(this.variables)).filter(
          (plugin) => Object.keys(plugin.variables).length > 0 // don't show plugins that don't have any variables
        )
      },
    },
  },
  methods: {
    submit: function () {
      const allVariables = this.variables
        .filter((plugin) => Object.keys(plugin.variables).length === 0) // need to send back these so they get iterated over for calling install phase 2
        .concat(this.localVariables)
      this.$emit('submit', allVariables)
    },
  },
}
</script>
