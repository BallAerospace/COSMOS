import Vue from 'vue'
import App from './App.vue'

Vue.config.productionTip = false

import '../../packages/cosmosc2-tool-common/src/assets/stylesheets/layout/layout.scss'
import vuetify from './plugins/vuetify'

new Vue({
  vuetify,
  render: (h) => h(App),
}).$mount('#cosmos-main')
