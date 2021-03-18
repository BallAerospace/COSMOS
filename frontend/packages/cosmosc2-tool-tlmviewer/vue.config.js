module.exports = {
  publicPath: '/tools/tlmviewer',
  outputDir: 'tools/tlmviewer',
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
      public: 'localhost:2916/tools/tlmviewer'
    }
  },
  chainWebpack(config) {
    config.module
      .rule('js')
        .use('babel-loader')
          .tap(options => {
            return {
              rootMode: "upward"
            }
          })
  }
}
