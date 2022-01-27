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

describe('TlmGrapher', () => {
  //
  beforeEach(() => {
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    cy.wait(1000)
  })

  afterEach(() => {
    //
  })

  // Creates an alias to the graph width and height
  function aliasWidthHeight() {
    cy.get('#gridItem0').invoke('width').as('width')
    cy.get('#gridItem0').invoke('height').as('height')
  }
  // Compares the current graph width and height to the aliased values
  function checkWidthHeight(
    widthComparison,
    widthMultiplier = 1,
    heightComparison,
    heightMultiplier = 1
  ) {
    cy.get('@width').then((value) => {
      cy.get('#gridItem0')
        .invoke('width')
        .should(widthComparison, value * widthMultiplier)
    })
    cy.get('@height').then((value) => {
      cy.get('#gridItem0')
        .invoke('height')
        .should(heightComparison, value * heightMultiplier)
    })
  }

  beforeEach(() => {
    Cypress.on('uncaught:exception', (err, runnable) => false)
  })

  it.skip('adds items to a graph, starts, pauses, resumes and stops', () => {
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click({ force: true })
    cy.get('#gridItem0').contains('TEMP1')
    cy.wait(5000) // Wait for graphing to occur
    // Add another item while it is already graphing
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click({ force: true })
    cy.get('#gridItem0').contains('TEMP2')
    cy.wait(5000) // Wait for graphing to occur
    cy.get('[data-test="Telemetry Grapher-Graph"]').click({ force: true })
    cy.get('[data-test="Telemetry Grapher-Graph-Pause"]').click({ force: true })
    cy.contains('Description').click({ force: true })
    cy.wait(1000)
    cy.get('[data-test="Telemetry Grapher-Graph"]').click({ force: true })
    cy.get('[data-test="Telemetry Grapher-Graph-Resume"]').click({
      force: true,
    })
    cy.wait(2000)
    cy.get('[data-test="Telemetry Grapher-Graph"]').click({ force: true })
    cy.get('[data-test="Telemetry Grapher-Graph-Stop"]').click({
      force: true,
    })
    cy.wait(1000) // Small wait to visually see it stopped
  })

  it('edits a graph title', () => {
    cy.contains('Graph 0')
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click({ force: true })
    cy.wait(5000) // Wait for graphing to occur
    cy.get('[data-test=editGraphIcon]').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.get('[data-test=editGraphTitle]').clear().type('My New Title')
      cy.contains('of 2')
      cy.get('[data-test=deleteItemIcon1]').click({ force: true })
      cy.wait(1000)
      cy.contains('of 1')
      cy.contains('Ok').click({ force: true })
    })
    cy.contains('My New Title')
      .parents('.v-card')
      .eq(0)
      .within(() => {
        cy.contains('TEMP2')
        cy.should('not.contain', 'TEMP1')
      })
  })

  it.skip('edits the min/max scale', () => {
    // TODO
  })

  it.skip('edits the start date/time', () => {
    // TODO
  })

  it.skip('edits the end date/time', () => {
    // TODO
  })

  it('adds multiple graphs', () => {
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click({ force: true })
    cy.get('.v-toolbar').contains('Graph').click({ force: true })
    cy.contains('Add Graph').click({ force: true })
    cy.get('#gridItem1')
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click({ force: true })
    // Ensure TEMP2 got added to the correct graph
    cy.get('#gridItem1').within(() => {
      cy.contains('Graph 1')
      cy.contains('TEMP2')
      cy.should('not.contain', 'TEMP1')
    })
    cy.get('#gridItem0').within(() => {
      cy.contains('Graph 0')
      cy.contains('TEMP1')
      cy.should('not.contain', 'TEMP2')
      // Close Graph 0
      cy.get('[data-test=closeGraphIcon]').click({ force: true })
    })
    cy.get('#gridItem0').should('not.exist')
  })

  it('shrinks and expands a graph width and height', () => {
    aliasWidthHeight()
    cy.get('#gridItem0').within(() => {
      cy.contains('Graph 0')
      cy.get('[data-test=collapseAll]').click({ force: true })
    })
    checkWidthHeight('be.lt', 0.5, 'be.lt', 0.5)
    cy.get('#gridItem0').within(() => {
      cy.get('[data-test=expandAll]').click({ force: true })
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('shrinks and expands a graph width', () => {
    aliasWidthHeight()
    cy.get('#gridItem0').within(() => {
      cy.get('[data-test=expandWidth]').click({ force: true })
    })
    checkWidthHeight('eq', 1, 'eq', 1)
    cy.get('#gridItem0').within(() => {
      cy.contains('Graph 0')
      cy.get('[data-test=collapseWidth]').click({ force: true })
    })
    checkWidthHeight('be.lt', 0.5, 'eq', 1)
    cy.get('#gridItem0').within(() => {
      cy.get('[data-test=expandWidth]').click({ force: true })
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('shrinks and expands a graph height', () => {
    aliasWidthHeight()
    cy.get('#gridItem0').within(() => {
      cy.contains('Graph 0')
      cy.get('[data-test=collapseVertical]').click({ force: true })
    })
    checkWidthHeight('eq', 1, 'be.lt', 0.5)
    cy.get('#gridItem0').within(() => {
      cy.get('[data-test=expandVertical]').click({ force: true })
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('minimizes a graph', () => {
    cy.get('#gridItem0').within(() => {
      cy.get('#chart').should('be.visible')
      cy.get('[data-test=minimizeScreenIcon]').click({ force: true })
      cy.wait(1000) // Wait for graphing to occur
      cy.get('[data-test=maximizeScreenIcon]').click({ force: true })
      cy.get('#chart').should('be.visible')
    })
  })
})
