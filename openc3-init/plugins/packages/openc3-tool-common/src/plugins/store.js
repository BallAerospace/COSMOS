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

import Vue from 'vue'
import Vuex from 'vuex'

Vue.use(Vuex)

const NOTIFY_HISTORY_MAX_LENGTH = 100

if (!window.hasOwnProperty('OpenC3Store')) {
  window.OpenC3Store = new Vuex.Store({
    state: {
      notifyHistory: [],
      tlmViewerItems: [],
      tlmViewerValues: {},
    },
    getters: {},
    mutations: {
      notifyAddHistory: function (state, notification) {
        if (state.notifyHistory.length >= NOTIFY_HISTORY_MAX_LENGTH) {
          state.notifyHistory.length = NOTIFY_HISTORY_MAX_LENGTH - 1
        }
        state.notifyHistory.unshift(notification)
      },
      notifyClearHistory: function (state) {
        state.notifyHistory = []
      },

      tlmViewerUpdateValues: function (state, values) {
        for (let i = 0; i < values.length; i++) {
          Vue.set(state.tlmViewerValues, state.tlmViewerItems[i], values[i])
        }
      },
      tlmViewerAddItem: function (state, item) {
        state.tlmViewerItems.push(item)
        Vue.set(state.tlmViewerValues, item, [null, null])
      },
      tlmViewerDeleteItem: function (state, item) {
        let index = state.tlmViewerItems.indexOf(item)
        state.tlmViewerItems.splice(index, 1)
        delete state.tlmViewerValues[item]
      },
    },
    modules: {},
  })
}

export default window.OpenC3Store
