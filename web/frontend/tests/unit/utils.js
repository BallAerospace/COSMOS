import Vue from 'vue'
import Vuetify from 'vuetify'
import { mount, shallowMount, createLocalVue } from '@vue/test-utils'
Vue.use(Vuetify)

export default {
  createWrapper: (component, options = {}, vuetifyOptions = {}) => {
    const localVue = createLocalVue()
    const vuetify = new Vuetify(vuetifyOptions)
    return mount(component, {
      localVue,
      vuetify,
      ...options,
    })
  },
  createShallowWrapper: (component, options = {}, vuetifyOptions = {}) => {
    const localVue = createLocalVue()
    const vuetify = new Vuetify(vuetifyOptions)
    return shallowMount(component, {
      localVue,
      vuetify,
      ...options,
    })
  },
}
