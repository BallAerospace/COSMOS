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
    <v-card-title>{{ noteEvent.name }}</v-card-title>
    <v-card-subtitle>
      <span>
        {{ noteEvent.start | dateTime(utc) }}
      </span>
      <br />
      <span>
        {{ noteEvent.end | dateTime(utc) }}
      </span>
    </v-card-subtitle>
    <div class="ma-2">
      <v-card-text>
        <v-row>
          <v-textarea readonly rows="6" :value="description" />
        </v-row>
        <v-row class="pt-1">
          <v-col class="text-right pa-0">
            <span class="text-caption">
              Last update: {{ updated_at | dateTime(utc) }}
            </span>
          </v-col>
        </v-row>
      </v-card-text>
      <v-card-actions class="pa-1">
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-btn icon data-test="update-note" @click="updateDialog">
                <v-icon>mdi-pencil</v-icon>
              </v-btn>
            </div>
          </template>
          <span> Update </span>
        </v-tooltip>
        <v-spacer />
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-btn icon data-test="delete-note" @click="deleteDialog">
                <v-icon> mdi-delete </v-icon>
              </v-btn>
            </div>
          </template>
          <span> Delete </span>
        </v-tooltip>
      </v-card-actions>
    </div>
    <!--- Menus --->
    <note-update-dialog
      v-model="showUpdateDialog"
      :note="noteEvent.note"
      @close="close"
    />
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'
import NoteUpdateDialog from '@/tools/Calendar/Dialogs/NoteUpdateDialog'

export default {
  components: {
    NoteUpdateDialog,
  },
  mixins: [TimeFilters],
  props: {
    noteEvent: {
      type: Object,
      required: true,
    },
    utc: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      showUpdateDialog: false,
    }
  },
  computed: {
    updated_at: function () {
      const v = parseInt(this.noteEvent.note.updated_at / 1000000)
      return new Date(v)
    },
    description: function () {
      return this.noteEvent.note.description
    },
  },
  methods: {
    close: function () {
      this.$emit('close')
    },
    updateDialog: function () {
      this.showUpdateDialog = !this.showUpdateDialog
    },
    deleteDialog: function () {
      const noteStart = this.noteEvent.note.start
      const eventStart = this.generateDateTime(this.noteEvent.start, this.utc)
      this.$dialog
        .confirm(
          `Are you sure you want to remove note: ${eventStart} (${noteStart})`,
          {
            okText: 'Delete',
            cancelText: 'Cancel',
          }
        )
        .then((dialog) => {
          return Api.delete(`/openc3-api/notes/${noteStart}`)
        })
        .then((response) => {
          this.$notify.normal({
            title: 'Deleted Note',
            body: `Deleted note: ${eventStart} (${noteStart})`,
          })
          this.$emit('close')
        })
    },
  },
}
</script>

<style scoped>
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
</style>
