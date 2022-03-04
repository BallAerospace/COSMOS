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

describe('CmdTlmServer Targets', () => {
  it('displays the list of targets', () => {
    cy.visit('/tools/cmdtlmserver/targets')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=targets-table]').contains('INST', { timeout: 10000 })
    cy.get('[data-test=targets-table]').contains('INST2' , { timeout: 10000 })
    cy.get('[data-test=targets-table]').contains('EXAMPLE')
    cy.get('[data-test=targets-table]').contains('TEMPLATED')
  })

  it.only('displays the command count', () => {
    cy.visit('/tools/cmdtlmserver')
    cy.hideNav()
    cy.wait(1000)
    // Connect the EXAMPLE interface since it doesn't automatically send packets
    // it is a stable target to work with the command count
    cy.get('[data-test=interfaces-table]')
      .contains('EXAMPLE_INT')
      .parent()
      .children()
      .eq(2)
      .invoke('text')
      .then((connection) => {
        // Check for DISCONNECTED and if so click connect
        if (connection === ' DISCONNECTED ') {
          cy.get('[data-test=interfaces-table]')
            .contains('EXAMPLE_INT')
            .parent()
            .children()
            .eq(1)
            .click()
        }
      })
    cy.get('[data-test=interfaces-table]')
      .contains('EXAMPLE_INT', { timeout: 10000 })
      .parent()
      .children()
      .eq(2)
      .invoke('text')
      .should('eq', ' CONNECTED ')
    cy.visit('/tools/cmdtlmserver/targets')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=targets-table]', { timeout: 10000 })
      .contains('EXAMPLE_INT')
      .parent()
      .children()
      .eq(2)
      .invoke('text')
      .then((cmdCnt) => {
        cy.visit('/tools/cmdsender/EXAMPLE/START')
        // Make sure the Send button is enabled so we're ready
        cy.get('[data-test=select-send]', { timeout: 10000 }).should('not.have.class', 'v-btn--disabled')
        cy.get('[data-test=select-send]').click().wait(1000)
        cy.visit('/tools/cmdtlmserver')
        cy.hideNav()
        cy.get('.v-tab').contains('Targets').click({ force: true })
        cy.get('[data-test=targets-table]')
          .contains('EXAMPLE_INT')
          .parent()
          .children()
          .eq(2)
          .invoke('text')
          .then((cmdCnt2) => {
            expect(parseInt(cmdCnt2)).to.eq(parseInt(cmdCnt) + 1)
          })
      })
  })

  it('displays the telemetry count', () => {
    cy.visit('/tools/cmdtlmserver/targets')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=targets-table]', { timeout: 10000 })
      .contains('INST_INT')
      .parent()
      .children()
      .eq(3)
      .invoke('text')
      .then((tlmCnt) => {
        cy.wait(1500)
        cy.get('[data-test=targets-table]')
          .contains('INST_INT')
          .parent()
          .children()
          .eq(3)
          .invoke('text')
          .then((tlmCnt2) => {
            expect(tlmCnt2).to.not.eq(tlmCnt)
          })
      })
  })
})
