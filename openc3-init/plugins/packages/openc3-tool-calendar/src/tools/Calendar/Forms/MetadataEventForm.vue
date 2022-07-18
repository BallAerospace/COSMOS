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
    <v-card-title>{{ title }}</v-card-title>
    <v-card-subtitle>{{ metadataEvent.start | dateTime(utc) }}</v-card-subtitle>
    <div class="ma-2">
      <v-card-text>
        <v-row>
          <v-col class="pa-0">
            <v-simple-table dense>
              <tbody>
                <tr>
                  <th class="text-left">Key</th>
                  <th class="text-left">Value</th>
                </tr>
                <template v-for="(value, i) in metadataValues">
                  <tr :key="`tr-${i}`">
                    <td class="text-left">
                      <span v-text="value.key" />
                    </td>
                    <td class="text-left">
                      <span v-text="value.value" />
                    </td>
                  </tr>
                </template>
              </tbody>
            </v-simple-table>
          </v-col>
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
              <v-btn icon data-test="update-metadata" @click="updateDialog">
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
              <v-btn icon data-test="delete-metadata" @click="deleteDialog">
                <v-icon> mdi-delete </v-icon>
              </v-btn>
            </div>
          </template>
          <span> Delete </span>
        </v-tooltip>
      </v-card-actions>
    </div>
    <!--- Menus --->
    <metadata-update-dialog
      v-model="showUpdateDialog"
      :metadata-obj="metadataEvent.metadata"
      @close="close"
    />
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'
import MetadataUpdateDialog from '@/tools/Calendar/Dialogs/MetadataUpdateDialog'

export default {
  components: {
    MetadataUpdateDialog,
  },
  mixins: [TimeFilters],
  props: {
    metadataEvent: {
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
    metadataValues: function () {
      const metadata = this.metadataEvent.metadata.metadata
      return Object.keys(metadata).map((k) => {
        return { key: k, value: metadata[k] }
      })
    },
    updated_at: function () {
      const v = parseInt(this.metadataEvent.metadata.updated_at / 1000000)
      return new Date(v)
    },
    title: function () {
      return `${this.metadataEvent.metadata.type}`
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
      const metadataStart = this.metadataEvent.metadata.start
      const eventStart = this.generateDateTime(
        this.metadataEvent.start,
        this.utc
      )
      this.$dialog
        .confirm(
          `Are you sure you want to remove metadata: ${eventStart} (${metadataStart})`,
          {
            okText: 'Delete',
            cancelText: 'Cancel',
          }
        )
        .then((dialog) => {
          return Api.delete(`/openc3-api/metadata/${metadataStart}`)
        })
        .then((response) => {
          this.$notify.normal({
            title: 'Deleted Metadata',
            body: `Deleted metadata: ${eventStart} (${metadataStart})`,
          })
          this.$emit('close')
        })
        .catch((error) => {
          if (error) {
            this.$notify.error({
              title: 'Failed to Delete Metadata',
              body: `Failed to delete metadata ${metadataStart}. Error: ${error}`,
            })
          }
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
