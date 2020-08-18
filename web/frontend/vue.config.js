module.exports = {
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      watchOptions: {
        ignored: ['node_modules'],
        aggregateTimeout: 300,
        poll: 1500
      },
      public: 'localhost:8080'
    }
  }
}
