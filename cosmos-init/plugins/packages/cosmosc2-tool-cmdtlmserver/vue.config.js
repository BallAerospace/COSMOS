module.exports = {
  publicPath: '/tools/cmdtlmserver',
  outputDir: 'tools/cmdtlmserver',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    output: {
      libraryTarget: 'system',
    },
    devServer: {
      port: 2911,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      client: {
        webSocketURL: {
          hostname: 'localhost',
          pathname: '/tools/cmdtlmserver',
          port: 2911,
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
