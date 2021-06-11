/*
# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
*/

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

const fs = require('fs')
const path = require('path')

const preprocessor = require('@cypress/vue/dist/plugins/webpack')

module.exports = (on, config) => {
  // Make the download directory cypress/downloads
  const downloadDirectory = path.join(__dirname, '..', 'downloads')

  // `on` is used to hook into various events Cypress emits

  on('before:browser:launch', (browser, options) => {
    if (browser.family === 'chrome' && browser.name !== 'electron') {
      // The available option list is here:
      // https://src.chromium.org/viewvc/chrome/trunk/src/chrome/common/pref_names.cc?view=markup
      // TODO: Is there a way to disable the warning about Ruby file downloads?
      options.preferences.default['download'] = {
        default_directory: downloadDirectory,
      }
      return options
    }
    if (browser.family === 'firefox') {
      options.preferences['browser.download.dir'] = downloadDirectory
      options.preferences['browser.download.folderList'] = 2
      // needed to prevent download prompt for text/csv files.
      options.preferences['browser.helperApps.neverAsk.saveToDisk'] =
        'text/csv,text/plain,text/x-ruby'
      return options
    }
  })

  on('task', {
    clearDownloads: function () {
      fs.readdir(downloadDirectory, (err, files) => {
        if (err) throw err

        for (const file of files) {
          fs.unlink(path.join(downloadDirectory, file), (err) => {
            if (err) throw err
          })
        }
      })
      return null
    },

    readDownloads: function () {
      return fs
        .readdirSync(downloadDirectory)
        .map((file) => path.join(downloadDirectory, file))
    },
  })

  require('@cypress/code-coverage/task')(on, config)
  preprocessor(on, config)
  // IMPORTANT return the config object
  return config
}
