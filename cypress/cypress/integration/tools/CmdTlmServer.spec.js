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

describe('CmdTlmServer', () => {
  //
  // Test the File menu
  //
  it('changes the polling rate', function () {
    cy.visit('/tools/cmdtlmserver')
    cy.hideNav()
    cy.contains('td', 'CONNECTED')
    cy.wait(1000) // Let things spin up
    cy.get('[data-test=interfaces-table]')
      .contains('INST_INT')
      .parent()
      .children()
      .eq(7)
      .invoke('text')
      .then((rxBytes1) => {
        cy.wait(1500)
        cy.get('[data-test=interfaces-table]')
          .contains('INST_INT')
          .parent()
          .children()
          .eq(7)
          .invoke('text')
          .then((rxBytes2) => {
            expect(rxBytes2).to.not.eq(rxBytes1)
          })
      })

    cy.contains('TEMP1')
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Options').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.get('input').clear().type('5000')
    })
    cy.get('.v-dialog:visible').type('{esc}')

    cy.get('[data-test=interfaces-table]')
      .contains('INST_INT')
      .parent()
      .children()
      .eq(7)
      .invoke('text')
      .then((rxBytes1) => {
        cy.wait(2000)
        cy.get('[data-test=interfaces-table]')
          .contains('INST_INT')
          .parent()
          .children()
          .eq(7)
          .invoke('text')
          .then((rxBytes2) => {
            expect(rxBytes2).to.eq(rxBytes1)
          })

        cy.wait(2500)
        cy.get('[data-test=interfaces-table]')
          .contains('INST_INT')
          .parent()
          .children()
          .eq(7)
          .invoke('text')
          .then((rxBytes3) => {
            expect(rxBytes3).to.not.eq(rxBytes1)
          })
      })
  })

  //
  // Test the basic functionality of the application
  //
  it('stops posting to the api after closing', () => {
    // Override the fail handler to catch the expected fail
    Cypress.on('fail', (error) => {
      // Expect a No request error message once the API requests stop
      expect(error.message).to.include('No request ever occurred.')
      return false
    })
    cy.visit('/tools/cmdtlmserver')
    cy.hideNav()
    cy.contains('Log Messages')
    cy.visit('/tools/cmdsender')
    cy.contains('Command Sender')
    cy.wait(1000) // Allow the initial Command Sender APIs to happen
    cy.server()
    cy.route('POST', '/api').as('api')
    cy.wait('@api', {
      requestTimeout: 1000,
    }).then((xhr) => {
      // If an xhr request is made this will fail the test which we want
      assert.isNull(xhr.response.body)
    })
  })
})
