module.exports = {
  publicPath: '/tools/cmdsender',
  outputDir: 'tools/cmdsender',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  devServer: {
    port: 2913,
    headers: {
      'Access-Control-Allow-Origin': '*',
    },
    client: {
      webSocketURL: {
        hostname: 'localhost',
        pathname: '/tools/cmdtlmserver',
        port: 2913,
      },
    },
  },
  configureWebpack: {
    output: {
      libraryTarget: 'system',
    },
  },
  chainWebpack: config => {
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
