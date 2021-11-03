/*
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
*/

import Toast from './Toast.vue'

class Notify {
  constructor(Vue, globalOptions = {}) {
    this.Vue = Vue
    this.mounted = false
    this.$root = null
  }

  mount = function () {
    if (this.mounted) return

    const ToastConstructor = this.Vue.extend(Toast)
    const toast = new ToastConstructor()

    const el = document.createElement('div')
    document.querySelector('#cosmos-app-toolbar > div').appendChild(el)
    this.$root = toast.$mount(el)

    this.mounted = true
  }

  // destroy = function () {
  //   if (this.mounted) {
  //     const el = this.$root.$el
  //     el.remove()
  //     this.mounted = false
  //   }
  // }

  toast = function ({ title, body, severity, duration }) {
    this.mount()
    this.$root.toast(
      {
        title,
        body,
        severity,
      },
      duration
    )
  }

  critical = function ({ title, body, duration }) {
    this.toast({ title, body, duration, severity: 'critical' })
  }
  serious = function ({ title, body, duration }) {
    this.toast({ title, body, duration, severity: 'serious' })
  }
  caution = function ({ title, body, duration }) {
    this.toast({ title, body, duration, severity: 'caution' })
  }
  normal = function ({ title, body, duration }) {
    this.toast({ title, body, duration, severity: 'normal' })
  }
  standby = function ({ title, body, duration }) {
    this.toast({ title, body, duration, severity: 'standby' })
  }
  off = function ({ title, body, duration }) {
    this.toast({ title, body, duration, severity: 'off' })
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
