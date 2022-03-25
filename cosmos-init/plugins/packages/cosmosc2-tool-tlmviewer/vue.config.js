module.exports = {
  publicPath: '/tools/tlmviewer',
  outputDir: 'tools/tlmviewer',
  filenameHashing: false,
  transpileDependencies: ['uplot', 'vuetify'],
  configureWebpack: {
    // TODO: Necessary?
    // module: {
    //   rules: [{ parser: { system: false } }],
    // },
    // TODO: Necessary?
    // output: {
    //   libraryTarget: 'system',
    // },
    devServer: {
      port: 2920,
      // TODO: Necessary?
      allowedHosts: 'auto',
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
