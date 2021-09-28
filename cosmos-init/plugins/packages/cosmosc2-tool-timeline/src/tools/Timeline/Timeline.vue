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
    <top-bar :menus="menus" :title="title" />
    <v-container dense>
      <v-snackbar
        v-model="showAlert"
        :top="true"
        :color="alertType"
        :icon="alertType"
        :timeout="5000"
      >
        <v-icon> mdi-{{ alertType }} </v-icon>
        {{ alert }}
        <template v-slot:action="{ attrs }">
          <v-btn text v-bind="attrs" @click="showAlert = false"> Close </v-btn>
        </template>
      </v-snackbar>
      <!-- The left side of the screen to list timelines -->
      <v-row dense>
        <v-col :cols="3">
          <timeline-list
            v-model="checkedTimelines"
            @alert="alertHandler"
            :timelines="timelines"
          />
        </v-col>
        <!-- The rigt side of the view should be reserved for a search bar and a calendar -->
        <v-col :cols="9">
          <template v-if="checkedTimelines.length">
            <activity-calendar
              v-if="activityView == 'calendar'"
              @alert="alertHandler"
              @update="updateHandler"
              :activities="selectedActivities"
              :display-time-in-utc="displayTimeInUtc"
            />
            <activity-list
              v-else-if="activityView == 'list'"
              @alert="alertHandler"
              @update="updateHandler"
              :activities="selectedActivities"
              :display-time-in-utc="displayTimeInUtc"
            />
          </template>
          <span v-else> No timelines selected </span>
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import Cable from '@cosmosc2/tool-common/src/services/cable.js'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'
import TimelineList from '@/tools/Timeline/TimelineList'
import ActivityCalendar from '@/tools/Timeline/ActivityCalendar'
import ActivityList from '@/tools/Timeline/ActivityList'

