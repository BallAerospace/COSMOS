module.exports = {
  publicPath: '/tools/packetviewer',
  outputDir: 'tools/packetviewer',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  devServer: {
    port: 2915,
    headers: {
      'Access-Control-Allow-Origin': '*',
    },
    client: {
      webSocketURL: {
        hostname: 'localhost',
        pathname: '/tools/packetviewer',
        port: 2915,
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
