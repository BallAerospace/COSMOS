import Vue from 'vue'
import Vuex from 'vuex'
// import cloneDeep from 'lodash/cloneDeep'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    tlmViewerItems: [],
    // Format of the get_tlm_values method result
    tlmViewerValues: [[], []]
  },
  getters: {},
  // Mutations change store state and must be syncronous
  mutations: {
    tlmViewerUpdateValues(state, values) {
      state.tlmViewerValues = values
      // TODO: Make a deep copy of the values array
      // state.tlmViewerValues = cloneDeep(values)
    },
    tlmViewerAddItem(state, { item, callback }) {
      state.tlmViewerItems.push(item)
      callback(state.tlmViewerItems.length - 1)
    }
  },
  // Actions commit mutations and can contain arbitrary asynchronous operations
  actions: {
    // Deconstruct the context argument to just get 'commit'
    tlmViewerAddItem({ commit }, item) {
      return new Promise(resolve => {
        commit('tlmViewerAddItem', { item: item, callback: resolve })
      })
    }
  },
  modules: {}
})
