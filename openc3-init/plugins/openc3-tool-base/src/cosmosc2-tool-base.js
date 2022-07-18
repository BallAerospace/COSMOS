import Vue from 'vue'
import App from './App.vue'
import router from './router'

Vue.config.productionTip = false

import store from '../../packages/openc3-tool-common/src/plugins/store'
import '../../packages/openc3-tool-common/src/assets/stylesheets/layout/layout.scss'
import vuetify from './plugins/vuetify'

// Register these globally so they don't have to be imported every time
import AstroBadge from '../../packages/openc3-tool-common/src/components/icons/AstroBadge'
import AstroBadgeIcon from '../../packages/openc3-tool-common/src/components/icons/AstroBadgeIcon'
import AstroStatusIndicator from '../../packages/openc3-tool-common/src/components/icons/AstroStatusIndicator'
Vue.component('astro-badge', AstroBadge)
Vue.component('astro-badge-icon', AstroBadgeIcon)
Vue.component('astro-status-indicator', AstroStatusIndicator)

const options = OpenC3Auth.getInitOptions()
OpenC3Auth.init(options).then(() => {
  new Vue({
    router,
    store,
    vuetify,
    render: (h) => h(App),
  }).$mount('#openc3-main')
})
