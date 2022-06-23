module.exports = {
  publicPath: '/tools/handbooks',
  outputDir: 'tools/handbooks',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  devServer: {
    port: 2923,
    headers: {
      'Access-Control-Allow-Origin': '*',
    },
    client: {
      webSocketURL: {
        hostname: 'localhost',
        pathname: '/tools/handbooks',
        port: 2923,
      },
    },
  },
  configureWebpack: {
    output: {
      libraryTarget: 'system',
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
    config.externals(['vue', 'vuetify', 'vuex', 'vue-router'])
  },
}
