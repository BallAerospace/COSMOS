import './set-public-path'
import Vue from 'vue'
import VuejsDialog from 'vuejs-dialog'
import singleSpaVue from 'single-spa-vue'

import App from './App.vue'
import router from './router'
import store from './store'

// Register these globally so they don't have to be imported every time
import AstroBadge from '@cosmosc2/tool-common/src/components/icons/AstroBadge'
import AstroBadgeIcon from '@cosmosc2/tool-common/src/components/icons/AstroBadgeIcon'
Vue.component('astro-badge', AstroBadge)
Vue.component('astro-badge-icon', AstroBadgeIcon)

Vue.config.productionTip = false

import '@cosmosc2/tool-common/src/assets/stylesheets/layout/layout.scss'
import vuetify from './plugins/vuetify'
import 'vuejs-dialog/dist/vuejs-dialog.min.css'
import PortalVue from 'portal-vue'

Vue.use(PortalVue)
Vue.use(VuejsDialog)

const vueLifecycles = singleSpaVue({
  Vue,
  appOptions: {
    router,
    store,
    vuetify,
    render(h) {
      return h(App, {
        props: {},
      })
    },
    el: '#cosmos-tool',
  },
})

export const bootstrap = vueLifecycles.bootstrap
export const mount = vueLifecycles.mount
export const unmount = vueLifecycles.unmount
