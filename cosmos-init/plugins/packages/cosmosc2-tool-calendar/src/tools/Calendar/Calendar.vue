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
    <top-bar :title="title" />
    <v-container dense>
      <v-row>
        <v-col class="pa-1">
          <calendar-toolbar
            v-model="calendarConfiguration"
            :timelines="timelines"
            :events="calendarEvents"
            @action="actionHandler"
          />
        </v-col>
      </v-row>
      <v-row>
        <v-col style="max-width: 300px">
          <mini-calendar v-model="calendarConfiguration" />
          <v-divider class="my-1" />
          <calendar-selector
            v-model="selectedCalendars"
            :timelines="timelines"
          />
        </v-col>
        <v-col class="pa-1">
          <event-calendar
            v-model="calendarConfiguration"
            ref="eventCalendar"
            :events="calendarEvents"
          />
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import Cable from '@cosmosc2/tool-common/src/services/cable.js'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'

import EventCalendar from '@/tools/Calendar/EventCalendar'
import CalendarToolbar from '@/tools/Calendar/CalendarToolbar'
import CalendarSelector from '@/tools/Calendar/CalendarSelector'
import MiniCalendar from '@/tools/Calendar/MiniCalendar'
import TimelineMethods from '@/tools/Calendar/Filters/timeFilters.js'
import { getTimelineEvents } from '@/tools/Calendar/Filters/timelineFilters.js'
import { getChronicleEvents } from '@/tools/Calendar/Filters/chronicleFilters.js'

