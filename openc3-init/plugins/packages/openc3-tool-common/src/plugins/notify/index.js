/*
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
*/

import Toast from './Toast.vue'

class Notify {
  constructor(Vue, options = {}) {
    this.Vue = Vue
    this.$store = options.store
    this.mounted = false
    this.$root = null
  }

  mount = function () {
    if (this.mounted) return

    const ToastConstructor = this.Vue.extend(Toast)
    const toast = new ToastConstructor()

    const el = document.createElement('div')
    document.querySelector('#openc3-app-toolbar > div').appendChild(el)
    this.$root = toast.$mount(el)

    this.mounted = true
  }

  open = function ({
    method,
    title,
    body,
    severity,
    duration,
    type = 'alert',
    logToConsole = false,
    saveToHistory = true,
  }) {
    this.mount()
    if (logToConsole) {
      // eslint-disable-next-line no-console
      console.log(`${severity.toUpperCase()} - ${title}: ${body}`)
    }
    if (saveToHistory) {
      this.$store.commit('notifyAddHistory', { title, body, severity })
    }
    this[method]({ title, body, severity, duration, type })
  }

  toast = function ({ title, body, severity, duration, type }) {
    this.$root.toast(
      {
        title,
        body,
        severity,
        type,
      },
      duration
    )
  }

  critical = function ({
    title,
    body,
    type,
    duration,
    logToConsole,
    saveToHistory,
  }) {
    this.open({
      method: 'toast',
      severity: 'critical',
      title,
      body,
      type,
      duration,
      logToConsole,
      saveToHistory,
    })
  }
  serious = function ({
    title,
    body,
    type,
    duration,
    logToConsole,
    saveToHistory,
  }) {
    this.open({
      method: 'toast',
      severity: 'serious',
      title,
      body,
      type,
      duration,
      logToConsole,
      saveToHistory,
    })
  }
  caution = function ({
    title,
    body,
    type,
    duration,
    logToConsole,
    saveToHistory,
  }) {
    this.open({
      method: 'toast',
      severity: 'caution',
      title,
      body,
      type,
      duration,
      logToConsole,
      saveToHistory,
    })
  }
  normal = function ({
    title,
    body,
    type,
    duration,
    logToConsole,
    saveToHistory,
  }) {
    this.open({
      method: 'toast',
      severity: 'normal',
      title,
      body,
      type,
      duration,
      logToConsole,
      saveToHistory,
    })
  }
  standby = function ({
    title,
    body,
    type,
    duration,
    logToConsole,
    saveToHistory,
  }) {
    this.open({
      method: 'toast',
      severity: 'standby',
      title,
      body,
      type,
      duration,
      logToConsole,
      saveToHistory,
    })
  }
  off = function ({
    title,
    body,
    type,
    duration,
    logToConsole,
    saveToHistory,
  }) {
    this.open({
      method: 'toast',
      severity: 'off',
      title,
      body,
      type,
      duration,
      logToConsole,
      saveToHistory,
    })
  }
}

export default {
  install(Vue, options) {
    if (!Vue.prototype.hasOwnProperty('$notify')) {
      Vue.notify = new Notify(Vue, options)

      Object.defineProperties(Vue.prototype, {
        $notify: {
          get() {
            return Vue.notify
          },
        },
      })
    }
  },
}
