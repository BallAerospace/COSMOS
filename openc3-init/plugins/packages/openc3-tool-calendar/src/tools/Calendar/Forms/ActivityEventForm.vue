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
    <v-card-title>
      <span v-text="activityEvent.name" />
      <v-spacer />
      <v-icon>
        {{ activityBadgeIcon }}
      </v-icon>
    </v-card-title>
    <v-card-subtitle>
      <span>
        {{ activityEvent.start | dateTime(utc) }}
      </span>
      <br />
      <span>
        {{ activityEvent.end | dateTime(utc) }}
      </span>
    </v-card-subtitle>
    <div class="ma-2">
      <v-card-text>
        <v-row>
          <v-col class="pa-0">
            <v-simple-table dense>
              <tbody>
                <tr>
                  <th class="text-left" width="100">Fulfilled</th>
                  <td v-text="activityFulfillment" />
                </tr>
                <tr>
                  <th class="text-left" v-text="activityKind" />
                  <td v-text="activityData[activityKind]" />
                </tr>
                <tr v-if="showEnv">
                  <th class="text-left">ENV</th>
                  <td v-text="activityEnvironment" />
                </tr>
              </tbody>
            </v-simple-table>
          </v-col>
        </v-row>
        <v-row>
          <v-col>
            <activity-event-timeline
              :activity-events="activityEvents"
              :utc="utc"
            />
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
      <v-card-actions>
        <div v-if="!activityEvent.fulfillment">
          <v-tooltip top>
            <template v-slot:activator="{ on, attrs }">
              <div v-on="on" v-bind="attrs">
                <v-btn icon data-test="update-activity" @click="updateDialog">
                  <v-icon> mdi-pencil </v-icon>
                </v-btn>
              </div>
            </template>
            <span> Update </span>
          </v-tooltip>
        </div>
        <v-spacer />
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-btn icon data-test="delete-activity" @click="deleteDialog">
                <v-icon> mdi-delete </v-icon>
              </v-btn>
            </div>
          </template>
          <span> Delete </span>
        </v-tooltip>
      </v-card-actions>
    </div>
    <!--- Menus --->
    <activity-update-dialog
      v-model="showUpdateDialog"
      :activity="activityEvent.activity"
      @close="close"
    />
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'
import ActivityEventTimeline from '@/tools/Calendar/Forms/ActivityEventTimeline'
import ActivityUpdateDialog from '@/tools/Calendar/Dialogs/ActivityUpdateDialog'

export default {
  components: {
    ActivityEventTimeline,
    ActivityUpdateDialog,
  },
  mixins: [TimeFilters],
  props: {
    activityEvent: {
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
    activityBadgeColor: function () {
      return this.activityEvent.activity.fulfillment ? '#4caf50' : '#ff5252'
    },
    activityBadgeIcon: function () {
      return this.activityEvent.activity.fulfillment
        ? 'mdi-check-circle'
        : 'mdi-close-circle'
    },
    activityFulfillment: function () {
      return this.activityEvent.activity.fulfillment
    },
    activityData: function () {
      return this.activityEvent.activity.data
    },
    activityKind: function () {
      return this.activityEvent.activity.kind
    },
    activityEnvironment: function () {
      return this.activityEvent.activity.data.environment
    },
    activityEvents: function () {
      return this.activityEvent.activity.events
    },
    showEnv: function () {
      return (
        this.activityEvent.activity.data.environment &&
        this.activityEvent.activity.data.environment.length > 0
      )
    },
    updated_at: function () {
      const v = parseInt(this.activityEvent.activity.updated_at / 1000000)
      return new Date(v)
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
      const activityTime = this.generateDateTime(this.activityEvent.start)
      const activityStart = this.activityEvent.activity.start
      const timelineName = this.activityEvent.activity.name
      this.$dialog
        .confirm(
          `Are you sure you want to remove activity: ${activityTime} (${activityStart}) from timeline: ${timelineName}`,
          {
            okText: 'Delete',
            cancelText: 'Cancel',
          }
        )
        .then((dialog) => {
          return Api.delete(
            `/openc3-api/timeline/${timelineName}/activity/${activityStart}`
          )
        })
        .then((response) => {
          this.$notify.normal({
            title: 'Deleted Activity from Timeline',
            body: `Deleted activity: ${activityTime} (${activityStart}) from timeline: ${timelineName}`,
          })
          this.$emit('close')
        })
        .catch((error) => {
          if (error) {
            this.$notify.error({
              title: 'Failed to Deleted Activity from Timeline',
              body: `Failed to delete activity ${activityStart} from timeline: ${timelineName}. Error: ${error}`,
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
