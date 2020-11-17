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
