const webpack = require('webpack')
const systemjsInterop = require('systemjs-webpack-interop/webpack-config')
const { mergeWithRules } = require('webpack-merge')
const singleSpaDefaults = require('webpack-config-single-spa')
const HtmlWebpackPlugin = require('html-webpack-plugin')
const CopyWebpackPlugin = require('copy-webpack-plugin')
const { VueLoaderPlugin } = require('vue-loader')
const path = require('path')

function resolve(dir) {
  return path.join(__dirname, '..', dir)
}

module.exports = (webpackConfigEnv, argv) => {
  const orgName = 'openc3'
  const defaultConfig = singleSpaDefaults({
    orgName,
    projectName: 'tool-base',
    webpackConfigEnv,
    argv,
    disableHtmlGeneration: true,
  })

  return mergeWithRules({
    module: {
      rules: {
        test: 'match',
        use: 'replace',
        loader: 'replace',
      },
    },
  })(defaultConfig, {
    // modify the webpack config however you'd like to by adding to this object
    output: {
      path: path.resolve(__dirname, 'tools/base'),
      libraryTarget: 'system', // This line is in all the vue.config.js files, is it needed here?
    },
    plugins: [
      new HtmlWebpackPlugin({
        inject: false,
        template: 'src/index.ejs',
        templateParameters: {
          isLocal: webpackConfigEnv && webpackConfigEnv.isLocal,
          orgName,
        },
      }),
      new HtmlWebpackPlugin({
        inject: false,
        template: 'src/index-allow-http.ejs',
        filename: 'index-allow-http.html',
        templateParameters: {
          isLocal: webpackConfigEnv && webpackConfigEnv.isLocal,
          orgName,
        },
      }),
      new VueLoaderPlugin(),
      new CopyWebpackPlugin({ patterns: [{ from: 'public', to: '.' }] }),
      new webpack.DefinePlugin({
        'process.env.BASE_URL': process.env.BASE_URL,
      }),
    ],
    module: {
      rules: [
        {
          test: /\.vue$/,
          loader: 'vue-loader',
        },
        {
          test: /\.html$/i,
          exclude: /node_modules/,
          use: { loader: 'vue-loader' },
        },
        {
          test: /\.s[ac]ss$/i,
          use: [
            // Creates `style` nodes from JS strings
            'vue-style-loader',
            // Translates CSS into CommonJS
            'css-loader',
            // Compiles Sass to CSS
            'sass-loader',
          ],
        },
        {
          test: /\.(png|jpe?g|gif)$/i,
          type: 'asset/resource',
        },
      ],
    },
    resolve: {
      extensions: ['.js', '.vue', '.json'],
      alias: {
        '@': resolve('src'),
      },
    },
    externals: [
      'vue',
      'vuetify',
      'vuex',
      'vue-router',
    ],
  })
}

// Throws errors if your webpack config won't interop well with SystemJS
systemjsInterop.checkWebpackConfig(module.exports)
