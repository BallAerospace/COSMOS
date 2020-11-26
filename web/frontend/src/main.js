import Vue from 'vue'
import VuejsDialog from 'vuejs-dialog'
import App from './App.vue'
import router from './router'
import store from './store'

Vue.config.productionTip = false

import './assets/stylesheets/layout/layout.scss'
import vuetify from './plugins/vuetify'
import 'vuejs-dialog/dist/vuejs-dialog.min.css'

Vue.use(VuejsDialog)

new Vue({
  router,
  store, // This injects the Vuex store into all components (eg this.$store)
  vuetify,
  render: (h) => h(App),
}).$mount('#app')
