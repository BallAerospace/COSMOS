/*
# Copyright 2022 Ball Aerospace & Technologies Corp.
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

describe('TableManager', () => {
  beforeEach(() => {
    cy.visit('/tools/tablemanager')
    cy.hideNav()
    cy.wait(1000)
  })

  //
  // Test the File menu
  //
  it('creates a binary file', function () {
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('New').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.wait(1000) // allow the dialog to open
      cy.get('[data-test=file-open-save-search]').type('MCConfig')
      cy.contains('MCConfigurationTable').click({ force: true }).wait(1000)
      cy.get('[data-test=file-open-save-submit-btn]').click({ force: true })
      cy.wait(1000)
    })
    cy.contains('MC CONFIGURATION')
    cy.get('.v-tab').should('have.length', 1)
  })
  it('opens a binary file', function () {
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.wait(1000) // allow the dialog to open
      cy.get('[data-test=file-open-save-search]').type('ConfigTables.bin')
      cy.contains('ConfigTables').click({ force: true }).wait(1000)
      cy.get('[data-test=file-open-save-submit-btn]').click({ force: true })
      cy.wait(1000)
    })
    cy.get('.v-tab').should('have.length', 3)
    cy.contains('MC CONFIGURATION')
    cy.contains('TLM MONITORING')
    cy.contains('PPS SELECTION')

    // Test searching
    cy.get('tr').should('have.length', 12)
    cy.get('div label').contains('Search').siblings('input').as('search')
    cy.get('@search').type('UNEDIT')
    cy.get('tr').should('have.length', 4)
    // TODO would be fun to test that these are disabled
    // cy.get('tr').each(($el, index, $list) => {
    //   // Need to get the 'tr td div'
    //   expect($el).to.have.class('v-input--is-disabled')
    // })
    cy.get('@search').clear()
    cy.get('tr').should('have.length', 12)
  })
})
