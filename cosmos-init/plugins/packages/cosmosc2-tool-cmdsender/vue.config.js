module.exports = {
  publicPath: '/tools/cmdsender',
  outputDir: 'tools/cmdsender',
  filenameHashing: false,
  transpileDependencies: ['vuetify'],
  configureWebpack: {
    devServer: {
      port: 2913,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      client: {
        webSocketURL: {
          hostname: "0.0.0.0",
          pathname: "/tools/cmdsender",
          port: 2913,
        },
      },
      static: {
        watch: true,
        // watchOptions: {
        //   ignored: 'node_modules',
        //   aggregateTimeout: 300,
        //   poll: 1500,
        // },
      }
      // webSocketServer: {
      //   options: {
      //     path: "/tools/cmdsender",
      //   },
      // },
    },
  },
  // chainWebpack: config => {
  //   config.module
  //     .rule('js')
  //     .use('babel-loader')
  //     .tap((options) => {
  //       return {
  //         rootMode: 'upward',
  //       }
  //     })
  //   config.externals([
  //     'portal-vue',
  //     'vue',
  //     'vuejs-dialog',
  //     'vuetify',
  //     'vuex',
  //     'vue-router',
  //   ])
  // },
}
