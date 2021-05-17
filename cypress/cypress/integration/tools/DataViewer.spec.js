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

describe('DataViewer', () => {
  it('adds a raw packet to a new tab', () => {
    cy.visit('/tools/dataviewer')
    cy.hideNav()
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').should('be.visible').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.wait(1000) // wait for the first packet to come in
    cy.get('[data-test=dump-component-text-area]').should('not.have.value', '')
  })

  it('adds a decom packet to a new tab', () => {
    cy.visit('/tools/dataviewer')
    cy.hideNav()
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').should('be.visible').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=new-packet-decom-radio]').check({ force: true })
    cy.get('[data-test=add-packet-value-type]').should('be.visible')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.wait(1000) // wait for the first packet to come in
    cy.get('[data-test=dump-component-text-area]').should('not.have.value', '')
  })

  // TODO: add pause test and get more coverage
})
