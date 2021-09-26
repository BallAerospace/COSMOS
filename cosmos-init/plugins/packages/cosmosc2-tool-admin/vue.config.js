module.exports = {
  publicPath: '/tools/admin',
  outputDir: 'tools/admin',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2930,
      watchOptions: {
        ignored: ['node_modules'],
        aggregateTimeout: 300,
        poll: 1500,
      },
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      public: 'localhost:2930/tools/admin',
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
