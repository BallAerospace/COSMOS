const path = require('path')

module.exports = {
  css: {
    extract: false,
  },
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  chainWebpack(config) {
    config.module
      .rule('js')
      .use('babel-loader')
      .tap((options) => {
        return {
          rootMode: 'upward',
        }
      })
    config.externals([
      'portal-vue',
      'vue',
      'vuejs-dialog',
      'vuetify',
      'vuex',
      'vue-router',
    ])
  },
}
