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
    <v-card outlined>
      <div>
        <v-card-title
          :class="reaction.snoozed_until ? 'selected-title' : 'available-title'"
        >
          <v-icon class="pr-5">
            {{ reaction.active ? 'mdi-power-plug' : 'mdi-power-plug-off' }}
          </v-icon>
          <v-icon class="pr-5">
            {{ reaction.snoozed_until ? 'mdi-bell-sleep' : 'mdi-bell' }}
          </v-icon>
          <span v-text="reaction.name" />
        </v-card-title>
        <v-card-text>
          <v-simple-table dense>
            <tbody>
              <tr>
                <th class="text-left">Description</th>
                <td v-text="reaction.description" />
              </tr>
              <tr>
                <th class="text-left">Active</th>
                <td v-text="reaction.active" />
              </tr>
              <tr>
                <th class="text-left">Review</th>
                <td v-text="reaction.review" />
              </tr>
              <tr>
                <th class="text-left">Snooze</th>
                <td v-text="reaction.snooze" />
              </tr>
              <tr>
                <th class="text-left">Snoozed Until</th>
                <td v-text="snoozedZuluTime" />
              </tr>
              <tr v-for="(trigger, i) in reaction.triggers" :key="i">
                <th class="text-left" v-text="`Trigger-${i}`" />
                <td v-text="`${trigger.group}, ${trigger.name}`" />
              </tr>
              <tr v-for="(action, i) in reaction.actions" :key="i">
                <th class="text-left" v-text="`Action-${i}`" />
                <td v-text="action.value" />
              </tr>
            </tbody>
          </v-simple-table>
        </v-card-text>
      </div>

      <v-card-actions>
        <div v-if="reaction.active">
          <v-tooltip top>
            <template v-slot:activator="{ on, attrs }">
              <div v-on="on" v-bind="attrs">
                <v-btn
                  icon
                  :data-test="`reaction-deactivate-icon-${index}`"
                  @click="deactivateHandler"
                >
                  <v-icon> mdi-power-plug-off </v-icon>
                </v-btn>
              </div>
            </template>
            <span> Deactivate </span>
          </v-tooltip>
        </div>
        <div v-else>
          <v-tooltip top>
            <template v-slot:activator="{ on, attrs }">
              <div v-on="on" v-bind="attrs">
                <v-btn
                  icon
                  :data-test="`reaction-activate-icon-${index}`"
                  @click="activateHandler"
                >
                  <v-icon>mdi-power-plug</v-icon>
                </v-btn>
              </div>
            </template>
            <span> Activate </span>
          </v-tooltip>
        </div>
        <v-spacer />
        <v-tooltip top>
          <template v-slot:activator="{ on, attrs }">
            <div v-on="on" v-bind="attrs">
              <v-btn
                icon
                :data-test="`reaction-delete-icon-${index}`"
                @click="deleteHandler"
              >
                <v-icon>mdi-delete</v-icon>
              </v-btn>
            </div>
          </template>
          <span> Delete </span>
        </v-tooltip>
      </v-card-actions>
    </v-card>
  </div>
</template>

<script>
import Api from '@openc3/tool-common/src/services/api'

export default {
  props: {
    reaction: {
      type: Object,
      required: true,
    },
    index: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {}
  },
  computed: {
    snoozedZuluTime: function () {
      if (!this.reaction.snoozed_until) {
        return ''
      }
      return new Date(this.reaction.snoozed_until * 1000).toISOString()
    },
  },
  methods: {
    activateHandler: function () {
      Api.post(
        `/openc3-api/autonomic/reaction/${this.reaction.name}/activate`,
        {}
      ).then((response) => {
        this.$notify.normal({
          title: 'Activated Reaction',
          body: `reaction: ${this.reaction.name} has been activated.`,
        })
      })
    },
    deactivateHandler: function () {
      Api.post(
        `/openc3-api/autonomic/reaction/${this.reaction.name}/deactivate`,
        {}
      ).then((response) => {
        this.$notify.normal({
          title: 'Deactivated Reaction',
          body: `reaction: ${this.reaction.name} has been deactivated.`,
        })
      })
    },
    deleteHandler: function () {
      Api.delete(`/openc3-api/autonomic/reaction/${this.reaction.name}`).then(
        (response) => {
          this.$notify.normal({
            title: 'Reaction Deleted',
            body: `reaction: ${this.reaction.name} has been deleted.`,
          })
        }
      )
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