export default {
  components: {
    EventCalendar,
    CalendarToolbar,
    CalendarSelector,
    MiniCalendar,
    TopBar,
  },
  mixins: [TimelineMethods],
  data() {
    return {
      title: 'Calendar',
      timelines: [],
      selectedCalendars: [],
      activities: {},
      calendarEvents: [],
      chronicles: { metadata: [], narrative: [] },
      calendarConfiguration: {
        utc: false,
        focus: '',
        type: '4day',
      },
      channels: ['TimelineEventsChannel', 'CalendarEventsChannel'],
      cable: new Cable(),
      subscriptions: [],
    }
  },
  computed: {
    eventHandlerFunctions: function () {
      return {
        timeline: {
          created: this.createdTimelineFromEvent,
          refresh: this.refreshTimelineFromEvent,
          updated: this.updatedTimelineFromEvent,
          deleted: this.deletedTimelineFromEvent,
        },
        activity: {
          event: this.eventActivityFromEvent,
          created: this.createdActivityFromEvent,
          updated: this.updatedActivityFromEvent,
          deleted: this.deletedActivityFromEvent,
        },
        calendar: {
          created: this.createdChronicleFromEvent,
          updated: this.updatedChronicleFromEvent,
          deleted: this.deletedChronicleFromEvent,
        },
      }
    },
  },
  watch: {
    selectedCalendars: {
      immediate: true,
      handler: function () {
        this.updateActivities()
      },
    },
    chronicles: {
      immediate: true,
      handler: function () {
        this.rebuildCalendarEvents()
      },
    },
    activities: {
      immediate: true,
      handler: function () {
        this.rebuildCalendarEvents()
      },
    },
  },
  created: function () {
    this.subscribe()
    this.getTimelines()
    this.updateMetadata()
    this.updateNarrative()
  },
  destroyed: function () {
    this.subscriptions.forEach((subscription) => {
      subscription.unsubscribe()
    })
    this.cable.disconnect()
  },
  methods: {
    actionHandler: function (event) {
      // console.log('actionHandler', event)
      if (event.method === 'next') {
        this.$refs.eventCalendar.next()
      } else if (event.method === 'prev') {
        this.$refs.eventCalendar.prev()
      } else if (event.method === 'refresh') {
        this.refresh()
      }
    },
    rebuildCalendarEvents: function () {
      const timelineEvents = getTimelineEvents(
        this.selectedCalendars,
        this.activities
      )
      const chronicleEvents = getChronicleEvents(
        this.selectedCalendars,
        this.chronicles
      )
      this.calendarEvents = timelineEvents.concat(chronicleEvents)
    },
    refresh: function () {
      this.updateActivities()
      this.updateMetadata()
      this.updateNarrative()
    },
    getTimelines: function () {
      Api.get('/cosmos-api/timeline').then((response) => {
        const timelineResponse = response.data
        timelineResponse.forEach((timeline) => {
          timeline.messages = 0
          timeline.type = 'timeline'
        })
        this.timelines = timelineResponse
      })
    },
    updateActivities: function (name = null) {
      // this.activities = {
      //   "timelineName": [activity1, activity2, etc],
      //   "anotherTimeline": etc
      // }
      const noLongerNeeded = Object.keys(this.activities).filter(
        (timeline) => !this.selectedCalendars.includes(timeline)
      )
      for (const timeline of noLongerNeeded) {
        delete this.activities[timeline.name]
      }
      if (noLongerNeeded) {
        this.activities = { ...this.activities } // New object reference to force reactivity
      }
      let timelinesToUpdate
      if (name) {
        const inputTimeline = this.timelines.find(
          (timeline) => timeline.name === name
        )
        timelinesToUpdate = inputTimeline && [inputTimeline]
      } else {
        timelinesToUpdate = this.selectedCalendars.filter(
          (calendar) => calendar.type === 'timeline'
        )
      }
      for (const timeline of timelinesToUpdate) {
        timeline.messages = 0
        if (name || !this.activities[timeline.name]) {
          Api.get(`/cosmos-api/timeline/${timeline.name}/activities`).then(
            (response) => {
              this.activities[timeline.name] = response.data
              this.activities = { ...this.activities } // New object reference to force reactivity
            }
          )
        }
      }
    },
    updateMetadata: function () {
      // this.chronicles = {
      //   "metadata": [event1, event2, etc],
      //   "narrative": etc
      // }
      Api.get(`/cosmos-api/metadata`).then((response) => {
        this.chronicles = {
          ...this.chronicles,
          metadata: response.data,
        }
      })
    },
    updateNarrative: function () {
      // this.chronicles = {
      //   "narrative": [event1, event2, etc],
      //   "metadata": etc
      // }
      Api.get(`/cosmos-api/note`).then((response) => {
        this.chronicles = {
          ...this.chronicles,
          narrative: response.data,
        }
      })
    },
    subscribe: function () {
      this.channels.forEach((channel) => {
        this.cable
          .createSubscription(channel, localStorage.scope, {
            received: (data) => this.received(data),
          })
          .then((subscription) => {
            this.subscriptions.push(subscription)
          })
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
    refreshTimelineFromEvent: function (event) {
      this.updateActivities(event.timeline)
    },
    createdTimelineFromEvent: function (event) {
      event.data.messages = 0
      event.data.type = 'timeline'
      this.timelines.push(event.data)
      this.activities[event.timeline] = []
    },
    updatedTimelineFromEvent: function (event) {
      const timelineIndex = this.timelines.findIndex(
        (timeline) => timeline.name === event.timeline
      )
      this.timelines[timelineIndex] = event.data
      this.timelines = this.timelines.slice()
      this.activities = { ...this.activities }
    },
    deletedTimelineFromEvent: function (event) {
      const timelineIndex = this.timelines.findIndex(
        (timeline) => timeline.name === event.timeline
      )
      this.timelines.splice(timelineIndex, timelineIndex >= 0 ? 1 : 0)
      const checkedIndex = this.selectedCalendars.findIndex(
        (timeline) => timeline.name === event.timeline
      )
      this.selectedCalendars.splice(checkedIndex, checkedIndex >= 0 ? 1 : 0)
    },
    createdActivityFromEvent: function (event) {
      this.incrementTimelineMessages(event.timeline)
      if (this.activities.hasOwnProperty(event.timeline)) {
        this.activities[event.timeline].push(event.data)
        this.activities = { ...this.activities }
      }
    },
    eventActivityFromEvent: function (event) {
      this.incrementTimelineMessages(event.timeline)
      if (this.activities.hasOwnProperty(event.timeline)) {
        const activityIndex = this.activities[event.timeline].findIndex(
          (activity) => activity.start === event.data.start
        )
        this.activities[event.timeline][activityIndex] = event.data
        this.activities = { ...this.activities }
      }
    },
    updatedActivityFromEvent: function (event) {
      event.extra = parseInt(event.extra)
      this.incrementTimelineMessages(event.timeline)
      if (this.activities.hasOwnProperty(event.timeline)) {
        const activityIndex = this.activities[event.timeline].findIndex(
          (activity) => activity.start === event.extra
        )
        this.activities[event.timeline][activityIndex] = event.data
        this.activities = { ...this.activities }
      }
    },
    deletedActivityFromEvent: function (event) {
      this.incrementTimelineMessages(event.timeline)
      if (this.activities.hasOwnProperty(event.timeline)) {
        const activityIndex = this.activities[event.timeline].findIndex(
          (activity) => activity.start === event.data.start
        )
        this.activities[event.timeline].splice(
          activityIndex,
          activityIndex >= 0 ? 1 : 0
        )
        this.activities = { ...this.activities }
      }
    },
    incrementTimelineMessages: function (timelineName) {
      if (!this.selectedCalendars.includes(timelineName)) {
        this.timelines.find((timeline) => timeline.name === timelineName)
          .messages++
      }
    },
    createdChronicleFromEvent: function (event) {
      const chronicleType = event.data.type
      this.chronicles[chronicleType].push(event.data)
      this.chronicles = { ...this.chronicles }
    },
    updatedChronicleFromEvent: function (event) {
      event.extra = parseInt(event.extra)
      const chronicleType = event.data.type
      const chronicleIndex = this.chronicles[chronicleType].findIndex(
        (calendarEvent) => calendarEvent.start === event.extra
      )
      this.chronicles[chronicleType][chronicleIndex] = event.data
      this.chronicles = { ...this.chronicles }
    },
    deletedChronicleFromEvent: function (event) {
      const chronicleType = event.data.type
      const chronicleIndex = this.chronicles[chronicleType].findIndex(
        (calendarEvent) => calendarEvent.start === event.data.start
      )
      this.chronicles[chronicleType].splice(
        chronicleIndex,
        chronicleIndex >= 0 ? 1 : 0
      )
      this.chronicles = { ...this.chronicles }
    },
  },
}
</script>
