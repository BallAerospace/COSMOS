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

describe('CmdTlmServer Targets', () => {
  it('displays the list of targets', () => {
    cy.visit('/tools/cmdtlmserver/targets')
    cy.hideNav()
    cy.get('[data-test=targets-table]', { timeout: 10000 }).contains('INST')
    cy.get('[data-test=targets-table]').contains('INST2')
    cy.get('[data-test=targets-table]').contains('EXAMPLE')
    cy.get('[data-test=targets-table]').contains('TEMPLATED')
    // Check for the INST_INT interface name for the INST target
    // cy.get('[data-test=targets-table]')
    //   .contains(/^INST$/)
    //   .parent()
    //   .children()
    //   .eq(1)
    //   .invoke('text')
    //   .should('eq', 'INST_INT')
  })
  xit('displays the command count', () => {
    cy.visit('/tools/cmdtlmserver/targets')
    cy.hideNav()
    cy.get('[data-test=targets-table]', { timeout: 10000 })
      .contains('INST2_INT')
      .parent()
      .children()
      .eq(2)
      .invoke('text')
      .then((cmdCnt) => {
        cy.visit('/tools/commandsender/INST2/ABORT')
        cy.hideNav()
        cy.contains('Aborts a collect')
        cy.get('button').contains('Send').click()
        cy.visit('/tools/cmdtlmserver')
        cy.hideNav()
        cy.get('.v-tab').contains('Targets').click()
        cy.get('[data-test=targets-table]')
          .contains('INST2_INT')
          .parent()
          .children()
          .eq(2)
          .invoke('text')
          .then((cmdCnt2) => {
            expect(parseInt(cmdCnt2)).to.eq(parseInt(cmdCnt) + 1)
          })
      })
  })
  xit('displays the telemetry count', () => {
    cy.visit('/tools/cmdtlmserver/targets')
    cy.hideNav()
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
