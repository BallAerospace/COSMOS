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

import { format } from 'date-fns'

describe('LimitsMonitor', () => {
  //
  // Test the Limits Tab
  //
  it('temporarily hides items', function () {
    cy.visit('/tools/limitsmonitor')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=limits-row]:contains("TEMP2")', {
      timeout: 60000,
    }).should('have.length', 2)
    cy.wait(500)

    // Hide both TEMP2s
    cy.get('[data-test=label]')
      .contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(2) // hide item
      .click()
    cy.get('[data-test=label]')
      .contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(2) // hide item
      .click()
    cy.get('TEMP2').should('not.exist')

    // Now wait for them to come back
    cy.get('[data-test=limits-row]:contains("TEMP2")', {
      timeout: 30000,
    }).should('have.length', 2)
  })

  it('ignores items', function () {
    cy.visit('/tools/limitsmonitor')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=limits-row]:contains("TEMP2")', {
      timeout: 60000,
    }).should('have.length', 2)
    cy.wait(500)

    // Ignore both TEMP2s
    cy.get('[data-test=label]')
      .contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(1) // ignore item
      .click()
    cy.get('[data-test=label]')
      .contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(1) // ignore item
      .click()
    cy.get('TEMP2').should('not.exist')
    cy.get('[data-test=overall-state]')
      .invoke('val')
      .should('include', 'Some items ignored')

    // Check the menu
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Show Ignored').click()
    cy.get('.v-dialog:visible').within(() => {
      // Find the items and delete them to restore them
      cy.contains('INST HEALTH_STATUS TEMP2').find('button').click()
      cy.contains('INST2 HEALTH_STATUS TEMP2').find('button').click()
      cy.contains('Ok').click()
    })
    // Now we find both items again
    cy.get('[data-test=limits-row]:contains("TEMP2")', {
      timeout: 30000,
    }).should('have.length', 2)
  })

  it('ignores entire packets', function () {
    cy.visit('/tools/limitsmonitor')
    cy.hideNav()
    cy.wait(1000)
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
    cy.get('.v-dialog:visible').within(() => {
      // Find the existing item and delete it
      cy.contains(/INST\d? PARAMS/)
        .find('button')
        .click()
      cy.contains(/INST\d? PARAMS/).should('not.exist')
      cy.contains('Ok').click()
    })
    // Now we find both items again
    cy.get('[data-test=limits-row]:contains("VALUE2")').should('have.length', 2)
    cy.get('[data-test=limits-row]:contains("VALUE4")').should('have.length', 2)
  })

  it.skip('ignores items which changes overall state', function () {
    // TODO: possibly remove this test. It relies on a target not entering red status, and therefore it's unreliable with the current demo code
    cy.visit('/tools/limitsmonitor')
    cy.hideNav()
    cy.wait(1000)
    cy.get('[data-test=overall-state]').invoke('val').should('eq', 'RED')
    cy.wait(500)

    // Ignore the entire VALUE2 packet
    cy.get('[data-test=label]')
      .contains('VALUE2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(0) // Ignore packet
      .click()
    cy.get('[data-test=label]')
      .contains('VALUE2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(0) // Ignore packet
      .click()
    cy.get('[data-test=label]')
      .contains('TEMP2')
      .parentsUntil('[data-test=limits-row]')
      .parent()
      .children()
      .eq(1)
      .find('button')
      .eq(0) // Ignore packet
      .click()
    cy.get('[data-test=label]')
      .contains('TEMP2')
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
    cy.get('.v-dialog:visible').within(() => {
      // Verify the ignored items
      cy.contains('INST HEALTH_STATUS')
      cy.contains('INST2 HEALTH_STATUS')
      cy.contains('INST PARAMS')
      cy.contains('INST2 PARAMS')
      cy.contains('INST MECH SLRPNL1')
      cy.contains('INST2 MECH SLRPNL1')
      cy.contains('Ok').click()
    })
  })

  //
  // Test the log tab
  //
  it('displays the limits log', () => {
    cy.visit('/tools/limitsmonitor')
    cy.hideNav()
    cy.wait(1000)
    cy.get('.v-tab').contains('Log').click({ force: true })
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
    cy.visit('/tools/limitsmonitor')
    cy.hideNav()
    cy.wait(1000)
    cy.contains('INST')
    cy.visit('/tools/cmdsender')
    cy.contains('Command Sender')
    cy.wait(1000) // Allow the initial Command Sender APIs to happen
    cy.server()
    cy.route('POST', '/cosmos-api/api').as('api')
    cy.wait('@api', {
      requestTimeout: 1000,
    }).then((xhr) => {
      // If an xhr request is made this will fail the test which we want
      assert.isNull(xhr.response.body)
    })
  })
})
