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
    <!-- The top bar of the screen to have buttons and actions -->
    <v-card-title class="pb-0">
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-on="on" v-bind="attrs">
            <v-btn icon data-test="download" @click="downloadGroups">
              <v-icon> mdi-download </v-icon>
            </v-btn>
          </div>
        </template>
        <span> Download Groups </span>
      </v-tooltip>
      <div class="mx-2">Groups</div>
      <v-spacer />
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-on="on" v-bind="attrs">
            <v-btn icon data-test="newGroup" @click="newGroup">
              <v-icon>mdi-database-plus</v-icon>
            </v-btn>
          </div>
        </template>
        <span> New Group </span>
      </v-tooltip>
    </v-card-title>
    <v-card-title>
      <v-text-field
        v-model="searchGroups"
        label="Search"
        data-test="search"
        dense
        outlined
        hide-details
      />
    </v-card-title>
    <!-- The main part of the screen to have lists and information -->
    <v-list data-test="groupList">
      <div v-for="(group, index) in groups" :key="group.name">
        <v-list-item>
          <v-list-item-content>
            <v-list-item-title v-text="group.name" />
          </v-list-item-content>
          <v-list-item-icon>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-icon @click="deleteGroup(group)" v-bind="attrs" v-on="on">
                  mdi-delete
                </v-icon>
              </template>
              <span>Delete Group</span>
            </v-tooltip>
          </v-list-item-icon>
        </v-list-item>
        <v-divider v-if="index < groups.length - 1" :key="index" />
      </div>
    </v-list>
    <!--- EVENTS --->
    <v-card-title class="pb-0">
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-on="on" v-bind="attrs">
            <v-btn icon data-test="download-log" @click="downloadEvents">
              <v-icon> mdi-download </v-icon>
            </v-btn>
          </div>
        </template>
        <span> Download Log </span>
      </v-tooltip>
      <div class="mx-2">Events</div>
      <v-spacer />
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-on="on" v-bind="attrs">
            <v-btn icon data-test="clear-log" @click="clearEvents">
              <v-icon> mdi-delete </v-icon>
            </v-btn>
          </div>
        </template>
        <span> Clear Log </span>
      </v-tooltip>
    </v-card-title>
    <v-card-title>
      <v-text-field
        v-model="searchEvents"
        label="Search"
        data-test="search"
        dense
        outlined
        hide-details
      />
    </v-card-title>
    <v-data-table
      :headers="headers"
      :items="data"
      :search="search"
      calculate-widths
      disable-pagination
      hide-default-footer
      multi-sort
      dense
      height="55vh"
      data-test="output-messages"
    >
      <template v-slot:item.actions="{ item }">
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-btn icon data-test="viewEvent" @click="viewEvent(item)">
                <v-icon> mdi-eye </v-icon>
              </v-btn>
            </div>
          </template>
          <span> View Event </span>
        </v-tooltip>
      </template>
    </v-data-table>
    <create-dialog v-model="showNewGroupDialog" :groups="triggerGroupNames" />
  </div>
</template>

<script>
import { format } from 'date-fns'
import Api from '@cosmosc2/tool-common/src/services/api'
import Cable from '@cosmosc2/tool-common/src/services/cable.js'

import CreateDialog from '@/tools/Autonomic/Tabs/Overview/CreateDialog'

export default {
  components: {
    CreateDialog,
  },
  data() {
    return {
      searchGroups: '',
      groups: [],
      showNewGroupDialog: false,
      searchEvents: '',
      history_count: 100,
      data: [],
      headers: [
        { text: 'Time', value: 'timestamp' },
        { text: 'Type', value: 'type' },
        { text: 'Message', value: 'log' },
      ],
      cable: new Cable(),
      subscription: null,
    }
  },
  created: function () {
    this.subscribe()
  },
  mounted: function () {
    this.getGroups()
  },
  destroyed: function () {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  computed: {
    triggerGroupNames: function () {
      return this.groups.map((group) => {
        return group.name
      })
    },
    eventGroupHandlerFunctions: function () {
      return {
        created: this.createdGroupFromEvent,
        updated: this.updatedGroupFromEvent,
        deleted: this.deletedGroupFromEvent,
      }
    },
  },
  methods: {
    getGroups: function () {
      return Api.get('/cosmos-api/autonomic/group').then((response) => {
        this.groups = response.data
      })
    },
    newGroup: function () {
      this.showNewGroupDialog = true
    },
    downloadGroups() {
      const output = JSON.stringify(this.groups, null, 2)
      const blob = new Blob([output], {
        type: 'application/json',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_autonomic_groups.json'
      )
      link.click()
    },
    deleteGroup: function (group) {
      this.$dialog
        .confirm(
          `Are you sure you want to delete TriggerGroup: ${group.name}`,
          {
            okText: 'Delete',
            cancelText: 'Cancel',
          }
        )
        .then((dialog) => {
          return Api.delete(`/cosmos-api/autonomic/group/${group.name}`)
        })
        .then((response) => {
          this.$notify.normal({
            title: 'Removed TriggerGroup',
            body: `TriggerGroup: ${group.name} has been deleted`,
          })
        })
    },
    createdGroupFromEvent: function (event) {
      this.groups.push(event.data)
    },
    updatedGroupFromEvent: function (event) {
      const groupIndex = this.groups.findIndex(
        (group) => group.name === event.data.name
      )
      if (groupIndex >= 0) {
        this.groups[groupIndex] = event.data
      }
    },
    deletedGroupFromEvent: function (event) {
      const groupIndex = this.groups.findIndex(
        (group) => group.name === event.data.name
      )
      this.groups.splice(groupIndex, groupIndex >= 0 ? 1 : 0)
    },
    // CABLE Methods
    subscribe: function () {
      this.cable
        .createSubscription('AutonomicEventsChannel', localStorage.scope, {
          received: (data) => this.received(data),
        })
        .then((subscription) => {
          this.subscription = subscription
        })
    },
    received: function (data) {
      this.updateMessages(JSON.parse(data))
    },
    // EVENT Methods
    downloadEvents: function () {
      const output = JSON.stringify(this.data, null, 2)
      const blob = new Blob([output], {
        type: 'application/json',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_autonomic_events.json'
      )
      link.click()
    },
    clearEvents: function () {
      this.$dialog
        .confirm('Are you sure you want to clear the autonomic events logs?', {
          okText: 'Clear',
          cancelText: 'Cancel',
        })
        .then((dialog) => {
          this.data = []
        })
    },
    generateMessage: function (message) {
      // console.log('DEBUG EVENTS >>>', message)
      switch (message.type) {
        case 'group':
          this.eventGroupHandlerFunctions[message.kind](message)
          return `${message.data.name} was ${message.kind}`
        case 'trigger':
          return `${message.data.group}, ${message.data.name} was ${message.kind}`
        case 'reaction':
          return `${message.data.name} was ${message.kind}`
      }
    },
    updateMessages: function (messages) {
      if (messages.length > this.history_count) {
        this.messages.splice(0, messages.length - 100)
      }
      const dataMessages = messages.map((message) => {
        message.data = JSON.parse(message.data)
        return {
          timestamp: new Date().toISOString(),
          type: message.type.toUpperCase(),
          log: this.generateMessage(message),
        }
      })
      this.data = dataMessages.reverse().concat(this.data)
      if (this.data.length > this.history_count) {
        this.data.length = this.history_count
      }
    },
  },
}
</script>
