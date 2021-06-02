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
            @click="deleteSelectedTimelines()"
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
            data-test="createTimeline"
            @click="createTimeline()"
            v-bind="attrs"
            v-on="on"
          >
            <v-icon>mdi-calendar-plus</v-icon>
          </v-btn>
        </template>
        <span>Create Timelines</span>
      </v-tooltip>
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <v-btn
            icon
            data-test="setSelectedActivitiesOn"
            @click="setSelectedActivitiesOn()"
            v-bind="attrs"
            v-on="on"
          >
            <v-icon v-show="!selectedTimelinesOn">mdi-check</v-icon>
            <v-icon v-show="selectedTimelinesOn">mdi-close</v-icon>
          </v-btn>
        </template>
        <span>Select Multiple Timelines</span>
      </v-tooltip>
    </v-toolbar>
    <v-list>
      <v-list-item-group :multiple="selectedTimelinesOn">
        <template v-for="(timeline, index) in sortedTimelines">
          <v-list-item
            :key="timeline.name"
            data-test="selectTimeline"
            @click="select(timeline, !selectedTimelinesOn)"
          >
            <v-row>
              <v-col>
                <v-list-item-content class="mt-2">
                  <v-badge
                    dot
                    bordered
                    inline
                    tile
                    :color="timeline.color"
                    :value="timeline.messages"
                  >
                    <v-list-item-title
                      class="font-weight-bold"
                      v-text="timeline.name"
                    />
                  </v-badge>
                </v-list-item-content>
              </v-col>
              <v-col :cols="2">
                <v-list-item-content>
                  <v-menu offset-y>
                    <template v-slot:activator="{ on, attrs }">
                      <v-btn
                        data-test="timelineActions"
                        icon
                        v-bind="attrs"
                        v-on="on"
                      >
                        <v-icon>mdi-dots-vertical</v-icon>
                      </v-btn>
                    </template>
                    <v-list>
                      <v-list-item>
                        <v-list-item-title
                          data-test="openTimelineColorDialog"
                          @click="openTimelineColorDialog(timeline)"
                        >
                          Color
                        </v-list-item-title>
                      </v-list-item>
                      <v-divider />
                      <v-list-item>
                        <v-list-item-title
                          data-test="deleteTimeline"
                          @click="deleteTimeline(timeline)"
                        >
                          Delete
                        </v-list-item-title>
                      </v-list-item>
                    </v-list>
                  </v-menu>
                </v-list-item-content>
              </v-col>
            </v-row>
          </v-list-item>
          <v-divider
            v-if="index < sortedTimelines.length - 1"
            :key="index"
          ></v-divider>
        </template>
      </v-list-item-group>
    </v-list>
    <!-- menus -->
    <timeline-color-dialog
      v-on="listeners"
      v-model="showColorMenu"
      :timeline="colorMenuTimeline"
      :timelineColor="colorMenuTimeline.color"
    />
  </div>
</template>

<script>
import Api from '@cosmosc2/tool-common/src/services/api'
import TimelineColorDialog from '@/tools/Timeline/TimelineColorDialog'

export default {
  components: {
    TimelineColorDialog,
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
      selectedTimelinesOn: false,
      colorMenuTimeline: {},
      showColorMenu: false,
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
    select: function (timeline, single = false, onlyDeselect = false) {
      let newVal = null
      if (single) {
        newVal = [timeline]
      } else {
        newVal = [...this.selectedTimelines]
        const index = newVal.indexOf(timeline)
        if (index >= 0) {
          // remove it
          newVal.splice(index, 1)
        } else {
          // add it
          newVal.push(timeline)
        }
      }
      this.selectedTimelines = newVal
    },
    setSelectedActivitiesOn: function () {
      if (this.selectedTimelinesOn || this.selectedTimelines.length > 1) {
        this.selectedTimelines = []
      }
      this.selectedTimelinesOn = !this.selectedTimelinesOn
    },
    openTimelineColorDialog: function (timeline) {
      this.colorMenuTimeline = timeline
      this.showColorMenu = true
    },
    createTimeline: function () {
      this.$dialog
        .prompt({
          okText: 'Create',
          cancelText: 'Cancel',
          title: 'Create New Timeline',
          body: 'Add a timeline to schedule activities on.',
        })
        .then((dialog) => {
          return Api.post('/cosmos-api/timeline', {
            json: JSON.stringify({
              name: dialog.data,
            }),
          })
        })
        .then((response) => {
          const alertObject = {
            text: `Created new timeline: ${response.data.name}`,
            type: 'success',
          }
          this.$emit('alert', alertObject)
        })
        .catch((error) => {
          if (error) {
            const alertObject = {
              text: `Failed to create timeline. ${error}`,
              type: 'error',
            }
            this.$emit('alert', alertObject)
          }
        })
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
.theme--dark .v-card__title,
.theme--dark .v-card__subtitle {
  background-color: var(--v-secondary-darken3);
}
</style>
