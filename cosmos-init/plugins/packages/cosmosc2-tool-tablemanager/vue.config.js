module.exports = {
  publicPath: '/tools/tablemanager',
  outputDir: 'tools/tablemanager',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2916,
      watchOptions: {
        ignored: ['node_modules'],
        aggregateTimeout: 300,
        poll: 1500,
      },
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      public: 'localhost:2916/tools/tablemanager',
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
