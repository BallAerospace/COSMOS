module.exports = {
  publicPath: '/tools/tablemanager',
  outputDir: 'tools/tablemanager',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2916,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      client: {
        webSocketURL: {
          hostname: 'localhost',
          pathname: '/tools/tablemanager',
          port: 2916,
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
