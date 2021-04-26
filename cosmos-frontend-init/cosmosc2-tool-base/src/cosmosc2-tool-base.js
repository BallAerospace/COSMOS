import Vue from 'vue'
import App from './App.vue'

Vue.config.productionTip = false

import '../../packages/cosmosc2-tool-common/src/assets/stylesheets/layout/layout.scss'
import vuetify from './plugins/vuetify'

// Register these globally so they don't have to be imported every time
import AstroBadge from '../../packages/cosmosc2-tool-common/src/components/icons/AstroBadge'
import AstroBadgeIcon from '../../packages/cosmosc2-tool-common/src/components/icons/AstroBadgeIcon'
import AstroStatusIndicator from '../../packages/cosmosc2-tool-common/src/components/icons/AstroStatusIndicator'
Vue.component('astro-badge', AstroBadge)
Vue.component('astro-badge-icon', AstroBadgeIcon)
Vue.component('astro-status-indicator', AstroStatusIndicator)

const options = CosmosAuth.getInitOptions()
CosmosAuth.init(options).then(() => {
  new Vue({
    vuetify,
    render: (h) => h(App),
  }).$mount('#cosmos-main')
})
