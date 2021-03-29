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
    <v-overlay :value="showNotificationPane" class="notifications-overlay" />
    <v-menu
      v-model="showNotificationPane"
      transition="slide-y-transition"
      :close-on-content-click="false"
      :nudge-width="340"
      offset-y
      :nudge-bottom="20"
    >
      <!-- Bell icon -->
      <template v-slot:activator="{ on, attrs }">
        <v-btn v-bind="attrs" v-on="on" icon>
          <v-icon v-if="unreadCount === 0" :size="size">
            mdi-bell-outline
          </v-icon>
          <v-badge
            v-else
            left
            offset-x="24"
            offset-y="8"
            :color="badgeColor"
            bordered
            :content="unreadCount"
          >
            <v-icon :size="size" :color="badgeColor"> mdi-bell </v-icon>
          </v-badge>
        </v-btn>
      </template>

      <!-- Notifications list -->
      <v-card>
        <v-card-title>
          Notifications
          <v-spacer />
          <v-tooltip top open-delay="350">
            <template v-slot:activator="{ on, attrs }">
              <v-btn
                icon
                v-bind="attrs"
                v-on="on"
                @click="clearNotifications"
                class="ml-1"
              >
                <v-icon> mdi-notification-clear-all </v-icon>
              </v-btn>
            </template>
            <span>Clear all</span>
          </v-tooltip>
          <v-btn icon @click="toggleSettingsDialog" class="ml-1">
            <v-icon> $astro-settings </v-icon>
          </v-btn>
        </v-card-title>
        <v-card-text v-if="notifications.length === 0">
          No notifications
        </v-card-text>
        <v-list
          v-else
          two-line
          width="388"
          max-height="80vh"
          class="overflow-y-auto"
        >
          <template v-for="(notification, index) in notificationList">
            <template v-if="notification.header">
              <v-divider v-if="index !== 0" :key="index" class="mb-2" />
              <v-subheader :key="notification.header">
                <astro-status-indicator
                  v-if="notification.header !== 'Read'"
                  :status="notification.header.toLowerCase()"
                  class="mr-1"
                />
                {{ notification.header }}
              </v-subheader>
            </template>

            <v-list-item
              v-else
              :key="`notification-${index}`"
              @click="openDialog(notification)"
            >
              <v-badge
                dot
                inline
                :color="notification.read ? 'transparent' : 'success'"
              >
                <v-list-item-content class="pt-0 pb-0">
                  <v-list-item-title>
                    {{ notification.title }}
                  </v-list-item-title>
                  <v-list-item-subtitle>
                    {{ notification.body }}
                  </v-list-item-subtitle>
                </v-list-item-content>
                <v-list-item-action class="mt-0">
                  <v-list-item-action-text>
                    {{ notification.time | shortDateTime }}
                  </v-list-item-action-text>
                  <v-spacer />
                </v-list-item-action>
              </v-badge>
            </v-list-item>
          </template>
        </v-list>
      </v-card>
    </v-menu>

    <!-- Toast -->
    <v-slide-y-transition>
      <v-sheet
        v-show="showToast"
        :style="toastStyle"
        class="toast-notification"
        @click="openDialog(toastNotification, true)"
      >
        <div class="toast-content">
          <span class="text-subtitle-1 mr-1">
            {{ toastNotification.title }}:
          </span>
          <span class="text-body-2">
            {{ toastNotification.body }}
          </span>
        </div>
        <v-spacer />
        <v-btn text @click.stop="toast = false"> Dismiss </v-btn>
      </v-sheet>
    </v-slide-y-transition>

    <!-- Dialog for viewing full notification -->
    <v-dialog v-model="notificationDialog" width="600">
      <v-card>
        <v-card-title>
          {{ selectedNotification.title }}
          <v-spacer />
          <astro-status-indicator :status="selectedNotification.severity" />
        </v-card-title>
        <v-card-subtitle>
          {{ selectedNotification.time | shortDateTime }}
        </v-card-subtitle>
        <v-card-text>
          {{ selectedNotification.body }}
        </v-card-text>
        <v-divider></v-divider>
        <v-card-actions>
          <v-btn
            color="primary"
            text
            @click="navigate(selectedNotification.url)"
          >
            Open
          </v-btn>
          <v-btn color="primary" text @click="notificationDialog = false">
            Dismiss
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Dialog for changing notification settings -->
    <v-dialog v-model="settingsDialog" width="600">
      <v-card>
        <v-card-title> Notification settings </v-card-title>
        <v-card-text>
          <v-switch v-model="showToastSetting" label="Show toasts" />
        </v-card-text>
        <v-divider></v-divider>
        <v-card-actions>
          <v-btn color="primary" text @click="toggleSettingsDialog">
            close
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import * as ActionCable from 'actioncable'
import { formatDistanceToNow } from 'date-fns'
import { AstroStatusColors } from '../../../packages/cosmosc2-tool-common/src/components/icons'
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
      cable: ActionCable.Cable,
      subscription: ActionCable.Channel,
      notifications: [],
      showNotificationPane: false,
      toast: false,
      toastNotification: {},
      toastTimeout: null,
      notificationDialog: false,
      selectedNotification: {},
      settingsDialog: false,
      showToastSetting: true,
    }
  },
  computed: {
    badgeColor: function () {
      if (!this.unreadCount) {
        return AstroStatusColors['off']
      }
      const severities = this.unreadNotifications
        .map((notification) => notification.severity)
        .filter((val, index, self) => {
          return self.indexOf(val) === index // Unique values
        })
      return AstroStatusColors[highestSeverity(severities)]
    },
    readNotifications: function () {
      return this.notifications
        .filter((notification) => notification.read)
        .sort((a, b) => b.time - a.time)
    },
    unreadNotifications: function () {
      return this.notifications
        .filter((notification) => !notification.read)
        .sort((a, b) => b.time - a.time)
    },
    unreadCount: function () {
      return this.unreadNotifications.length
    },
    notificationList: function () {
      const groups = groupBySeverity(this.unreadNotifications)
      let result = orderBySeverity(Object.keys(groups), (k) => k).flatMap(
        (severity) => {
          const header = {
            header: severity.charAt(0).toUpperCase() + severity.slice(1),
          }
          return [header, ...groups[severity]]
        }
      )
      if (this.readNotifications.length) {
        result = result.concat([{ header: 'Read' }, ...this.readNotifications])
      }
      return result
    },
    showToast: function () {
      return this.showToastSetting && this.toast
    },
    toastStyle: function () {
      return `--toast-bg-color:${
        AstroStatusColors[this.toastNotification.severity]
      };`
    },
  },
  watch: {
    showNotificationPane: function (val) {
      if (!val) {
        this.markAllAsRead()
      }
    },
    showToastSetting: function (val) {
      localStorage.notoast = !val
      if (val) {
        // Don't show an old toast when turning this setting on
        this.toast = false
        clearTimeout(this.toastTimeout)
      }
    },
  },
  created: function () {
    this.showToastSetting = localStorage.notoast === 'false'
    this.cable = ActionCable.createConsumer('/cosmos-api/cable')
    this.subscribe()
  },
  destroyed: function () {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    markAllAsRead: function () {
      this.notifications.forEach((notification) => {
        notification.read = true
        if (
          !localStorage.lastReadNotification ||
          localStorage.lastReadNotification < notification.msg_id
        ) {
          localStorage.lastReadNotification = notification.msg_id
        }
      })
    },
    clearNotifications: function () {
      this.markAllAsRead()
      this.notifications = []
      localStorage.notificationStreamOffset = localStorage.lastReadNotification
      this.showNotificationPane = false
    },
    toggleNotificationPane: function () {
      this.showNotificationPane = !this.showNotificationPane
    },
    toggleSettingsDialog: function () {
      this.settingsDialog = !this.settingsDialog
    },
    openDialog: function (notification, clearToast = false) {
      notification.read = true
      if (
        !localStorage.lastReadNotification ||
        localStorage.lastReadNotification < notification.msg_id
      ) {
        localStorage.lastReadNotification = notification.msg_id
      }
      this.selectedNotification = notification
      this.notificationDialog = true
      if (clearToast) {
        this.toast = false
        clearTimeout(this.toastTimeout)
      }
    },
    navigate: function (url) {
      window.open(url, '_blank')
    },
    subscribe: function () {
      const startOptions = {
        start_offset:
          localStorage.notificationStreamOffset ||
          localStorage.lastReadNotification,
      }
      this.subscription = this.cable.subscriptions.create(
        {
          channel: 'NotificationsChannel',
          scope: 'DEFAULT',
          ...startOptions,
        },
        {
          received: (data) => this.received(data),
        }
      )
    },
    received: function (data) {
      const parsed = JSON.parse(data)
      let foundToast = false
      parsed.forEach((notification) => {
        notification.read =
          notification.msg_id <= localStorage.lastReadNotification
        notification.severity = notification.severity || 'normal'
        if (
          !notification.read && // Don't toast read notifications
          ['critical', 'serious'].includes(notification.severity) && // Toast for these statuses
          (!this.toast || notification.severity === 'critical') // Ok to override a toast only if this one is 'critical'
        ) {
          foundToast = true
          if (notification.severity === 'critical') {
            clearTimeout(this.toastTimeout)
          }
          this.toastNotification = notification
        }
      })
      this.notifications = this.notifications.concat(parsed)
      this.toast = this.toast || foundToast
      if (foundToast && this.toastNotification.severity === 'serious') {
        // 'critical' notifications are persistent, 'serious' ones hide after a few seconds
        this.toastTimeout = setTimeout(() => {
          this.toast = false
        }, 5000)
      }
    },
  },
  filters: {
    shortDateTime: function (nsec) {
      if (!nsec) return ''
      const date = new Date(nsec / 1_000_000)
      return formatDistanceToNow(date, { addSuffix: true })
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

.notifications-overlay {
  height: 100vh;
  width: 100vw;
}

.v-sheet.toast-notification {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  background-color: var(--toast-bg-color) !important;
  display: flex;
  align-items: center;
  padding: 14px;
  cursor: pointer;
}

.toast-notification .toast-content {
  white-space: nowrap;
  overflow-x: hidden;
  text-overflow: ellipsis;
}
</style>
