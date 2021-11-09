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
  <v-dialog persistent v-model="show" width="600">
    <v-card>
      <form v-on:submit.prevent="submit">
        <v-system-bar>
          <v-spacer />
          <span v-text="title" />
          <v-spacer />
          <div class="mx-2">
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <div v-on="on" v-bind="attrs">
                  <v-btn icon data-test="downloadIcon" @click="download">
                    <v-icon> mdi-download </v-icon>
                  </v-btn>
                </div>
              </template>
              <span> Download </span>
            </v-tooltip>
          </div>
        </v-system-bar>

        <v-card-text>
          <div class="pa-3">
            <v-row class="mt-3"> Upload a file. </v-row>
            <v-row no-gutters align="center">
              <v-col cols="3">
                <v-btn
                  block
                  color="success"
                  @click="loadFile"
                  :disabled="!file || loadingFile || readonly"
                  :loading="loadingFile"
                  data-test="editScreenLoadBtn"
                >
                  Load
                  <template v-slot:loader>
                    <span>Loading...</span>
                  </template>
                </v-btn>
              </v-col>
              <v-col cols="9">
                <v-file-input
                  v-model="file"
                  accept=".json"
                  label="Click to select .json file."
                  :disabled="readonly"
                />
              </v-col>
            </v-row>
            <v-row> Edit json content </v-row>
            <v-row no-gutters>
              <v-textarea
                v-model="json_content"
                rows="15"
                :readonly="readonly"
                data-test="editTextInput"
              />
            </v-row>
            <v-row class="my-3">
              <span class="red--text" v-show="error" v-text="error" />
            </v-row>
            <v-row>
              <v-btn
                color="success"
                type="submit"
                :disabled="!!error || readonly"
                data-test="editSubmitBtn"
              >
                Save
              </v-btn>
              <v-spacer />
              <v-btn
                color="primary"
                @click.prevent="close"
                data-test="editCancelBtn"
              >
                Cancel
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
    content: {
      type: String,
      required: true,
    },
    title: String,
    value: Boolean, // value is the default prop when using v-model
    readonly: Boolean,
  },
  data() {
    return {
      json_content: this.content,
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
    error: function () {
      if (this.json_content === '' && !this.file) {
        return 'Input can not be blank.'
      }
      return null
    },
  },
  methods: {
    submit: function () {
      $emit('submit', json_content)
      this.json_content = null
      this.show = !this.show
    },
    close: function () {
      this.json_content = null
      this.show = !this.show
    },
    download: function () {
      const blob = new Blob([this.json_content], {
        type: 'text/plain',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute('download', `${this.title}.json`)
      link.click()
    },
  },
}
</script>

<style scoped>
.v-card {
  background-color: var(--v-tertiary-darken2);
}
.v-textarea >>> textarea {
  padding: 5px;
  background-color: var(--v-tertiary-darken1) !important;
}
</style>
