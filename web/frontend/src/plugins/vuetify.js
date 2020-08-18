import Vue from 'vue'
import Vuetify from 'vuetify/lib'

Vue.use(Vuetify)

export default new Vuetify({
  theme: {
    dark: true,
    options: {
      customProperties: true
    },
    themes: {
      dark: {
        primary: '#005a8f',
        secondary: '#4dacff',
        tertiary: '#283f58'
      },
      light: {
        primary: '#cce6ff',
        secondary: '#cce6ff'
      }
    }
  }
})
