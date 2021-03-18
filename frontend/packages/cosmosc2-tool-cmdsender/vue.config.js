module.exports = {
  publicPath: '/tools/cmdsender',
  outputDir: 'tools/cmdsender',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2913,
      watchOptions: {
        ignored: ['node_modules'],
        aggregateTimeout: 300,
        poll: 1500,
      },
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      public: 'localhost:2913/tools/cmdsender'
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
