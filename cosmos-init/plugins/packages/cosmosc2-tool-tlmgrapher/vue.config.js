module.exports = {
  publicPath: '/tools/tlmgrapher',
  outputDir: 'tools/tlmgrapher',
  filenameHashing: false,
  transpileDependencies: ['uplot', 'vuetify'],
  configureWebpack: {
    devServer: {
      port: 2917,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      client: {
        webSocketURL: {
          hostname: 'localhost',
          pathname: '/tools/tlmgrapher',
          port: 2917,
        },
      },
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
