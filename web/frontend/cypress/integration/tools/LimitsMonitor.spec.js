import { format } from 'date-fns'

describe('LimitsMonitor', () => {
  //
  // Test the Limits Tab
  //
  it('temporarily hides items', function () {
    cy.visit('/limits-monitor')
    cy.hideNav()
    cy.get('[data-test=limits-row]:contains("TEMP2")', {
      timeout: 30000,
    }).should('have.length', 2)

    // Hide both TEMP2s
    cy.contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(2) // hide item
      .click()
    cy.contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(2) // hide item
      .click()
    cy.get('TEMP2').should('not.be.visible')

    // Now wait for them to come back
    cy.get('[data-test=limits-row]:contains("TEMP2")', {
      timeout: 30000,
    }).should('have.length', 2)
  })

  it('ignores items', function () {
    cy.visit('/limits-monitor')
    cy.hideNav()
    cy.get('[data-test=limits-row]:contains("TEMP2")', {
      timeout: 30000,
    }).should('have.length', 2)

    // Ignore both TEMP2s
    cy.contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(1) // ignore item
      .click()
    cy.contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(1) // ignore item
      .click()
    cy.get('TEMP2').should('not.be.visible')
    cy.get('[data-test=overall-state]')
      .invoke('val')
      .should('include', 'Some items ignored')

    // Check the menu
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Show Ignored').click()
    cy.get('.v-dialog').within(() => {
      // Find the items and delete them to restore them
      cy.contains('INST HEALTH_STATUS TEMP2').find('button').click()
      cy.contains('INST2 HEALTH_STATUS TEMP2').find('button').click()
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')
    // Now we find both items again
    cy.get('[data-test=limits-row]:contains("TEMP2")', {
      timeout: 30000,
    }).should('have.length', 2)
  })

  it('ignores entire packets', function () {
    cy.visit('/limits-monitor')
    cy.hideNav()
    cy.get('[data-test=overall-state]').invoke('val').should('eq', 'RED')

    // The INST1 and INST2 targets both have VALUE2 & VALUE4 as red
    cy.get('[data-test=limits-row]:contains("VALUE2")').should('have.length', 2)
    cy.get('[data-test=limits-row]:contains("VALUE4")').should('have.length', 2)
    // Ignore the entire VALUE2 packet
    cy.contains('VALUE2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(0) // Ignore packet
      .click()
    cy.get('[data-test=limits-row]:contains("VALUE2")').should('have.length', 1)
    cy.get('[data-test=limits-row]:contains("VALUE4")').should('have.length', 1)
    cy.get('[data-test=overall-state]')
      .invoke('val')
      .should('include', 'Some items ignored')

    // Check the menu
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Show Ignored').click()
    cy.get('.v-dialog').within(() => {
      // Find the existing item and delete it
      cy.contains(/INST\d? PARAMS/)
        .find('button')
        .click()
      cy.contains(/INST\d? PARAMS/).should('not.exist')
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')
    // Now we find both items again
    cy.get('[data-test=limits-row]:contains("VALUE2")').should('have.length', 2)
    cy.get('[data-test=limits-row]:contains("VALUE4")').should('have.length', 2)
  })

  it('ignores items which changes overall state', function () {
    cy.visit('/limits-monitor')
    cy.hideNav()
    cy.get('[data-test=overall-state]').invoke('val').should('eq', 'RED')

    // Ignore the entire VALUE2 packet
    cy.contains('VALUE2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(0) // Ignore packet
      .click()
    cy.contains('VALUE2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(0) // Ignore packet
      .click()
    cy.contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(0) // Ignore packet
      .click()
    cy.contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(0) // Ignore packet
      .click()

    // We should just be left with SLRPNL1 items which are always YELLOW
    cy.get('[data-test=limits-row]:contains("SLRPNL1")').should(
      'have.length',
      2
    )
    cy.get('[data-test=overall-state]')
      .invoke('val')
      .should('eq', 'YELLOW (Some items ignored)')

    cy.contains('SLRPNL1')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(1) // Ignore item
      .click()
    cy.contains('SLRPNL1')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(1) // Ignore item
      .click()

    // With everything ignored we go GREEN!
    cy.get('[data-test=limits-row]').should('have.length', 0)
    cy.get('[data-test=overall-state]')
      .invoke('val')
      .should('eq', 'GREEN (Some items ignored)')

    // Check the menu
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Show Ignored').click()
    cy.get('.v-dialog').within(() => {
      // Verify the ignored items
      cy.contains('INST HEALTH_STATUS')
      cy.contains('INST2 HEALTH_STATUS')
      cy.contains('INST PARAMS')
      cy.contains('INST2 PARAMS')
      cy.contains('INST MECH SLRPNL1')
      cy.contains('INST2 MECH SLRPNL1')
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')
  })

  //
  // Test the log tab
  //
  it('displays the limits log', () => {
    cy.visit('/limits-monitor')
    cy.hideNav()
    cy.get('.v-tab').contains('Log').click()
    // Just verify we see dates and the various red, yellow, green states
    cy.contains(format(new Date(), 'yyyy-MM-dd'))
    cy.contains('RED')
    cy.contains('YELLOW')
    cy.contains('GREEN')
  })

  it('stops posting to the api after closing', () => {
    // Override the fail handler to catch the expected fail
    Cypress.on('fail', (error) => {
      // Expect a No request error message once the API requests stop
      expect(error.message).to.include('No request ever occurred.')
      return false
    })
    cy.visit('/limits-monitor')
    cy.hideNav()
    cy.contains('INST')
    cy.visit('/command-sender')
    cy.contains('Command Sender')
    cy.wait(1000) // Allow the initial Command Sender APIs to happen
    cy.server()
    cy.route('POST', '/api').as('api')
    cy.wait('@api', {
      requestTimeout: 1000,
    }).then((xhr) => {
      // If an xhr request is made this will fail the test which we want
      assert.isNull(xhr.response.body)
    })
  })
})
