module.exports = {
  publicPath: '/tools/scriptrunner',
  outputDir: 'tools/scriptrunner',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2914,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      client: {
        webSocketURL: {
          hostname: 'localhost',
          pathname: '/tools/scriptrunner',
          port: 2914,
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
