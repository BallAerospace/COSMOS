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

import ConfirmDialog from './ConfirmDialog.vue'

class Dialog {
  constructor(Vue, options = {}) {
    this.Vue = Vue
    this.mounted = false
    this.$root = null
  }

  mount = function () {
    if (this.mounted) return

    const DialogConstructor = this.Vue.extend(ConfirmDialog)
    const dialog = new DialogConstructor()

    const el = document.createElement('div')
    document.querySelector('#openc3-app-toolbar > div').appendChild(el)
    this.$root = dialog.$mount(el)

    this.mounted = true
  }

  open = function ({
    title,
    text,
    okText,
    cancelText,
    html,
  }) {
    this.mount()
    return new Promise((resolve, reject) => {
      this.$root.dialog(
        { title, text, okText, cancelText, html },
        resolve, reject
      )
    })
  }

  confirm = function (text, {
    okText = 'Ok',
    cancelText = 'Cancel',
  }) {
    return this.open({
      title: 'Confirm',
      text: text,
      okText: okText,
      cancelText: cancelText,
      html: false,
    })
  }
  alert = function (text, {
    okText = 'Ok',
    html = false,
  }) {
    return this.open({
      title: 'Alert',
      text: text,
      okText: okText,
      cancelText: null, // Which means no cancel
      html: html,
    })
  }
}

export default {
  install(Vue, options) {
    if (!Vue.prototype.hasOwnProperty('$dialog')) {
      Vue.dialog = new Dialog(Vue, options)

      Object.defineProperties(Vue.prototype, {
        $dialog: {
          get() {
            return Vue.dialog
          },
        },
      })
    }
  },
}
