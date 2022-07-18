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
    <v-overlay :value="showAlertPane" class="overlay" />
    <v-menu
      v-model="showAlertPane"
      transition="slide-y-transition"
      :close-on-content-click="false"
      :nudge-width="340"
      offset-y
      :nudge-bottom="20"
    >
      <!-- Alert box icon -->
      <template v-slot:activator="{ on, attrs }">
        <v-btn v-bind="attrs" v-on="on" icon>
          <v-icon :size="size"> mdi-alert-box-outline </v-icon>
        </v-btn>
      </template>

      <!-- Alerts list -->
      <v-card>
        <v-card-title>
          Alerts
          <v-spacer />
          <v-tooltip top open-delay="350">
            <template v-slot:activator="{ on, attrs }">
              <v-btn
                icon
                v-bind="attrs"
                v-on="on"
                @click="clearAlerts"
                class="ml-1"
              >
                <v-icon> mdi-notification-clear-all </v-icon>
              </v-btn>
            </template>
            <span>Clear all</span>
          </v-tooltip>
        </v-card-title>
        <v-card-text v-if="alerts.length === 0"> No alerts </v-card-text>
        <v-list
          v-else
          two-line
          width="388"
          max-height="80vh"
          class="overflow-y-auto"
        >
          <template v-for="(alert, index) in alerts">
            <v-list-item
              @click="openDialog(alert)"
              :key="`alert-${index}`"
              class="pl-2"
            >
              <v-badge left inline color="transparent">
                <v-list-item-content class="pt-0 pb-0">
                  <v-list-item-title>
                    {{ alert.title }}
                  </v-list-item-title>
                  <v-list-item-subtitle>
                    {{ alert.body }}
                  </v-list-item-subtitle>
                </v-list-item-content>
                <template v-slot:badge>
                  <astro-status-indicator
                    :status="alert.severity.toLowerCase()"
                  />
                </template>
              </v-badge>
            </v-list-item>
          </template>
        </v-list>
      </v-card>
    </v-menu>

    <!-- Dialog for viewing full alert -->
    <v-dialog v-model="alertDialog" width="600">
      <v-card>
        <v-card-title>
          {{ selectedAlert.title }}
          <v-spacer />
          <astro-status-indicator
            :status="selectedAlert.severity || 'normal'"
          />
        </v-card-title>
        <v-card-text>
          {{ selectedAlert.body }}
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-btn color="primary" text @click="alertDialog = false">
            Dismiss
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import { AstroStatusColors } from '../../../packages/openc3-tool-common/src/components/icons'
import {
  highestSeverity,
  orderBySeverity,
  groupBySeverity,
} from '../util/AstroStatus'

export default {
  props: {
    size: {
      type: [String, Number],
      default: 26,
    },
  },
  data: function () {
    return {
      AstroStatusColors,
      alerts: [],
      alertDialog: false,
      showAlertPane: false,
      selectedAlert: {},
    }
  },
  watch: {
    showAlertPane: function (val) {
      if (val) {
        this.refreshList()
      }
      if (!val && this.selectedAlert.title) {
        this.alertDialog = false
        this.selectedAlert = {}
      }
    },
  },
  methods: {
    refreshList: function () {
      this.alerts = this.$store.state.notifyHistory
    },
    clearAlerts: function () {
      this.$store.commit('notifyClearHistory')
      this.refreshList()
      this.showAlertPane = false
    },
    openDialog: function (alert, clearToast = false) {
      this.selectedAlert = alert
      this.alertDialog = true
    },
  },
}
</script>

<style scoped>
.v-subheader {
  height: 28px;
}

.v-badge {
  width: 100%;
}

.overlay {
  height: 100vh;
  width: 100vw;
}
</style>
