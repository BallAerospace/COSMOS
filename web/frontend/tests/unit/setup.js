import Vue from 'vue'
Vue.config.productionTip = false

// Define the magic customElements global which @astrouxds uses
global.customElements = new Object()
global.customElements.define = function () {}
