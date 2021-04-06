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

import Vue from 'vue'
import Vuex from 'vuex'
// import cloneDeep from 'lodash/cloneDeep'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    tlmViewerItems: [],
    // Format of the get_tlm_values method result
    tlmViewerValues: {},
  },
  getters: {},
  // Mutations change store state and must be syncronous
  mutations: {
    tlmViewerUpdateValues(state, values) {
      for (let i = 0; i < values.length; i++) {
        Vue.set(state.tlmViewerValues, state.tlmViewerItems[i], values[i])
      }
    },
    tlmViewerAddItem(state, item) {
      state.tlmViewerItems.push(item)
      Vue.set(state.tlmViewerValues, item, [null, null])
    },
    tlmViewerDeleteItem(state, item) {
      let index = state.tlmViewerItems.indexOf(item)
      state.tlmViewerItems.splice(index, 1)
      delete state.tlmViewerValues[item]
    },
  },
  modules: {},
})
