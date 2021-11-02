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
    <v-sheet>
      <v-toolbar>
        <v-toolbar-title v-text="title" />
        <v-spacer />
        <v-btn
          v-if="selected.length > 0"
          icon
          class="ma-2"
          data-test="multiDeleteActivity"
          @click="multiDeleteActivity()"
        >
          <v-icon>mdi-delete</v-icon>
        </v-btn>
        <activity-create-dialog
          v-model="showCreateDialog"
          v-on="$listeners"
          :timeline="activities[0].name"
          :display-time-in-utc="displayTimeInUtc"
        />
      </v-toolbar>
    </v-sheet>
    <v-data-table
      v-model="selected"
      item-key="activityId"
      class="mt-1"
      show-expand
      show-select
      :headers="activityHeaders"
      :items="listData"
      :single-expand="singleExpand"
      :expanded.sync="expanded"
    >
      <template v-slot:item.actions="{ item }">
        <v-row>
          <v-menu offset-y>
            <template v-slot:activator="{ on, attrs }">
              <v-btn
                class="mt-1"
                data-test="activityActions"
                icon
                v-bind="attrs"
                v-on="on"
              >
                <v-icon>mdi-dots-vertical</v-icon>
              </v-btn>
            </template>
            <v-list>
              <v-list-item-group>
                <v-list-item
                  data-test="viewActivity"
                  @click="eventDialog(item)"
                >
                  <v-list-item-icon>
                    <v-icon> mdi-eye </v-icon>
                  </v-list-item-icon>
                  <v-list-item-title> View Activity </v-list-item-title>
                </v-list-item>
                <v-divider />
                <v-list-item
                  data-test="updateActivity"
                  @click="updateDialog(item)"
                >
                  <v-list-item-icon>
                    <v-icon> mdi-pencil </v-icon>
                  </v-list-item-icon>
                  <v-list-item-title> Update Activity </v-list-item-title>
                </v-list-item>
                <v-divider />
                <v-list-item
                  data-test="deleteActivity"
                  @click="deleteDialog(item)"
                >
                  <v-list-item-icon>
                    <v-icon> mdi-delete </v-icon>
                  </v-list-item-icon>
                  <v-list-item-title> Delete Activity </v-list-item-title>
                </v-list-item>
              </v-list-item-group>
            </v-list>
          </v-menu>
        </v-row>
      </template>
      <template v-slot:no-data>
        <v-btn color="primary" @click="() => $emit('update', title)">
          Refresh
        </v-btn>
      </template>
      <template v-slot:expanded-item="{ headers, item }">
        <td :colspan="headers.length">
          <event-timeline
            show-icon
            :events="item.events"
            :display-time-in-utc="displayTimeInUtc"
          />
        </td>
      </template>
    </v-data-table>
    <!-- Note we're using v-if here so it gets re-created each time and refreshes the list -->
    <activity-event-dialog
      v-if="showActivityDialog"
      v-model="showActivityDialog"
      :activity="selectedActivity"
      :display-time-in-utc="displayTimeInUtc"
    />
    <activity-update-dialog
      v-if="showUpdateDialog"
      v-model="showUpdateDialog"
      :activity="selectedActivity"
      :display-time-in-utc="displayTimeInUtc"
      @close="activityCallback"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import { isValid, parse, format, getTime } from 'date-fns'
import ActivityCreateDialog from '@/tools/Timeline/ActivityCreateDialog'
import ActivityEventDialog from '@/tools/Timeline/ActivityEventDialog'
import ActivityUpdateDialog from '@/tools/Timeline/ActivityUpdateDialog'
import EventTimeline from '@/tools/Timeline/EventTimeline'
import TimeFilters from './util/timeFilters.js'

