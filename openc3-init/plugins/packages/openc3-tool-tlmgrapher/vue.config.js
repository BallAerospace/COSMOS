module.exports = {
  publicPath: '/tools/tlmgrapher',
  outputDir: 'tools/tlmgrapher',
  filenameHashing: false,
  transpileDependencies: ['uplot', 'vuetify'],
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
