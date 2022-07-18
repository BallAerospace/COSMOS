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
      'vue',
      'vuetify',
      'vuex',
      'vue-router',
    ])
  },
}