export default {
  components: {
    ActivityCreateDialog,
    ActivityEventDialog,
    ActivityUpdateDialog,
    EventTimeline,
  },
  mixins: [TimeFilters],
  props: {
    activities: {
      type: Array,
      required: true,
    },
    displayTimeInUtc: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return {
      searchDate: format(new Date(), 'yyyy-MM-dd'),
      showCreateDialog: false,
      showActivityDialog: false,
      showUpdateDialog: false,
      selectedActivitiesOn: false,
      selectedOpen: false,
      singleExpand: false,
      selectedActivity: null,
      expanded: [],
      selected: [],
      activityHeaders: [
        {
          text: 'Timeline',
          align: 'start',
          sortable: false,
          value: 'name',
        },
        { text: 'Start Time', value: 'startStr' },
        { text: 'Stop Time', value: 'stopStr' },
        { text: 'Kind', value: 'kind' },
        { text: 'Complete', value: 'fulfillment', sortable: false },
        { text: 'Actions', value: 'actions', sortable: false },
        { text: '', value: 'data-table-expand' },
      ],
    }
  },
  computed: {
    title: function () {
      if (!this.activities) return 'Timeline'
      return this.activities.map((timeline) => timeline.name).join(', ')
    },
    singleTimeline: function () {
      if (!this.activities) return false
      return this.activities.length === 1
    },
    listData: function () {
      if (!this.activities) return []
      let activityId = 0
      return this.activities.flatMap((timeline) =>
        timeline.activities.map((activity) => {
          activityId += 1
          const startDate = new Date(activity.start * 1000)
          const stopDate = new Date(activity.stop * 1000)
          let startStr, stopStr
          if (this.displayTimeInUtc) {
            startStr = startDate.toUTCString()
            stopStr = stopDate.toUTCString()
          } else {
            startStr = startDate.toLocaleString()
            stopStr = stopDate.toLocaleString()
          }
          return {
            ...activity,
            startStr,
            stopStr,
            activityId,
          }
        })
      )
    },
    selectedData: function () {
      return this.activities.flatMap((timeline) =>
        timeline.activities.map((activity) => {
          return {
            id: activity.start,
            name: activity.name,
          }
        })
      )
    },
    selectedActivities: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  mounted: function () {
    // console.log(this.activities)
  },
  methods: {
    eventDialog: function (activity) {
      this.selectedActivity = activity
      this.showActivityDialog = !this.showActivityDialog
    },
    updateDialog: function (activity) {
      this.selectedActivity = activity
      this.showUpdateDialog = !this.showUpdateDialog
    },
    deleteDialog: function (activity) {
      const activityTime = this.generateDateTime(activity)
      this.$dialog
        .confirm(
          `Are you sure you want to remove activity: ${activityTime} (${activity.start}) from timeline: ${activity.name}`,
          {
            okText: 'Delete',
            cancelText: 'Cancel',
          }
        )
        .then((dialog) => {
          return Api.delete(
            `/cosmos-api/timeline/${activity.name}/activity/${activity.start}`
          )
        })
        .then((response) => {
          const alertObject = {
            text: `Deleted activity: ${activityTime} (${activity.start}) from timeline: ${activity.name}`,
            type: 'warning',
          }
          this.$emit('alert', alertObject)
          this.$emit('close')
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to delete activity ${activity.start} from timeline: ${activity.name}. Error: ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
    },
    multiDeleteActivity: function () {
      const toDelete = this.selected.map((activity) => {
        return { name: activity.name, id: activity.start }
      })
      this.$dialog
        .confirm(
          `${this.selected.length} selected activities. Are you sure you?`,
          {
            type: 'hard',
            verification: 'delete',
          }
        )
        .then((dialog) => {
          return Api.post('/cosmos-api/timeline/activities/delete', {
            data: {
              multi: toDelete,
            },
          })
        })
        .then((response) => {
          const alertObject = {
            text: `Deleted ${response.data.length} Activities Complete`,
            type: 'success',
          }
          this.$emit('alert', alertObject)
          this.$emit('update')
          this.selected = []
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed Multi-Delete. ${error}`,
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
