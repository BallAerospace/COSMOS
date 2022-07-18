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
    <v-toolbar dense>
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-bind="attrs" v-on="on">
            <v-btn
              icon
              data-test="create-timeline"
              @click="showCreateDialog = true"
            >
              <v-icon>mdi-calendar-plus</v-icon>
            </v-btn>
          </div>
        </template>
        <span>Create Timeline</span>
      </v-tooltip>
      <v-spacer />
      <!--- <v-toolbar-title> Timelines </v-toolbar-title> --->
      <v-spacer />
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-bind="attrs" v-on="on">
            <v-btn
              icon
              data-test="view-environment-dialog"
              @click="showEnvironmentDialog = true"
            >
              <v-icon>mdi-library</v-icon>
            </v-btn>
          </div>
        </template>
        <span>Environment Dialog</span>
      </v-tooltip>
    </v-toolbar>
    <!--- SHOW TIMELINES --->
    <v-list flat>
      <v-subheader style="height: 25px">Calendar Events</v-subheader>
      <v-list-item-group multiple v-model="selectedChronicles" @change="select">
        <v-list-item data-test="select-metadata">
          <template v-slot:default="{ active }">
            <v-list-item-action>
              <v-checkbox :input-value="active" color="white accent-4" />
            </v-list-item-action>

            <v-list-item-content>
              <v-list-item-title>Metadata</v-list-item-title>
            </v-list-item-content>
          </template>
        </v-list-item>
        <v-list-item data-test="select-note">
          <template v-slot:default="{ active }">
            <v-list-item-action>
              <v-checkbox :input-value="active" color="white accent-4" />
            </v-list-item-action>

            <v-list-item-content>
              <v-list-item-title>Notes</v-list-item-title>
            </v-list-item-content>
          </template>
        </v-list-item>
      </v-list-item-group>
      <!--- TIMELINES --->
      <v-subheader style="height: 25px">Timelines</v-subheader>
      <v-list-item-group multiple v-model="selectedTimelines" @change="select">
        <template v-for="timeline in timelines">
          <v-list-item
            :value="timeline"
            :key="`timeline-${timeline.name}`"
            :data-test="`select-timeline-${timeline.name}`"
          >
            <template v-slot:default="{ active }">
              <v-list-item-action>
                <v-checkbox :input-value="active" color="white accent-4" />
              </v-list-item-action>

              <v-list-item-content>
                <v-badge
                  dot
                  bordered
                  inline
                  tile
                  :color="timeline.color"
                  :value="timeline.messages"
                >
                  <v-list-item-title>{{ timeline.name }}</v-list-item-title>
                </v-badge>
              </v-list-item-content>

              <v-list-item-action>
                <selector-options :timeline="timeline" />
              </v-list-item-action>
            </template>
          </v-list-item>
        </template>
      </v-list-item-group>
    </v-list>
    <!--- MENUS --->
    <environment-dialog v-model="showEnvironmentDialog" />
    <timeline-create-dialog v-model="showCreateDialog" :timelines="timelines" />
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'
import EnvironmentDialog from '@openc3/tool-common/src/components/EnvironmentDialog'
import SelectorOptions from '@/tools/Calendar/SelectorOptions'
import TimelineCreateDialog from '@/tools/Calendar/Dialogs/TimelineCreateDialog'

export default {
  components: {
    SelectorOptions,
    TimelineCreateDialog,
    EnvironmentDialog,
  },
  props: {
    timelines: {
      type: Array,
      required: true,
    },
    value: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      selectedTimelines: [],
      selectedChronicles: [0, 1],
      showCreateDialog: false,
      showEnvironmentDialog: false,
    }
  },
  mounted: function () {
    this.select()
  },
  computed: {
    sortedTimelines: function () {
      return [...this.timelines].sort((a, b) => (a.name > b.name ? 1 : -1))
    },
    selectedCalendars: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  methods: {
    select: function () {
      let t = this.selectedTimelines.map((timeline) => {
        timeline.messages = 0
        return { ...timeline }
      })
      if (this.selectedChronicles.indexOf(0) > -1) {
        t.push({ type: 'chronicle', name: 'metadata', messages: 0 })
      }
      if (this.selectedChronicles.indexOf(1) > -1) {
        t.push({ type: 'chronicle', name: 'note', messages: 0 })
      }
      this.selectedCalendars = t
    },
  },
}
</script>

<style scoped>
.selected-title {
  background-color: var(--v-secondary-base);
}
.available-title {
  background-color: var(--v-primary-darken2);
}
</style>
