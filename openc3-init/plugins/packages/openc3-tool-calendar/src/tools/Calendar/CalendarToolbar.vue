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
    <v-toolbar class="my-1">
      <v-menu bottom right>
        <template v-slot:activator="{ on, attrs }">
          <div v-bind="attrs" v-on="on">
            <v-btn data-test="create-event" outlined>
              <v-icon left>mdi-plus-box</v-icon>
              <span>Create</span>
              <v-icon right>mdi-menu-down</v-icon>
            </v-btn>
          </div>
        </template>
        <v-list>
          <v-list-item data-test="note" @click="showNoteCreateDialog = true">
            <v-icon left>mdi-calendar-clock</v-icon>
            <v-list-item-title>Note</v-list-item-title>
          </v-list-item>
          <v-list-item
            data-test="metadata"
            @click="showMetadataCreateDialog = true"
          >
            <v-icon left>mdi-calendar-check</v-icon>
            <v-list-item-title>Metadata</v-list-item-title>
          </v-list-item>
          <v-list-item
            data-test="activity"
            @click="showActivityCreateDialog = true"
          >
            <v-icon left>mdi-calendar-question</v-icon>
            <v-list-item-title>Timeline Activity</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
      <v-btn outlined class="mx-3" data-test="today" @click="setToday">
        Today
      </v-btn>
      <v-btn fab text small data-test="prev" @click="prev">
        <v-icon small> mdi-chevron-left </v-icon>
      </v-btn>
      <v-btn fab text small data-test="next" @click="next">
        <v-icon small> mdi-chevron-right </v-icon>
      </v-btn>
      <!--- SPACER --->
      <v-spacer />
      <v-toolbar-title>{{ title }}</v-toolbar-title>
      <v-spacer />
      <!--- SPACER --->
      <v-menu bottom right>
        <template v-slot:activator="{ on, attrs }">
          <div v-bind="attrs" v-on="on">
            <v-btn icon data-test="settings" class="mx-2">
              <v-icon> mdi-cog </v-icon>
            </v-btn>
          </div>
        </template>
        <v-list>
          <v-list-item data-test="refresh" @click="refresh">
            <v-icon left> mdi-refresh </v-icon>
            <v-list-item-title> Refresh Display </v-list-item-title>
          </v-list-item>
          <v-list-item data-test="show-table" @click="showTable">
            <v-icon left> mdi-timetable </v-icon>
            <v-list-item-title> Show Table Display </v-list-item-title>
          </v-list-item>
          <v-list-item data-test="display-utc-time" @click="updateTime">
            <v-icon left> mdi-clock </v-icon>
            <v-list-item-title> Toggle UTC Display </v-list-item-title>
          </v-list-item>
          <v-list-item data-test="download-event-list" @click="downloadEvents">
            <v-icon left> mdi-download </v-icon>
            <v-list-item-title> Download Event List </v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
      <v-menu bottom right>
        <template v-slot:activator="{ on, attrs }">
          <div v-bind="attrs" v-on="on">
            <v-btn outlined data-test="change-type" width="125">
              <span>{{ typeToLabel[type] }}</span>
              <v-icon right> mdi-menu-down </v-icon>
            </v-btn>
          </div>
        </template>
        <v-list>
          <v-list-item data-test="type-day" @click="updateType('day')">
            <v-list-item-title> Day </v-list-item-title>
          </v-list-item>
          <v-list-item data-test="type-four-day" @click="updateType('4day')">
            <v-list-item-title>4 Days</v-list-item-title>
          </v-list-item>
          <v-list-item data-test="type-week" @click="updateType('week')">
            <v-list-item-title> Week </v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </v-toolbar>
    <!--- menus --->
    <event-list-dialog
      v-if="showEventTableDialog"
      v-model="showEventTableDialog"
      :events="events"
      :utc="utc"
    />
    <metadata-create-dialog
      v-if="showMetadataCreateDialog"
      v-model="showMetadataCreateDialog"
    />
    <note-create-dialog
      v-if="showNoteCreateDialog"
      v-model="showNoteCreateDialog"
    />
    <activity-create-dialog
      v-if="showActivityCreateDialog"
      v-model="showActivityCreateDialog"
      :timelines="timelines"
    />
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'
import { format } from 'date-fns'

import EventListDialog from '@/tools/Calendar/Dialogs/EventListDialog'
import ActivityCreateDialog from '@/tools/Calendar/Dialogs/ActivityCreateDialog'
import MetadataCreateDialog from '@/tools/Calendar/Dialogs/MetadataCreateDialog'
import NoteCreateDialog from '@/tools/Calendar/Dialogs/NoteCreateDialog'

export default {
  components: {
    EventListDialog,
    ActivityCreateDialog,
    MetadataCreateDialog,
    NoteCreateDialog,
  },
  props: {
    timelines: {
      type: Array,
      required: true,
    },
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
      typeToLabel: {
        week: 'Week',
        '4day': '4 Days',
        day: 'Day',
      },
      showEventTableDialog: false,
      showActivityCreateDialog: false,
      showMetadataCreateDialog: false,
      showNoteCreateDialog: false,
    }
  },
  computed: {
    monthNames: function () {
      return [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ]
    },
    title: function () {
      const d = this.value.focus ? new Date(this.value.focus) : new Date()
      const month = this.monthNames[d.getUTCMonth()]
      const year = d.getUTCFullYear()
      return `${month} ${year}`
    },
    utc: function () {
      return this.value.utc
    },
    focus: function () {
      return this.value.focus
    },
    type: function () {
      return this.value.type
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
  methods: {
    downloadEvents: function (type) {
      const output = JSON.stringify(this.events, null, 2)
      const blob = new Blob([output], {
        type: 'application/json',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_calendar_events.json'
      )
      link.click()
    },
    showTable: function () {
      this.showEventTableDialog = !this.showEventTableDialog
    },
    updateTime: function (type) {
      this.calendarConfiguration.utc = !this.calendarConfiguration.utc
    },
    updateType: function (type) {
      this.calendarConfiguration = {
        ...this.calendarConfiguration,
        type: type,
      }
      this.type = type
    },
    setToday: function () {
      this.calendarConfiguration = {
        ...this.calendarConfiguration,
        focus: '',
      }
    },
    prev() {
      this.$emit('action', { method: 'prev' })
    },
    next() {
      this.$emit('action', { method: 'next' })
    },
    refresh() {
      this.$emit('action', { method: 'refresh' })
    },
  },
}
</script>
