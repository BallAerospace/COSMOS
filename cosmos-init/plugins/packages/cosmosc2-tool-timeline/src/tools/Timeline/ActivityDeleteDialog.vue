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
  <div>
    <v-tooltip v-if="icon" top>
      <template v-slot:activator="{ on, attrs }">
        <div v-on="on" v-bind="attrs">
          <v-btn icon data-test="deleteActivityIcon" @click="deleteActivity">
            <v-icon> mdi-delete </v-icon>
          </v-btn>
        </div>
      </template>
      <span> Delete Activity </span>
    </v-tooltip>
    <v-list-item v-else data-test="deleteActivity" @click="deleteActivity">
      <v-list-item-title> Delete Activity </v-list-item-title>
    </v-list-item>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import TimeFilters from './util/timeFilters.js'

export default {
  props: {
    activity: {
      type: Object,
      required: true,
    },
    displayTimeInUtc: {
      type: Boolean,
      required: true,
    },
    value: Boolean, // value is the default prop when using v-model
    icon: Boolean,
  },
  mixins: [TimeFilters],
  methods: {
    deleteActivity() {
      const activityTime = this.generateDateTime(this.activity)
      this.$dialog
        .confirm(
          `Are you sure you want to remove activity: ${activityTime} (${this.activity.start}) from timeline: ${this.activity.name}`,
          {
            okText: 'Delete',
            cancelText: 'Cancel',
          }
        )
        .then((dialog) => {
          return Api.delete(
            `/cosmos-api/timeline/${this.activity.name}/activity/${this.activity.start}`
          )
        })
        .then((response) => {
          const alertObject = {
            text: `Deleted activity: ${activityTime} (${this.activity.start}) from timeline: ${this.activity.name}`,
            type: 'warning',
          }
          this.$emit('alert', alertObject)
          this.$emit('close')
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to delete activity ${this.activity.start} from timeline: ${this.activity.name}. Error: ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
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
