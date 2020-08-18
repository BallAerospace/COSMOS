import Vue from 'vue'
import App from './App.vue'
import router from './router'
import store from './store'

Vue.config.productionTip = false

import './assets/stylesheets/layout/layout.scss'
import vuetify from './plugins/vuetify'

new Vue({
  router,
  store, // This injects the Vuex store into all components (eg this.$store)
  vuetify,
  render: h => h(App)
}).$mount('#app')
