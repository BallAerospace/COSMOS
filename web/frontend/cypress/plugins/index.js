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
const csv = require("csv-parser")
const fs = require("fs")
const path = require("path")

const preprocessor = require('cypress-vue-unit-test/dist/plugins/webpack')

module.exports = (on, config) => {
  // `on` is used to hook into various events Cypress emits

  on("task", {
    parseCsv({ filePath }) {
      return new Promise((resolve, reject) => {
        try {
          const jsonData = csv.parse(fs.readFileSync(filePath))
          resolve(jsonData)
        } catch (e) {
          reject(e)
        }
      })
    }
  })


  require('@cypress/code-coverage/task')(on, config)
  preprocessor(on, config)
  // IMPORTANT return the config object
  return config
}
