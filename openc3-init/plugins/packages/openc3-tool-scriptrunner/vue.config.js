module.exports = {
  publicPath: '/tools/scriptrunner',
  outputDir: 'tools/scriptrunner',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
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
    config.externals([
      'vue',
      'vuetify',
      'vuex',
      'vue-router',
    ])
  },
}
