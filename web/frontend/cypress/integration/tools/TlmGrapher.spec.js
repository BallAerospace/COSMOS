describe('TlmGrapher', () => {
  // Creates an alias to the plot width and height
  function aliasWidthHeight() {
    cy.get('#tlmGrapherPlot1')
      .invoke('width')
      .as('width')
    cy.get('#tlmGrapherPlot1')
      .invoke('height')
      .as('height')
  }
  // Compares the current plot width and height to the aliased values
  function checkWidthHeight(
    widthComparison,
    widthMultiplier = 1,
    heightComparison,
    heightMultiplier = 1
  ) {
    cy.get('@width').then(value => {
      cy.get('#tlmGrapherPlot1')
        .invoke('width')
        .should(widthComparison, value * widthMultiplier)
    })
    cy.get('@height').then(value => {
      cy.get('#tlmGrapherPlot1')
        .invoke('height')
        .should(heightComparison, value * heightMultiplier)
    })
  }

  it('adds items to a graph, starts, pauses, resumes and stops', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.get('#tlmGrapherPlot1').contains('TEMP1')
    cy.get('[data-test=grapher-controls]').click()
    cy.get('[data-test=grapher-controls]')
      .contains('Start')
      .click()
    // Click off the controls to make it hide again
    cy.contains('Description').click()
    cy.wait(2000) // Wait for graphing to occur
    // Add another item while it is already graphing
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.get('#tlmGrapherPlot1').contains('TEMP2')
    cy.wait(3000) // Wait for graphing to occur
    cy.get('[data-test=grapher-controls]').click()
    cy.get('[data-test=grapher-controls]')
      .contains('Pause')
      .click()
    cy.contains('Description').click()
    cy.wait(1000)
    cy.wait(1000)
    cy.get('[data-test=grapher-controls]')
      .contains('Resume')
      .click()
    cy.wait(1000)
    cy.get('[data-test=grapher-controls]')
      .contains('Stop')
      .click()
  })

  it('adds multiple plots', () => {
    cy.visit('/telemetry-grapher')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.get('.v-toolbar')
      .contains('Plot')
      .click()
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
      cy.get('button')
        .eq(0)
        .click()
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
      cy.get('button')
        .eq(1)
        .click()
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
      cy.get('button')
        .eq(2)
        .click()
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
      cy.get('button')
        .eq(3)
        .click()
      cy.get('#chart').should('be.visible')
    })
  })
})
