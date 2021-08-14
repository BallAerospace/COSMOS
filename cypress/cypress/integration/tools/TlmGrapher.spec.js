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

describe('TlmGrapher', () => {
  // Creates an alias to the graph width and height
  function aliasWidthHeight() {
    cy.get('#tlmGrapherGraph1').invoke('width').as('width')
    cy.get('#tlmGrapherGraph1').invoke('height').as('height')
  }
  // Compares the current graph width and height to the aliased values
  function checkWidthHeight(
    widthComparison,
    widthMultiplier = 1,
    heightComparison,
    heightMultiplier = 1
  ) {
    cy.get('@width').then((value) => {
      cy.get('#tlmGrapherGraph1')
        .invoke('width')
        .should(widthComparison, value * widthMultiplier)
    })
    cy.get('@height').then((value) => {
      cy.get('#tlmGrapherGraph1')
        .invoke('height')
        .should(heightComparison, value * heightMultiplier)
    })
  }

  beforeEach(() => {
    Cypress.on('uncaught:exception', (err, runnable) => false)
  })

  it('adds items to a graph, starts, pauses, resumes and stops', () => {
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click({ force: true })
    cy.get('#tlmGrapherGraph1').contains('TEMP1')
    cy.wait(2000) // Wait for graphing to occur
    // Add another item while it is already graphing
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click({ force: true })
    cy.get('#tlmGrapherGraph1').contains('TEMP2')
    cy.wait(3000) // Wait for graphing to occur
    cy.get('[data-test=grapher-controls]').click({ force: true })
    cy.get('[data-test=grapher-controls]')
      .contains('Pause')
      .click({ force: true })
    cy.contains('Description').click({ force: true })
    cy.wait(1000)
    cy.get('[data-test=grapher-controls]')
      .contains('Resume')
      .click({ force: true })
    cy.wait(2000)
    cy.get('[data-test=grapher-controls]')
      .contains('Stop')
      .click({ force: true })
    cy.wait(1000) // Small wait to visually see it stopped
  })

  it('edits a graph title', () => {
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    cy.contains('Graph 1')
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click({ force: true })
    cy.wait(2000) // Wait for graphing to occur
    cy.get('.v-toolbar').contains('Graph').click({ force: true })
    cy.contains('Edit Graph').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.get('[data-test=edit-title]').clear().type('My New Title')
      cy.contains('INST HEALTH_STATUS TEMP1')
        .parent()
        .within(() => {
          cy.get('button').click({ force: true })
        })
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
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click({ force: true })
    cy.get('.v-toolbar').contains('Graph').click({ force: true })
    cy.contains('Add Graph').click({ force: true })
    cy.get('#tlmGrapherGraph2')
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click({ force: true })
    // Ensure TEMP2 got added to the correct graph
    cy.get('#tlmGrapherGraph2').within(() => {
      cy.contains('Graph 2')
      cy.contains('TEMP2')
      cy.should('not.contain', 'TEMP1')
    })
    cy.get('#tlmGrapherGraph1').within(() => {
      cy.contains('Graph 1')
      cy.contains('TEMP1')
      cy.should('not.contain', 'TEMP2')
      // Close Graph 1
      cy.get('.mdi-close-box').click({ force: true })
    })
    cy.get('#tlmGrapherGraph1').should('not.exist')
  })

  it('saves and loads the configuration', () => {
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click({ force: true })
    cy.get('.v-toolbar').contains('Graph').click({ force: true })
    cy.contains('Add Graph').click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP3')
    cy.contains('Add Item').click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP4')
    cy.contains('Add Item').click({ force: true })
    let config = 'spec' + Math.floor(Math.random() * 10000)
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Save Configuration').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.get('input').clear().type(config)
      cy.contains('Ok').click({ force: true })
    })
    cy.get('.v-dialog:visible').should('not.exist')
    // Verify we get a warning if trying to save over existing
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Save Configuration').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.get('input').clear().type(config)
      cy.contains('Ok').click({ force: true })
      cy.contains("'" + config + "' already exists")
      cy.contains('Cancel').click({ force: true })
    })
    cy.get('.v-dialog:visible').should('not.exist')
    // Totally refresh the page
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Open Configuration').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      // Try to click OK without anything selected
      cy.contains('Ok').click({ force: true })
      cy.contains('Select a configuration')
      cy.contains(config).click({ force: true })
      cy.contains('Ok').click({ force: true })
    })
    // Verify we're back
    cy.contains('Graph 1')
      .parents('.v-card')
      .eq(0)
      .within(() => {
        cy.contains('TEMP1')
        cy.contains('TEMP2')
      })
    cy.contains('Graph 2')
      .parents('.v-card')
      .eq(0)
      .within(() => {
        cy.contains('TEMP3')
        cy.contains('TEMP4')
      })
    // Delete this test configuation
    cy.get('.v-toolbar').contains('File').click({ force: true })
    cy.contains('Open Configuration').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.contains(config)
        .parents('.v-list-item')
        .eq(0)
        .within(() => {
          cy.get('button').click({ force: true })
        })
      cy.contains('Cancel').click({ force: true })
    })
  })

  it('shrinks and expands a graph width and height', () => {
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    aliasWidthHeight()
    cy.get('#tlmGrapherGraph1').within(() => {
      cy.contains('Graph 1')
      cy.get('button')
        .eq(0) // Expand button
        .click({ force: true })
    })
    checkWidthHeight('be.lt', 0.5, 'be.lt', 0.5)
    cy.get('#tlmGrapherGraph1').within(() => {
      cy.get('button').eq(0).click({ force: true })
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('shrinks and expands a graph width', () => {
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    aliasWidthHeight()
    cy.get('#tlmGrapherGraph1').within(() => {
      cy.contains('Graph 1')
      cy.get('button')
        .eq(1) // Width button
        .click({ force: true })
    })
    checkWidthHeight('be.lt', 0.5, 'eq', 1)
    cy.get('#tlmGrapherGraph1').within(() => {
      cy.get('button').eq(1).click({ force: true })
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('shrinks and expands a graph height', () => {
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    aliasWidthHeight()
    cy.get('#tlmGrapherGraph1').within(() => {
      cy.contains('Graph 1')
      cy.get('button')
        .eq(2) // Height button
        .click({ force: true })
    })
    checkWidthHeight('eq', 1, 'be.lt', 0.5)
    cy.get('#tlmGrapherGraph1').within(() => {
      cy.get('button').eq(2).click({ force: true })
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('minimizes a graph', () => {
    cy.visit('/tools/tlmgrapher')
    cy.hideNav()
    cy.get('#tlmGrapherGraph1').within(() => {
      cy.get('#chart').should('be.visible')
      cy.get('button')
        .eq(3) // Minimize
        .click({ force: true })
      cy.get('button').eq(3).click({ force: true })
      cy.get('#chart').should('be.visible')
    })
  })
})
