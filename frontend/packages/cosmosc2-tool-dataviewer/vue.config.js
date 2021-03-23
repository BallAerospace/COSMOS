module.exports = {
  publicPath: '/tools/dataviewer',
  outputDir: 'tools/dataviewer',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2919,
      watchOptions: {
        ignored: ['node_modules'],
        aggregateTimeout: 300,
        poll: 1500,
      },
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      public: 'localhost:2919/tools/dataviewer',
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
  },
}
