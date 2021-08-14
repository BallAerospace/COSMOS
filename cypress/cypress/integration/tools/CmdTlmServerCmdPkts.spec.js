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

describe('CmdTlmServer CmdPackets', () => {
  it('displays the list of command', () => {
    cy.visit('/tools/cmdtlmserver/cmd-packets')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=cmd-packets-table]')
      .contains('ABORT', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        // all searches are automatically rooted to the found tr element
        cy.get('td').eq(0).contains('INST') // either INST or INST2
      })
    cy.get('[data-test=cmd-packets-table]')
      .contains('COLLECT')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST') // either INST or INST2
      })
    cy.get('[data-test=cmd-packets-table]')
      .contains('EXAMPLE')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(1).contains('START')
      })
  })
  it('displays the command count', () => {
    cy.visit('/tools/cmdtlmserver/cmd-packets')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=cmd-packets-table]')
      .contains('ABORT', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td').eq(2).invoke('text').as('cmdCnt')
      })
    cy.visit('/tools/cmdsender/INST/ABORT')
    cy.hideNav()
    cy.contains('Aborts a collect')
    cy.get('button').contains('Send').click({ force: true })
    cy.visit('/tools/cmdtlmserver/cmd-packets')
    cy.hideNav()
    cy.get('[data-test=cmd-packets-table]')
      .contains('ABORT', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td')
          .eq(2)
          .invoke('text')
          .then((cmdCnt2) => {
            cy.get('@cmdCnt').then((value) => {
              expect(parseInt(cmdCnt2)).to.eq(parseInt(value) + 1)
            })
          })
      })
  })

  it('displays a raw command', () => {
    // Send a command to ensure it's there
    cy.visit('/tools/cmdsender/INST/ABORT')
    cy.hideNav()
    cy.wait(1000)
    cy.scrollTo(0, 0)
    cy.contains('Aborts a collect')
    cy.get('button').contains('Send').click({ force: true })
    cy.wait(2000)
    cy.visit('/tools/cmdtlmserver/cmd-packets')
    cy.hideNav()
    cy.get('[data-test=cmd-packets-table]')
      .contains('ABORT', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('button').eq(0).click({ force: true }).wait(4000)
      })
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Raw Command Packet: INST ABORT')
      cy.contains(/Packet Time: \d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/)
      cy.contains(/Received Time: \d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/)
      cy.get('textarea').invoke('val').should('include', 'Address')
      cy.get('textarea').invoke('val').should('include', '00000000:')
    })
    cy.get('.v-dialog:visible').type('{esc}')
    // Make sure we can re-open the raw dialog
    cy.get('[data-test=cmd-packets-table]')
      .contains('ABORT')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('button').eq(0).click({ force: true }).wait(4000)
      })
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Raw Command Packet: INST ABORT')
    })
    cy.get('.v-dialog:visible').type('{esc}')
  })

  it('links to command sender', () => {
    cy.visit('/tools/cmdtlmserver/cmd-packets', {
      onBeforeLoad(win) {
        cy.stub(win, 'open').as('windowOpen')
      },
    })

    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=cmd-packets-table]')
      .contains('ABORT', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('button').eq(1).click({ force: true }).wait(4000)
      })
    cy.get('@windowOpen').should('be.calledWith', '/tools/cmdsender/INST/ABORT')
  })
})
