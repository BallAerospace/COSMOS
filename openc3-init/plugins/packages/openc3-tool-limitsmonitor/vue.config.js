module.exports = {
  publicPath: '/tools/limitsmonitor',
  outputDir: 'tools/limitsmonitor',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
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
