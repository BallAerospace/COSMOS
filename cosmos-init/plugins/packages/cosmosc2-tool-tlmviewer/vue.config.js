module.exports = {
  publicPath: '/tools/tlmviewer',
  outputDir: 'tools/tlmviewer',
  filenameHashing: false,
  transpileDependencies: ['uplot', 'vuetify'],
  configureWebpack: {
    module: {
      rules: [{ parser: { system: false } }],
    },
  },
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
