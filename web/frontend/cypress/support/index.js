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
import 'cypress-vue-unit-test/dist/support'
import './commands'

Cypress.on('window:before:load', win => {
  cy.spy(win.console, 'log').as('consoleLog')
  cy.spy(win.console, 'error').as('consoleError')
})
