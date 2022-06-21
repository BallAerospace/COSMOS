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
  <v-dialog v-model="show" width="600">
    <v-card>
      <v-card-text>
      <v-row class="mt-3">
        <v-col cols="12">
          <h3>{{ plugin_name }}</h3>
        </v-col>
      </v-row>
      <v-tabs
        v-model="tab"
        background-color="primary"
        dark
      >
        <v-tab :key="0">
          Variables
        </v-tab>
        <v-tab :key="1">
          plugin.txt
        </v-tab>
        <v-tab v-if="existing_plugin_txt !== null" :key="2">
          Existing plugin.txt
        </v-tab>
      </v-tabs>

      <form v-on:submit.prevent="submit">
        <v-tabs-items v-model="tab">
          <v-tab-item :key="0">
            <v-card-text>
              <div class="pa-3">
                <v-row class="mt-3">
                  <div v-for="(value, name) in localVariables" :key="name">
                    <v-col>
                      <v-text-field
                        clearable
                        type="text"
                        :label="name"
                        v-model="localVariables[name]"
                      />
                    </v-col>
                  </div>
                </v-row>
              </div>
            </v-card-text>
          </v-tab-item>
          <v-tab-item :key="1">
            <v-textarea
              v-model="localPluginTxt"
              rows="15"
              data-test="editPluginTxt"
            />
          </v-tab-item>
          <v-tab-item v-if="existing_plugin_txt !== null" :key="2">
            <v-textarea
              v-model="localExistingPluginTxt"
              rows="15"
              data-test="editExistingPluginTxt"
            />
          </v-tab-item>
        </v-tabs-items>

        <v-row>
          <v-spacer />
          <v-btn
            @click.prevent="close"
            outlined
            class="mx-2"
            data-test="editCancelBtn"
          >
            Cancel
          </v-btn>
          <v-btn
            class="mx-2"
            color="primary"
            type="submit"
            data-test="variables-dialog-ok"
          >
            Ok
          </v-btn>
        </v-row>
      </form>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script>
export default {
  props: {
    plugin_name: {
      type: String,
      required: true
    },
    variables: {
      type: Object,
      required: true,
    },
    plugin_txt: {
      type: String,
      required: true
    },
    existing_plugin_txt: {
      type: String,
      required: false
    },
    value: Boolean, // value is the default prop when using v-model
  },
  data() {
    return {
      tab: 0,
      localVariables: [],
      localPluginTxt: "",
      localExistingPluginTxt: null
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
        this.localVariables = JSON.parse(JSON.stringify(this.variables)) // deep copy
        this.localPluginTxt = this.plugin_txt.slice()
        if (this.existing_plugin_txt != null) {
          this.ExistingPluginTxt = this.existing_plugin_txt.slice()
        }
      },
    },
  },
  methods: {
    submit: function () {
      let lines = this.localPluginTxt.split("\n")
      let plugin_hash = {
        name: this.plugin_name,
        variables: this.localVariables,
        plugin_txt_lines: lines
      }
      this.$emit('submit', plugin_hash)
    },
    close: function () {
      this.show = !this.show
    },
  },
}
</script>
