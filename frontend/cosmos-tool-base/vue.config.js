module.exports = {
  publicPath: '/',
  outputDir: 'tools/base',
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2903,
      watchOptions: {
        ignored: ['node_modules'],
        aggregateTimeout: 300,
        poll: 1500,
      },
    },
  },
}
