module.exports = {
  publicPath: '/tools/dataextractor',
  outputDir: 'tools/dataextractor',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  devServer: {
    port: 2918,
    headers: {
      'Access-Control-Allow-Origin': '*',
    },
    client: {
      webSocketURL: {
        hostname: 'localhost',
        pathname: '/tools/dataextractor',
        port: 2918,
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
