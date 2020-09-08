/// <reference types="cypress" />
// ***********************************************************
// This example plugins/index.js can be used to load plugins
//
// You can change the location of this file or turn off loading
// the plugins file with the 'pluginsFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/plugins-guide
// ***********************************************************

// This function is called when a project is opened or re-opened (e.g. due to
// the project's config changing)

// // This code uses the webpack.config.js configuration in the preprocessor
// // At one point this seemed to be required but the code below is all that is needed now?
// const webpackPreprocessor = require('@cypress/webpack-preprocessor')
// module.exports = on => {
// const options = {
//   // send in the options from your webpack.config.js, so it works the same
//   // as your app's code
//   webpackOptions: require('../../node_modules/@vue/cli-service/webpack.config.js'),
//   watchOptions: {}
// }
// on('file:preprocessor', webpackPreprocessor(options))
// }
const csv = require('csv-parser')
const fs = require('fs')
const path = require('path')

const preprocessor = require('cypress-vue-unit-test/dist/plugins/webpack')

module.exports = (on, config) => {
  // `on` is used to hook into various events Cypress emits

  on('before:browser:launch', (browser, options) => {
    // Make the download directory cypress/downloads
    const downloadDirectory = path.join(__dirname, '..', 'downloads')

    if (browser.family === 'chromium' && browser.name !== 'electron') {
      options.preferences.default['download'] = {
        default_directory: downloadDirectory
      }
      return options
    }
    if (browser.family === 'firefox') {
      options.preferences['browser.download.dir'] = downloadDirectory
      options.preferences['browser.download.folderList'] = 2
      // needed to prevent download prompt for text/csv files.
      options.preferences['browser.helperApps.neverAsk.saveToDisk'] = 'text/csv'
      return options
    }
  })

  require('@cypress/code-coverage/task')(on, config)
  preprocessor(on, config)
  // IMPORTANT return the config object
  return config
}
