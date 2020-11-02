describe('TlmGrapher', () => {
  // Creates an alias to the plot width and height
  function aliasWidthHeight() {
    cy.get('#tlmGrapherPlot1').invoke('width').as('width')
    cy.get('#tlmGrapherPlot1').invoke('height').as('height')
  }
  // Compares the current plot width and height to the aliased values
  function checkWidthHeight(
    widthComparison,
    widthMultiplier = 1,
    heightComparison,
    heightMultiplier = 1
  ) {
    cy.get('@width').then((value) => {
      cy.get('#tlmGrapherPlot1')
        .invoke('width')
        .should(widthComparison, value * widthMultiplier)
    })
    cy.get('@height').then((value) => {
      cy.get('#tlmGrapherPlot1')
        .invoke('height')
        .should(heightComparison, value * heightMultiplier)
    })
  }

  beforeEach(() => {
    Cypress.on('uncaught:exception', (err, runnable) => false)
  })

  it('adds items to a graph, starts, pauses, resumes and stops', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.get('#tlmGrapherPlot1').contains('TEMP1')
    cy.wait(2000) // Wait for graphing to occur
    // Add another item while it is already graphing
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.get('#tlmGrapherPlot1').contains('TEMP2')
    cy.wait(3000) // Wait for graphing to occur
    cy.get('[data-test=grapher-controls]').click()
    cy.get('[data-test=grapher-controls]').contains('Pause').click()
    cy.contains('Description').click()
    cy.wait(1000)
    cy.get('[data-test=grapher-controls]').contains('Resume').click()
    cy.wait(2000)
    cy.get('[data-test=grapher-controls]').contains('Stop').click()
    cy.wait(1000) // Small wait to visually see it stopped
  })

  it('edits a plot', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    cy.contains('Plot 1')
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.wait(2000) // Wait for graphing to occur
    cy.get('.v-toolbar').contains('Plot').click()
    cy.contains('Edit Plot').click()
    cy.get('.v-dialog').within(() => {
      cy.get('input').clear().type('My New Title')
      cy.contains('INST HEALTH_STATUS TEMP1')
        .parent()
        .within(() => {
          cy.get('button').click()
        })
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')
    cy.contains('My New Title')
      .parents('.v-card')
      .eq(0)
      .within(() => {
        cy.contains('TEMP2')
        cy.should('not.contain', 'TEMP1')
      })
  })

  it('adds multiple plots', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.get('.v-toolbar').contains('Plot').click()
    cy.contains('Add Plot').click()
    cy.get('#tlmGrapherPlot2')
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    // Ensure TEMP2 got added to the correct plot
    cy.get('#tlmGrapherPlot2').within(() => {
      cy.contains('Plot 2')
      cy.contains('TEMP2')
      cy.should('not.contain', 'TEMP1')
    })
    cy.get('#tlmGrapherPlot1').within(() => {
      cy.contains('Plot 1')
      cy.contains('TEMP1')
      cy.should('not.contain', 'TEMP2')
      // Close Plot 1
      cy.get('.mdi-close-box').click()
    })
    cy.get('#tlmGrapherPlot1').should('not.exist')
  })

  it('saves and loads the configuration', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.get('.v-toolbar').contains('Plot').click()
    cy.contains('Add Plot').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP3')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP4')
    cy.contains('Add Item').click()
    let config = 'spec' + Math.floor(Math.random() * 10000)
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save Configuration').click()
    cy.get('.v-dialog').within(() => {
      cy.get('input').clear().type(config)
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')
    // Verify we get a warning if trying to save over existing
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save Configuration').click()
    cy.get('.v-dialog').within(() => {
      cy.get('input').clear().type(config)
      cy.contains('Ok').click()
      cy.contains("'" + config + "' already exists")
      cy.contains('Cancel').click()
    })
    cy.get('.v-dialog').should('not.be.visible')
    // Totally refresh the page
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open Configuration').click()
    cy.get('.v-dialog').within(() => {
      // Try to click OK without anything selected
      cy.contains('Ok').click()
      cy.contains('Select a configuration')
      cy.contains(config).click()
      cy.contains('Ok').click()
    })
    // Verify we're back
    cy.contains('Plot 1')
      .parents('.v-card')
      .eq(0)
      .within(() => {
        cy.contains('TEMP1')
        cy.contains('TEMP2')
      })
    cy.contains('Plot 2')
      .parents('.v-card')
      .eq(0)
      .within(() => {
        cy.contains('TEMP3')
        cy.contains('TEMP4')
      })
    // Delete this test configuation
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open Configuration').click()
    cy.get('.v-dialog').within(() => {
      cy.contains(config)
        .parents('.v-list-item')
        .eq(0)
        .within(() => {
          cy.get('button').click()
        })
      cy.contains('Cancel').click()
    })
  })

  it('shrinks and expands a plot width and heigth', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    aliasWidthHeight()
    cy.get('#tlmGrapherPlot1').within(() => {
      cy.contains('Plot 1')
      cy.get('button')
        .eq(0) // Expand button
        .click()
    })
    checkWidthHeight('be.lt', 0.5, 'be.lt', 0.5)
    cy.get('#tlmGrapherPlot1').within(() => {
      cy.get('button').eq(0).click()
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('shrinks and expands a plot width', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    aliasWidthHeight()
    cy.get('#tlmGrapherPlot1').within(() => {
      cy.contains('Plot 1')
      cy.get('button')
        .eq(1) // Width button
        .click()
    })
    checkWidthHeight('be.lt', 0.5, 'eq', 1)
    cy.get('#tlmGrapherPlot1').within(() => {
      cy.get('button').eq(1).click()
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('shrinks and expands a plot height', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    aliasWidthHeight()
    cy.get('#tlmGrapherPlot1').within(() => {
      cy.contains('Plot 1')
      cy.get('button')
        .eq(2) // Height button
        .click()
    })
    checkWidthHeight('eq', 1, 'be.lt', 0.5)
    cy.get('#tlmGrapherPlot1').within(() => {
      cy.get('button').eq(2).click()
    })
    checkWidthHeight('eq', 1, 'eq', 1)
  })

  it('minimizes a plot', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    cy.get('#tlmGrapherPlot1').within(() => {
      cy.get('#chart').should('be.visible')
      cy.get('button')
        .eq(3) // Minimize
        .click()
      cy.get('#chart').should('not.be.visible')
      cy.get('button').eq(3).click()
      cy.get('#chart').should('be.visible')
    })
  })
})
