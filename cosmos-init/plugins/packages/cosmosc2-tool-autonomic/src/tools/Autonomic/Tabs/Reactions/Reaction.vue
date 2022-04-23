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
            <v-btn icon data-test="reaction-download" @click="download">
              <v-icon> mdi-download </v-icon>
            </v-btn>
          </div>
        </template>
        <span> Download Reactions </span>
      </v-tooltip>
      <div class="mx-2">Reactions</div>
      <v-spacer />
      <v-tooltip top>
        <template v-slot:activator="{ on, attrs }">
          <div v-on="on" v-bind="attrs">
            <v-btn icon data-test="new-reaction" @click="newReaction">
              <v-icon>mdi-database-plus</v-icon>
            </v-btn>
          </div>
        </template>
        <span> New Reaction </span>
      </v-tooltip>
    </v-card-title>
    <v-card-title>
      <v-text-field
        v-model="search"
        label="Search"
        data-test="reaction-search"
        dense
        outlined
        hide-details
      />
    </v-card-title>
    <!-- The main part of the screen to have lists and information -->
    <v-row class="pa-4">
      <div v-for="(reaction, i) in reactions" :key="reaction.name">
        <v-col>
          <reaction-card :reaction="reaction" :index="i" />
        </v-col>
      </div>
    </v-row>
    <create-dialog v-model="showNewReactionDialog" :triggers="triggers" />
  </div>
</template>

<script>
import { format } from 'date-fns'
import Api from '@cosmosc2/tool-common/src/services/api'
import Cable from '@cosmosc2/tool-common/src/services/cable.js'
import EnvironmentDialog from '@cosmosc2/tool-common/src/components/EnvironmentDialog'

import CreateDialog from '@/tools/Autonomic/Tabs/Reactions/CreateDialog'
import ReactionCard from '@/tools/Autonomic/Tabs/Reactions/ReactionCard'

export default {
  components: {
    CreateDialog,
    ReactionCard,
  },
  data() {
    return {
      groups: [],
      triggers: {},
      reactions: [],
      cable: new Cable(),
      subscription: null,
      showNewReactionDialog: false,
    }
  },
  created: function () {
    this.subscribe()
  },
  mounted: function () {
    this.getGroups()
    this.getReactions()
  },
  destroyed: function () {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  computed: {
    eventReactionHandlerFunctions: function () {
      return {
        created: this.createdReactionFromEvent,
        updated: this.updatedReactionFromEvent,
        deleted: this.deletedReactionFromEvent,
        activated: this.updatedReactionFromEvent,
        deactivated: this.updatedReactionFromEvent,
        sleep: this.updatedReactionFromEvent,
        awaken: this.updatedReactionFromEvent,
      }
    },
  },
  watch: {
    groups: function () {
      this.getTriggers()
    },
  },
  methods: {
    getGroups: function () {
      Api.get('/cosmos-api/autonomic/group').then((response) => {
        this.groups = response.data
      })
    },
    getTriggers: function () {
      this.groups.forEach((group) => {
        const groupName = group.name
        Api.get(`/cosmos-api/autonomic/${groupName}/trigger`).then(
          (response) => {
            this.triggers = {
              ...this.triggers,
              [groupName]: response.data,
            }
          }
        )
      })
    },
    getReactions: function () {
      Api.get(`/cosmos-api/autonomic/reaction`).then((response) => {
        this.reactions = response.data
      })
    },
    newReaction: function () {
      this.showNewReactionDialog = true
    },
    download: function () {
      const output = JSON.stringify(this.reactions, null, 2)
      const blob = new Blob([output], {
        type: 'application/json',
      })
      // Make a link and then 'click' on it to start the download
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.setAttribute(
        'download',
        format(Date.now(), 'yyyy_MM_dd_HH_mm_ss') + '_autonomic_reactions.json'
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
          case 'reaction':
            // console.log('DEBUG REACTION >>>', event)
            this.eventReactionHandlerFunctions[event.kind](event)
            break
        }
      })
    },
    createdReactionFromEvent: function (event) {
      this.reactions.push(event.data)
    },
    updatedReactionFromEvent: function (event) {
      const reactionIndex = this.reactions.findIndex(
        (reaction) => reaction.name === event.data.name
      )
      if (reactionIndex >= 0) {
        this.reactions[reactionIndex] = event.data
      }
      this.reactions = [...this.reactions]
    },
    removedReactionFromEvent: function (event) {
      const reactionIndex = this.reactions.findIndex(
        (reaction) => reaction.name === event.data.name
      )
      this.reactions.splice(reactionIndex, reactionIndex >= 0 ? 1 : 0)
    },
  },
}
</script>
