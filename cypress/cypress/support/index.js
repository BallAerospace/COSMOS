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

// ***********************************************************
// This example support/index.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

import '@cypress/code-coverage/support'
import '@cypress/vue/dist/support'
import './commands'

require('@cypress/skip-test/support')

Cypress.on('window:before:load', (win) => {
  cy.spy(win.console, 'log').as('consoleLog')
  cy.spy(win.console, 'error').as('consoleError')
})

Cypress.on('window:load', (win) => {
  win.localStorage.token = 'password'
  win.localStorage.scope = 'DEFAULT'
})

before(() => {
  // Runs once before all tests
  cy.visit('/login')
  cy.wait(1000)
  cy.get('body').then(($body) => {
    // Ensure that a password is set. If not, set it to "password" so auth works.
    // If a password is already set, do nothing. (Cypress tests won't work if that password isn't "password" though)
    if ($body.text().includes('Create a')) {
      cy.get('[data-test=new-password]').clear().type('password')
      cy.get('[data-test=confirm-password]').clear().type('password')
      cy.get('[data-test=set-password]').click({ force: true })
    }
  })
})
