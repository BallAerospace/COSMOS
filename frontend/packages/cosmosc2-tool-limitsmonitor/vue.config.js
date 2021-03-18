module.exports = {
  publicPath: '/tools/limitsmonitor',
  outputDir: 'tools/limitsmonitor',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2912,
      watchOptions: {
        ignored: ['node_modules'],
        aggregateTimeout: 300,
        poll: 1500,
      },
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      public: 'localhost:2912/tools/limitsmonitor'
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
