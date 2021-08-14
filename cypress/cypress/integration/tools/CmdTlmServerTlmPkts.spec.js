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

describe('CmdTlmServer TlmPackets', () => {
  it('displays the list of telemetry', () => {
    cy.visit('/tools/cmdtlmserver/tlm-packets')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=tlm-packets-table]')
      .contains('HEALTH_STATUS', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        // all searches are automatically rooted to the found tr element
        cy.get('td').eq(0).contains('INST') // either INST or INST2
      })
    cy.get('[data-test=tlm-packets-table]')
      .contains('ADCS')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST') // either INST or INST2
      })
    cy.get('[data-test=tlm-packets-table]')
      .contains('UNKNOWN')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(1).contains('UNKNOWN')
      })
  })
  it('displays the packet count', () => {
    cy.visit('/tools/cmdtlmserver/tlm-packets')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=tlm-packets-table]')
      .contains('HEALTH_STATUS', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td').eq(2).invoke('text').as('tlmCnt')
      })
    cy.wait(1500)
    cy.get('[data-test=tlm-packets-table]')
      .contains('HEALTH_STATUS')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td')
          .eq(2)
          .invoke('text')
          .then((tlmCnt2) => {
            cy.get('@tlmCnt').then((value) => {
              expect(parseInt(tlmCnt2)).to.be.greaterThan(parseInt(value))
            })
          })
      })
  })

  it('displays a raw packet', () => {
    cy.visit('/tools/cmdtlmserver/tlm-packets')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=tlm-packets-table]', { timeout: 10000 })
      .contains('Target Name')
      .click({ force: true })
    cy.get('[data-test=tlm-packets-table]')
      .contains('HEALTH_STATUS', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('button').eq(0).click({ force: true })
      })
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Raw Telemetry Packet: INST HEALTH_STATUS')
      cy.contains(/Packet Time: \d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/, {
        timeout: 10000,
      })
      cy.contains(/Received Time: \d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/)
      cy.get('textarea').invoke('val').should('include', 'Address')
      cy.get('textarea').invoke('val').should('include', '00000000:')
      cy.get('textarea').invoke('val').as('textArea')
    })
    cy.wait(1500)
    cy.get('@textArea').then((value) => {
      cy.get('.v-dialog:visible textarea')
        .invoke('val')
        .then((textarea) => {
          expect(value).to.not.eq(textarea)
        })
    })
    cy.get('.v-dialog:visible').contains('Pause').click({ force: true })
    cy.wait(2000) // Give it a bit to actually Pause
    // Ensure it has paused the output
    cy.get('.v-dialog:visible').within(() => {
      cy.get('textarea').invoke('val').as('textArea')
    })
    cy.wait(1500)
    cy.get('@textArea').then((value) => {
      cy.get('.v-dialog:visible textarea')
        .invoke('val')
        .then((textarea) => {
          expect(value).to.eq(textarea)
        })
    })
    // Resume the updates
    cy.get('.v-dialog:visible').contains('Resume').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.get('textarea').invoke('val').as('textArea')
    })
    cy.wait(1500)
    cy.get('@textArea').then((value) => {
      cy.get('.v-dialog:visible textarea')
        .invoke('val')
        .then((textarea) => {
          expect(value).to.not.eq(textarea)
        })
    })
  })

  it('links to packet viewer', () => {
    cy.visit('/tools/cmdtlmserver/tlm-packets', {
      onBeforeLoad(win) {
        cy.stub(win, 'open').as('windowOpen')
      },
    })

    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=tlm-packets-table]', { timeout: 10000 })
      .contains('Target Name')
      .click({ force: true })
    cy.get('[data-test=tlm-packets-table]')
      .contains('HEALTH_STATUS', { timeout: 10000 })
      .parent('tr')
      .within(() => {
        cy.get('td')
          .eq(0)
          .contains(/^INST$/)
        cy.get('button').eq(1).click({ force: true })
      })
    cy.get('@windowOpen').should(
      'be.calledWith',
      '/tools/packetviewer/INST/HEALTH_STATUS'
    )
  })
})
