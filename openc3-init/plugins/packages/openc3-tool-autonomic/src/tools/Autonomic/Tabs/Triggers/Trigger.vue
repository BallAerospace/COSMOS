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
    <!-- The top bar of the screen to have buttons and actions -->
    <v-card-title class="pb-0">
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-on="on" v-bind="attrs">
            <v-btn icon data-test="trigger-download" @click="download">
              <v-icon> mdi-download </v-icon>
            </v-btn>
          </div>
        </template>
        <span> Download Triggers </span>
      </v-tooltip>
      <div class="mx-2">Triggers</div>
      <v-spacer />
      <v-select
        v-model="group"
        :items="triggerGroupNames"
        :disabled="triggerGroupNames.length <= 1"
        label="Group"
        class="mx-2"
        style="max-width: 200px"
        dense
        hide-details
      />
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-on="on" v-bind="attrs">
            <v-btn
              icon
              data-test="new-trigger"
              @click="newTrigger()"
              :disabled="!group"
            >
              <v-icon>mdi-database-plus</v-icon>
            </v-btn>
          </div>
        </template>
        <span> New Trigger </span>
      </v-tooltip>
    </v-card-title>
    <v-card-title>
      <v-text-field
        v-model="search"
        label="Search"
        data-test="search"
        dense
        outlined
        hide-details
      />
    </v-card-title>
    <!-- The main part of the screen to have lists and information -->
    <v-row class="pa-4">
      <div v-for="(trigger, i) in triggers" :key="trigger.name">
        <v-col>
          <trigger-card :trigger="trigger" :index="i" />
        </v-col>
      </div>
    </v-row>
    <create-dialog
      v-model="showNewTriggerDialog"
      :group="group"
      :triggers="triggers"
    />
  </div>
</template>

<script>
import { format } from 'date-fns'
import Api from '@openc3/tool-common/src/services/api'
import Cable from '@openc3/tool-common/src/services/cable.js'

import CreateDialog from '@/tools/Autonomic/Tabs/Triggers/CreateDialog'
import TriggerCard from '@/tools/Autonomic/Tabs/Triggers/TriggerCard'

export default {
  components: {
    CreateDialog,
    TriggerCard,
  },
  data() {
    return {
      group: null,
      triggerGroups: [],
      triggers: [],
      showNewTriggerDialog: false,
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
      return this.triggerGroups.map((group) => {
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
    eventTriggerHandlerFunctions: function () {
      return {
        created: this.createdTriggerFromEvent,
        updated: this.updatedTriggerFromEvent,
        deleted: this.deletedTriggerFromEvent,
        enabled: this.updatedTriggerFromEvent,
        disabled: this.updatedTriggerFromEvent,
        activated: this.updatedTriggerFromEvent,
        deactivated: this.updatedTriggerFromEvent,
      }
    },
  },
  watch: {
    group: function () {
      this.getTriggers()
    },
  },
  methods: {
    getGroups: function () {
      Api.get('/openc3-api/autonomic/group').then((response) => {
        this.triggerGroups = response.data
        this.group = this.triggerGroupNames[0]
      })
    },
    getTriggers: function () {
      if (!this.group) {
        return
      }
      Api.get(`/openc3-api/autonomic/${this.group}/trigger`).then(
        (response) => {
          this.triggers = response.data
        }
      )
    },
    newTrigger: function () {
      this.showNewTriggerDialog = true
    },
    download() {
      const output = JSON.stringify(this.triggers, null, 2)
      const blob = new Blob([output], {
        type: 'application/json',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_autonomic_triggers.json'
      )
      link.click()
    },
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
      const parsed = JSON.parse(data)
      parsed.forEach((event) => {
        event.data = JSON.parse(event.data)
        switch (event.type) {
          case 'group':
            // console.log('DEBUG GROUP >>>', event)
            this.eventGroupHandlerFunctions[event.kind](event)
            break
          case 'trigger':
            // console.log('DEBUG TRIGGER >>>', event)
            this.eventTriggerHandlerFunctions[event.kind](event)
            break
        }
      })
    },
    createdGroupFromEvent: function (event) {
      this.triggerGroups.push(event.data)
    },
    updatedGroupFromEvent: function (event) {
      const groupIndex = this.triggerGroups.findIndex(
        (group) => group.name === event.data.name
      )
      if (groupIndex >= 0) {
        this.triggerGroups[groupIndex] = event.data
      }
    },
    deletedGroupFromEvent: function (event) {
      const groupIndex = this.triggerGroups.findIndex(
        (group) => group.name === event.data.name
      )
      this.triggerGroups.splice(groupIndex, groupIndex >= 0 ? 1 : 0)
      if (this.group === event.data.name) {
        this.group = this.groups ? this.groups[0] : null
      }
    },
    createdTriggerFromEvent: function (event) {
      if (event.data.group !== this.group) {
        return
      }
      this.triggers.push(event.data)
    },
    updatedTriggerFromEvent: function (event) {
      if (event.data.group !== this.group) {
        return
      }
      const triggerIndex = this.triggers.findIndex(
        (trigger) => trigger.name === event.data.name
      )
      if (triggerIndex >= 0) {
        this.triggers[triggerIndex] = event.data
      }
      this.triggers = [...this.triggers]
    },
    deletedTriggerFromEvent: function (event) {
      if (event.data.group !== this.group) {
        return
      }
      const triggerIndex = this.triggers.findIndex(
        (trigger) => trigger.name === event.data.name
      )
      this.triggers.splice(triggerIndex, triggerIndex >= 0 ? 1 : 0)
    },
  },
}
</script>
