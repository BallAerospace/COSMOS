module.exports = {
  publicPath: '/tools/limitsmonitor',
  outputDir: 'tools/limitsmonitor',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2912,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      client: {
        webSocketURL: {
          hostname: 'localhost',
          pathname: '/tools/limitsmonitor',
          port: 2912,
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
