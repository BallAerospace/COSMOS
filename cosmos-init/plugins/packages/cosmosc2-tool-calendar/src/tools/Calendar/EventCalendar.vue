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
    <v-sheet height="800" class="mt-1">
      <v-calendar
        v-model="focus"
        ref="mainCalendar"
        color="primary"
        :events="events"
        :event-color="getEventColor"
        :type="type"
        @click:event="showEvent"
        @click:more="viewDay"
        @click:date="viewDay"
      >
        <!---
        <template v-slot:event="{ event }">
          <div class="mr-1">
            <span class="font-weight-bold" v-text="event.name" />
            <br />
            <span>{{ event.start | time(calendarConfiguration.utc) }}</span>
          </div>
        </template>
        --->
        <template v-slot:day-body="{ date, week }">
          <div
            class="v-current-time"
            :class="{ first: date === week[0].date }"
            :style="{ top: nowY }"
          />
        </template>
      </v-calendar>
      <v-menu
        v-model="selectedOpen"
        :close-on-content-click="false"
        :activator="selectedElement"
      >
        <event-dialog
          v-model="selectedOpen"
          :event="selectedEvent"
          :utc="utc"
          @close="close"
        />
      </v-menu>
    </v-sheet>
    <!-- MENUS -->
  </div>
</template>

<script>
import { isValid, parse, format, getTime } from 'date-fns'
import EventDialog from '@/tools/Calendar/Dialogs/EventDialog'
import TimeFilters from '@/tools/Calendar/Filters/timeFilters.js'
import { getTimelineEvents } from '@/tools/Calendar/Filters/timelineFilters.js'
import { getChronicleEvents } from '@/tools/Calendar/Filters/chronicleFilters.js'

export default {
  components: {
    EventDialog,
  },
  mixins: [TimeFilters],
  props: {
    events: {
      type: Array,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      selectedEvent: null,
      selectedElement: null,
      selectedOpen: false,
      showCreateDialog: false,
      showEventDialog: false,
      showUpdateDialog: false,
    }
  },
  watch: {
    events: function () {
      if (this.ready) {
        this.$refs.mainCalendar.checkChange()
      }
    },
  },
  computed: {
    cal: function () {
      return this.$refs.mainCalendar
    },
    nowY: function () {
      return this.ready ? this.cal.timeToY(this.cal.times.now) + 'px' : '-10px'
    },
    utc: {
      get() {
        return this.value.utc
      },
      set(value) {
        this.$emit('input', { ...this.value, utc: value }) // input is the default event when using v-model
      },
    },
    focus: {
      get() {
        return this.value.focus
      },
      set(value) {
        this.$emit('input', { ...this.value, focus: value }) // input is the default event when using v-model
      },
    },
    type: {
      get() {
        return this.value.type
      },
      set(value) {
        this.$emit('input', { ...this.value, type: value }) // input is the default event when using v-model
      },
    },
    calendarConfiguration: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  mounted() {
    this.ready = true
    this.scrollToTime()
    this.updateTime()
    this.cal.checkChange()
  },
  methods: {
    prev: function () {
      this.cal.prev()
    },
    next: function () {
      this.cal.next()
    },
    close: function () {
      this.selectedOpen = false
      this.selectedEvent = null
    },
    generateDateTime: function (activity) {
      if (!activity) return ''
      const date = new Date(activity.start * 1000)
      if (this.displayTimeInUtc) {
        return date.toUTCString()
      } else {
        return date.toLocaleString() // TODO: support other locales besides en-US
      }
    },
    getEventColor: function (event) {
      return event.color
    },
    getCurrentTime: function () {
      return this.ready
        ? this.cal.times.now.hour * 60 + this.cal.times.now.minute
        : 0
    },
    scrollToTime: function () {
      const time = this.getCurrentTime()
      const first = Math.max(0, time - (time % 30) - 30)
      this.cal.scrollToTime(first)
    },
    updateTime: function () {
      setInterval(() => this.cal.updateTimes(), 60 * 1000)
    },
    showEvent: function ({ nativeEvent, event }) {
      const open = () => {
        this.selectedEvent = event
        this.selectedElement = nativeEvent.target
        requestAnimationFrame(() =>
          requestAnimationFrame(() => (this.selectedOpen = true))
        )
      }
      if (this.selectedOpen) {
        this.selectedOpen = false
        requestAnimationFrame(() => requestAnimationFrame(() => open()))
      } else {
        open()
      }
      nativeEvent.stopPropagation()
    },
    eventDialog: function () {
      this.showEventDialog = !this.showEventDialog
    },
    updateDialog: function () {
      this.showUpdateDialog = !this.showUpdateDialog
    },
    viewDay: function ({ date }) {
      this.calendarConfiguration = {
        ...this.calendarConfiguration,
        type: 'day',
        focus: date,
      }
    },
  },
}
</script>

<style scoped lang="scss">
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
.v-current-time {
  height: 2px;
  background-color: #ea4335;
  position: absolute;
  left: -1px;
  right: 0;
  pointer-events: none;

  &.first::before {
    content: '';
    position: absolute;
    background-color: #ea4335;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    margin-top: -5px;
    margin-left: -6.5px;
  }
}
</style>