export default {
  components: {
    TopBar,
    TimelineList,
    ActivityCalendar,
    ActivityList,
  },
  data() {
    return {
      title: 'Timeline',
      toolName: 'timeline',
      api: null,
      alert: '',
      alertType: 'success',
      showAlert: false,
      activityView: 'list',
      displayTimeInUtc: false,
      menus: [
        {
          label: 'View',
          radioGroup: 'List', // Default radio selected
          items: [
            {
              label: 'Refresh',
              icon: 'mdi-refresh',
              command: () => {
                this.refresh()
              },
            },
            {
              divider: true,
            },
            {
              label: 'List',
              radio: true,
              command: () => {
                this.activityView = 'list'
              },
            },
            {
              label: 'Calendar',
              radio: true,
              command: () => {
                this.activityView = 'calendar'
              },
            },
          ],
        },
        {
          label: 'Time',
          radioGroup: 'Local', // Default radio selected
          items: [
            {
              label: 'Local',
              radio: true,
              command: () => {
                this.displayTimeInUtc = false
              },
            },
            {
              label: 'UTC',
              radio: true,
              command: () => {
                this.displayTimeInUtc = true
              },
            },
          ],
        },
      ],
      timelines: [],
      checkedTimelines: [],
      selectedTimeline: null,
      selectedTimelinesOn: false,
      warning: false,
      warningText: '',
      error: false,
      errorText: '',
      allItemValueType: null,
      cable: new Cable(),
      subscription: null,
      activities: {},
    }
  },
  computed: {
    selectedActivities: function () {
      // this.activities = {
      //   "timelineName": [activity1, activity2, etc],
      //   "anotherTimeline": etc
      // }
      return this.checkedTimelines.map((timeline) => {
        return {
          name: timeline.name,
          color: timeline.color,
          messages: timeline.messages,
          activities: this.activities[timeline.name] || [],
        }
      })
    },
    eventHandlerFunctions: function () {
      return {
        timeline: {
          create: this.createTimelineFromEvent,
          refresh: this.refreshTimelineFromEvent,
          update: this.updateTimelineFromEvent,
          delete: this.removeTimelineFromEvent,
        },
        activity: {
          create: this.createActivityFromEvent,
          event: this.updateActivityFromEvent,
          update: this.refreshTimelineFromEvent,
          delete: this.removeActivityFromEvent,
        },
      }
    },
  },
  watch: {
    checkedTimelines: function () {
      this.updateActivities()
    },
  },
  created: function () {
    this.subscribe()
    this.getTimelines()
  },
  destroyed: function () {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    refresh: function () {
      this.getTimelines()
      for (const timeline of this.checkedTimelines) {
        this.updateActivities(timeline.name)
      }
    },
    alertHandler: function (event) {
      // console.log('alertHandler', event)
      this.alert = event.text
      this.alertType = event.type
      this.showAlert = true
    },
    updateHandler: function (event) {
      // console.log('updateHandler', event)
      if (event == null) {
        this.refresh()
      } else {
        this.updateActivities(event)
      }
    },
    setTimeline: function (timeline) {
      this.selectedTimeline = timeline
    },
    getTimelines: function () {
      return Api.get('/cosmos-api/timeline')
        .then((response) => {
          const timelineResponse = response.data
          timelineResponse.forEach((timeline) => {
            timeline.messages = 0
          })
          this.timelines = timelineResponse
        })
        .catch((error) => {
          const alertObject = {
            text: `Failed to get timelines. ${error}`,
            type: 'error',
          }
          this.alertHandler(alertObject)
        })
    },
    updateActivities: function (name = null) {
      const self = this
      const noLongerNeeded = Object.keys(this.activities).filter(
        (timeline) => !this.checkedTimelines.includes(timeline)
      )
      for (const timeline of noLongerNeeded) {
        delete this.activities[timeline.name]
      }
      let timelinesToUpdate
      if (name) {
        const inputTimeline = this.timelines.find(
          (timeline) => timeline.name === name
        )
        timelinesToUpdate = inputTimeline && [inputTimeline]
      } else {
        timelinesToUpdate = this.checkedTimelines
      }
      for (const timeline of timelinesToUpdate) {
        timeline.messages = 0
        if (name || !this.activities[timeline.name]) {
          Api.get(`/cosmos-api/timeline/${timeline.name}/activities`)
            .then((response) => {
              this.activities[timeline.name] = response.data
              this.activities = { ...this.activities } // New object reference to force reactivity
            })
            .catch((error) => {
              this.alert = error
              this.alertType = 'error'
              this.showAlert = true
            })
        }
      }
    },
    subscribe: function () {
      // TODO: need to see how to get scope
      this.cable
        .createSubscription('TimelineEventsChannel', localStorage.scope, {
          received: (data) => this.received(data),
        })
        .then((subscription) => {
          this.subscription = subscription
        })
    },
    received: function (data) {
      const parsed = JSON.parse(data)
      parsed.forEach((event) => {
        event.data = JSON.parse(event.data)
        // console.log(event)
        this.eventHandlerFunctions[event.type][event.kind](event)
      })
    },
    createTimelineFromEvent: function (event) {
      event.data.messages = 0
      this.timelines.push(event.data)
      this.activities[event.timeline] = []
    },
    refreshTimelineFromEvent: function (event) {
      this.updateActivities(event.timeline)
    },
    updateTimelineFromEvent: function (event) {
      const timelineIndex = this.timelines.findIndex(
        (timeline) => timeline.name === event.timeline
      )
      this.timelines[timelineIndex] = event.data
    },
    removeTimelineFromEvent: function (event) {
      const timelineIndex = this.timelines.findIndex(
        (timeline) => timeline.name === event.timeline
      )
      this.timelines.splice(timelineIndex, timelineIndex >= 0 ? 1 : 0)
      const checkedIndex = this.checkedTimelines.findIndex(
        (timeline) => timeline.name === event.timeline
      )
      this.checkedTimelines.splice(checkedIndex, checkedIndex >= 0 ? 1 : 0)
    },
    createActivityFromEvent: function (event) {
      this.incrementTimelineMessages(event.timeline)
      if (this.activities.hasOwnProperty(event.timeline)) {
        this.activities[event.timeline].push(event.data)
      }
    },
    updateActivityFromEvent: function (event) {
      this.incrementTimelineMessages(event.timeline)
      if (this.activities.hasOwnProperty(event.timeline)) {
        const activityIndex = this.activities[event.timeline].findIndex(
          (activity) => activity.start === event.data.start
        )
        this.activities[event.timeline][activityIndex] = event.data
      }
    },
    removeActivityFromEvent: function (event) {
      this.incrementTimelineMessages(event.timeline)
      if (this.activities.hasOwnProperty(event.timeline)) {
        const activityIndex = this.activities[event.timeline].findIndex(
          (activity) => activity.start === event.data.start
        )
        this.activities[event.timeline].splice(
          activityIndex,
          activityIndex >= 0 ? 1 : 0
        )
      }
    },
    incrementTimelineMessages: function (timelineName) {
      if (!this.checkedTimelines.includes(timelineName)) {
        this.timelines.find((timeline) => timeline.name === timelineName)
          .messages++
      }
    },
  },
}
</script>

<style lang="scss" scoped>
// Disable transition animations to allow bar to grow faster
.v-progress-linear__determinate {
  transition: none !important;
}
</style>
