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
    <v-toolbar>
      <v-toolbar-title> Timelines </v-toolbar-title>
      <v-spacer />
      <v-tooltip top v-if="selectedTimelinesOn">
        <template v-slot:activator="{ on, attrs }">
          <v-btn
            icon
            data-test="deleteSelectedTimelines"
            @click="deleteSelectedTimelinesWrapper()"
            v-bind="attrs"
            v-on="on"
          >
            <v-icon>mdi-delete</v-icon>
          </v-btn>
        </template>
        <span>Delete Timelines</span>
      </v-tooltip>
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <v-btn
            icon
            v-on="on"
            v-bind="attrs"
            data-test="setSelectedActivities"
            @click="setSelectedActivitiesOn()"
          >
            <v-icon v-show="!selectedTimelinesOn">mdi-calendar-multiple</v-icon>
            <v-icon v-show="selectedTimelinesOn">mdi-close</v-icon>
          </v-btn>
        </template>
        <span>Select Multiple Timelines</span>
      </v-tooltip>
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <v-btn
            icon
            v-on="on"
            v-bind="attrs"
            data-test="createTimeline"
            @click="showCreateDialog = true"
          >
            <v-icon>mdi-calendar-plus</v-icon>
          </v-btn>
        </template>
        <span>Create Timelines</span>
      </v-tooltip>
    </v-toolbar>
    <div class="my-1">
      <div v-for="item in sortedTimelines" :key="item.name">
        <v-card outlined class="my-1" @click="select(item)">
          <v-card-title
            :class="selected(item) ? 'selected-title' : 'available-title'"
          >
            <v-badge
              dot
              bordered
              inline
              tile
              :color="item.color"
              :value="item.messages"
            >
              <span :data-test="`selectItem-${item.name}`" v-text="item.name" />
            </v-badge>
            <v-spacer />
            <v-icon class="mx-2">
              {{ selected(item) ? 'mdi-eye' : 'mdi-eye-off' }}
            </v-icon>
          </v-card-title>
          <v-card-actions>
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <v-icon
                  @click.stop="openTimelineColorDialog(item)"
                  v-on="on"
                  v-bind="attrs"
                  class="mx-2"
                  :data-test="`openTimelineColorDialog-${item.name}`"
                >
                  mdi-palette
                </v-icon>
              </template>
              <span> Change Timeline Color </span>
            </v-tooltip>
            <v-spacer />
            <v-tooltip top>
              <template v-slot:activator="{ on, attrs }">
                <v-icon
                  @click.stop="deleteTimeline(item)"
                  v-on="on"
                  v-bind="attrs"
                  class="mx-2"
                  :data-test="`deleteTimeline-${item.name}`"
                >
                  mdi-delete
                </v-icon>
              </template>
              <span> Delete Timeline </span>
            </v-tooltip>
          </v-card-actions>
        </v-card>
      </div>
    </div>
    <!-- menus -->
    <timeline-create-dialog
      v-if="showCreateDialog"
      v-model="showCreateDialog"
      :timelines="timelines"
    />
    <timeline-color-dialog
      v-if="showColorDialog"
      v-model="showColorDialog"
      :timeline="colorMenuTimeline"
      :timelineColor="colorMenuTimeline.color"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import TimelineColorDialog from '@/tools/Timeline/TimelineColorDialog'
import TimelineCreateDialog from '@/tools/Timeline/TimelineCreateDialog'

export default {
  components: {
    TimelineColorDialog,
    TimelineCreateDialog,
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
      selectedTimelinesTracker: new Map(),
      selectedTimelinesOn: false,
      colorMenuTimeline: {},
      showColorDialog: false,
      showCreateDialog: false,
    }
  },
  computed: {
    sortedTimelines: function () {
      return [...this.timelines].sort((a, b) => (a.name > b.name ? 1 : -1))
    },
    selectedTimelines: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
    listeners: function () {
      let listeners = { ...this.$listeners }
      delete listeners.input
      return listeners
    },
  },
  methods: {
    selected: function (event) {
      return this.selectedTimelinesTracker.get(event.name)
    },
    select: function (event) {
      let newVal = null
      let newMap = null
      if (this.selectedTimelinesOn) {
        newVal = [...this.selectedTimelines]
        newMap = new Map(this.selectedTimelinesTracker)
        const index = newVal.indexOf(event)
        if (index >= 0) {
          // remove it
          newVal.splice(index, 1)
          newMap.delete(event.name)
        } else {
          // add it
          newVal.push(event)
          newMap.set(event.name, 1)
        }
      } else {
        newVal = [event]
        newMap = new Map()
        newMap.set(event.name, 1)
      }
      this.selectedTimelines = newVal
      this.selectedTimelinesTracker = newMap
    },
    setSelectedActivitiesOn: function () {
      if (this.selectedTimelinesOn || this.selectedTimelines.length > 1) {
        this.selectedTimelines = []
        this.selectedTimelinesTracker = new Map()
      }
      this.selectedTimelinesOn = !this.selectedTimelinesOn
    },
    openTimelineColorDialog: function (timeline) {
      this.colorMenuTimeline = timeline
      this.showColorDialog = true
    },
    deleteTimeline: function (timeline) {
      this.$dialog
        .confirm(`Are you sure you want to remove: ${timeline.name}`, {
          okText: 'Delete',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          return Api.delete(`/cosmos-api/timeline/${timeline.name}`)
        })
        .then((response) => {
          if (this.selectedTimelines.includes(timeline.name)) {
            // Deselect it first
            this.select(timeline)
          }
          const alertObject = {
            text: `Deleted timeline: ${timeline.name}`,
            type: 'warning',
          }
          this.$emit('alert', alertObject)
          this.showContextMenu = false
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to delete timeline: ${timeline.name}. Error: ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
    },
    deleteSelectedTimelinesWrapper: function () {
      if (this.selectedTimelines.length < 1) {
        const alertObject = {
          text: 'At least one timeline must be selected.',
          type: 'error',
        }
        this.$emit('alert', alertObject)
        return
      }
      const selectedTimelineNames = this.selectedTimelines
        .map((e) => e.name)
        .join(', ')
      this.$dialog
        .confirm(
          `Are you sure you want to delete: ${selectedTimelineNames} Timelines?`,
          {
            type: 'hard',
            verification: 'delete',
          }
        )
        .then((dialog) => {
          this.deleteSelectedTimelines()
        })
    },
    deleteSelectedTimelines: function () {
      for (const timeline of this.selectedTimelines) {
        Api.delete(`/cosmos-api/timeline/${timeline.name}`).catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to delete timeline: ${timeline.name}. Error: ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
      }
      const alertObject = {
        text: `Deleted ${this.selectedTimelines
          .map((timeline) => timeline.name)
          .join(', ')} timelines.`,
        type: 'warning',
      }
      this.$emit('alert', alertObject)
      this.selectedTimelinesOn = false
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
