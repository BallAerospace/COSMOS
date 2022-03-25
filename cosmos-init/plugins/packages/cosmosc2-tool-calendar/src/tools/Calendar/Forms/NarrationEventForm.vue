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
    <v-card-title v-text="narrativeEvent.name" />
    <v-card-subtitle>
      <span>
        {{ narrativeEvent.start | dateTime(utc) }}
      </span>
      <br />
      <span>
        {{ narrativeEvent.end | dateTime(utc) }}
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
              <v-btn icon data-test="update-narration" @click="updateDialog">
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
              <v-btn icon data-test="delete-narration" @click="deleteDialog">
                <v-icon> mdi-delete </v-icon>
              </v-btn>
            </div>
          </template>
          <span> Delete </span>
        </v-tooltip>
      </v-card-actions>
    </div>
    <!--- Menus --->
    <narration-update-dialog
      v-model="showUpdateDialog"
      :narrative="narrativeEvent.narrative"
      @close="close"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'
import NarrationUpdateDialog from '@/tools/Calendar/Dialogs/NarrationUpdateDialog'

export default {
  components: {
    NarrationUpdateDialog,
  },
  mixins: [TimeFilters],
  props: {
    narrativeEvent: {
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
      const v = parseInt(this.narrativeEvent.narrative.updated_at / 1000000)
      return new Date(v)
    },
    description: function () {
      return this.narrativeEvent.narrative.description
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
      const narrationStart = this.narrativeEvent.narrative.start
      const eventStart = this.generateDateTime(
        this.narrativeEvent.start,
        this.utc
      )
      this.$dialog
        .confirm(
          `Are you sure you want to remove narration: ${eventStart} (${narrationStart})`,
          {
            okText: 'Delete',
            cancelText: 'Cancel',
          }
        )
        .then((dialog) => {
          return Api.delete(`/cosmos-api/narrative/${narrationStart}`)
        })
        .then((response) => {
          this.$notify.normal({
            title: 'Deleted Narration',
            body: `Deleted narration: ${eventStart} (${narrationStart})`,
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
