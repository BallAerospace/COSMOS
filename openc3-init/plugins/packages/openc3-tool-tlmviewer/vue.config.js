module.exports = {
  publicPath: '/tools/tlmviewer',
  outputDir: 'tools/tlmviewer',
  filenameHashing: false,
  transpileDependencies: ['uplot', 'vuetify'],
  devServer: {
    port: 2920,
    headers: {
      'Access-Control-Allow-Origin': '*',
    },
    client: {
      webSocketURL: {
        hostname: 'localhost',
        pathname: '/tools/tlmviewer',
        port: 2920,
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
