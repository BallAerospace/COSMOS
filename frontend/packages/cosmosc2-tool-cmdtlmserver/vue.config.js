module.exports = {
  publicPath: '/tools/cmdtlmserver',
  outputDir: 'tools/cmdtlmserver',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2911,
      watchOptions: {
        ignored: ['node_modules'],
        aggregateTimeout: 300,
        poll: 1500,
      },
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      public: 'localhost:2911/tools/cmdtlmserver'
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
