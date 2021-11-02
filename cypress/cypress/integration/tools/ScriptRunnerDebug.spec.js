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

describe('ScriptRunner Debug', () => {
  beforeEach(() => {
    cy.visit('/tools/scriptrunner')
    cy.hideNav()
    cy.wait(1000)
  })

  afterEach(() => {
    //
  })

  it('runs Ruby Syntax check', () => {
    cy.focused().type('if{enter}end{enter}end{enter}')
    cy.get('.v-toolbar').contains('Script').click({ force: true })
    cy.contains('Ruby Syntax Check').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      // New files automatically open File Save As
      cy.contains('Syntax Check Failed')
      cy.contains("unexpected `end'")
      cy.contains('Ok').click({ force: true })
    })
    cy.get('[data-test=start-button]').click({ force: true })
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'stopped'
    )
    cy.get('[data-test=output-messages]').contains('Exception')
  })

  it('handles fatal exceptions', () => {
    cy.focused().type('if{enter}end{enter}end{enter}')
    cy.get('.v-toolbar').contains('Script').click({ force: true })
    cy.contains('Ruby Syntax Check').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      // New files automatically open File Save As
      cy.contains('Syntax Check Failed')
      cy.contains("unexpected `end'")
      cy.contains('Ok').click({ force: true })
    })
    cy.get('[data-test=start-button]').click({ force: true })
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'stopped'
    )
    cy.get('[data-test=output-messages]').contains('Exception')
  })

  it('keeps a debug command history', () => {
    // Note we have to escape the { in cypress with {{}
    cy.focused().type(
      'x = 12345\nwait\nputs "x:#{{}x}"\nputs "one"\nputs "two"'
    )
    cy.get('[data-test=start-button]').click({ force: true })
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'waiting'
    )
    cy.get('.v-toolbar').contains('Script').click({ force: true })
    cy.contains('Toggle Debug').click({ force: true })
    cy.get('[data-test=debug-text]').should('be.visible')
    cy.get('[data-test=debug-text]').type('x{enter}')
    cy.get('[data-test=output-messages]').contains('12345')
    cy.get('[data-test=debug-text]').type('puts "abc123!"{enter}')
    cy.get('[data-test=output-messages]').contains('abc123!')
    cy.get('[data-test=debug-text]').type('x = 67890{enter}')
    // Test the history
    cy.get('[data-test=debug-text]').type('{uparrow}')
    cy.get('[data-test=debug-text]').should('have.value', 'x = 67890') // gets the last thing we did
    cy.get('[data-test=debug-text]').type('{uparrow}')
    cy.get('[data-test=debug-text]').should('have.value', 'puts "abc123!"')
    cy.get('[data-test=debug-text]').type('{uparrow}')
    cy.get('[data-test=debug-text]').should('have.value', 'x')
    cy.get('[data-test=debug-text]').type('{uparrow}') // wrap
    cy.get('[data-test=debug-text]').should('have.value', 'x = 67890')
    cy.get('[data-test=debug-text]').type('{downarrow}')
    cy.get('[data-test=debug-text]').should('have.value', 'x')
    cy.get('[data-test=debug-text]').type('{downarrow}')
    cy.get('[data-test=debug-text]').should('have.value', 'puts "abc123!"')
    cy.get('[data-test=debug-text]').type('{downarrow}')
    cy.get('[data-test=debug-text]').should('have.value', 'x = 67890')
    cy.get('[data-test=debug-text]').type('{downarrow}') // wrap
    cy.get('[data-test=debug-text]').should('have.value', 'x')
    cy.get('[data-test=debug-text]').type('{esc}') // escape clears the debug
    cy.get('[data-test=debug-text]').should('have.value', '')
    // Step
    cy.get('[data-test=step-button]').click({ force: true })
    cy.get('[data-test=state]').should('have.value', 'paused')
    cy.get('[data-test=step-button]').click({ force: true })
    cy.get('[data-test=state]').should('have.value', 'paused')
    // Go
    cy.get('[data-test=go-button]').click({ force: true })
    cy.get('[data-test=state]').should('have.value', 'stopped')
    // Verify we were able to change the 'x' variable
    cy.get('[data-test=output-messages]').contains('x:67890')
    cy.get('[data-test=output-messages]').contains('Script completed')

    cy.get('.v-toolbar').contains('Script').click({ force: true })
    cy.contains('Toggle Debug').click({ force: true })
    cy.get('[data-test=debug-text]').should('not.exist')
  })

  it('retries failed checks', () => {
    cy.focused().type('check_expression("1 == 2")')
    cy.get('[data-test=start-button]').click({ force: true })
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'error'
    )
    // Check for the initial check message
    cy.get('[data-test=output-messages] td:contains("1 == 2 is FALSE")').should(
      'have.length',
      2
    )
    cy.get('[data-test=pause-retry-button]').click({ force: true }) // Retry
    // Now we should have two error messages
    cy.get('[data-test=output-messages] td:contains("1 == 2 is FALSE")').should(
      'have.length',
      4
    )
    cy.get('[data-test=state]').should('have.value', 'error')
    cy.get('[data-test=go-button]').click({ force: true })
    cy.get('[data-test=output-messages]').contains('Script completed')
  })

  it('does nothing for call stack when not running', () => {
    cy.get('.v-toolbar').contains('Script').click({ force: true })
    cy.contains('Show Call Stack').should('have.attr', 'disabled', 'disabled')
    cy.get('@consoleError').should('not.be.called')
  })

  it('displays the call stack', () => {
    cy.focused().type(
      'def one{enter}two(){enter}end{enter}def two{enter}wait{enter}end{enter}one(){enter}'
    )
    cy.get('[data-test=start-button]').click({ force: true })
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'waiting'
    )
    cy.get('[data-test=pause-retry-button]').click({ force: true })
    cy.get('[data-test=state]').should('have.value', 'paused')

    cy.get('.v-toolbar').contains('Script').click({ force: true })
    cy.contains('Show Call Stack').click({ force: true })
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Call Stack')
      cy.get('.row').eq(0).contains('in `two') // Top of the stack is two()
      cy.get('.row').eq(1).contains('in `one') // then one()
      cy.contains('Ok').click({ force: true })
    })
    cy.get('[data-test=stop-button]').click({ force: true })
    cy.get('[data-test=state]').should('have.value', 'stopped')
  })

  it('displays disconnect icon', () => {
    cy.get('.v-toolbar').contains('Script').click({ force: true })
    cy.contains('Toggle Disconnect').click({ force: true })
    // Specify the icon inside the header since the menu has the same icon!
    cy.get('.v-icon.mdi-connection').should('be.visible')
    cy.get('.v-toolbar').contains('Script').click({ force: true })
    cy.contains('Toggle Disconnect').click({ force: true })
    cy.get('.v-icon.mdi-connection').should('not.be.visible')
  })
})
