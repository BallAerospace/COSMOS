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

describe('ScriptRunner Commands', () => {
  beforeEach(() => {
    cy.visit('/tools/scriptrunner')
    cy.hideNav()
    cy.wait(1000)
  })

  it('downloads the log messages', () => {
    cy.focused().type('puts "This is a test"')
    // Force click because we scroll down and can't see the button
    cy.get('[data-test=start-button]').click({force: true})
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'stopped'
    )
    cy.get('[data-test=output-messages]').contains('Script completed')
    cy.get('[data-test=download-log]').click()
    // TODO: Not sure how to verify this download takes place
  })

  it('prompts for hazardous commands', () => {
    cy.focused().type('cmd("INST CLEAR")')
    // Force click because we scroll down and can't see the button
    cy.get('[data-test=start-button]').click({force: true})
    cy.get('.v-dialog', { timeout: 30000 }).should('be.visible').within(() => {
      cy.wait(500)
      cy.contains('Hazardous Command')
      cy.contains('No').click()
    })
    cy.get('[data-test=state]').should('have.value', 'paused')
    cy.get('[data-test=go-button]').click().wait(1000)
    cy.get('.v-dialog').should('be.visible').within(() => {
      cy.wait(500)
      cy.contains('Hazardous Command')
      cy.contains('Yes').click()
    })
    cy.get('[data-test=state]').should('have.value', 'stopped')
    cy.get('[data-test=output-messages]').contains('Script completed')
  })

  it('does not hazardous prompt for cmd_no_hazardous_check, cmd_no_checks', () => {
    cy.focused().type(
      [
        'cmd_no_hazardous_check("INST CLEAR")',
        'cmd_no_checks("INST CLEAR")',
      ].join('\n')
    )
    // Force click because we scroll down and can't see the button
    cy.get('[data-test=start-button]').click({force: true})
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'stopped'
    )
    cy.get('[data-test=output-messages]').contains('Script completed')
  })

  it('errors for out of range command parameters', () => {
    cy.focused().type('cmd("INST COLLECT with DURATION 11, TYPE \'NORMAL\'")')
    // Force click because we scroll down and can't see the button
    cy.get('[data-test=start-button]').click({force: true})
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'error'
    )
    cy.get('[data-test=go-button]').click()
    cy.get('[data-test=output-messages]').contains('Script completed')
    cy.get('[data-test=output-messages]').contains('11 not in valid range')
  })

  it('does not out of range error for cmd_no_range_check, cmd_no_checks', () => {
    cy.focused().type(
      [
        'cmd_no_range_check("INST COLLECT with DURATION 11, TYPE \'NORMAL\'")',
        'cmd_no_checks("INST COLLECT with DURATION 11, TYPE \'NORMAL\'")',
      ].join('\n')
    )
    // Force click because we scroll down and can't see the button
    cy.get('[data-test=start-button]').click({force: true})
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'stopped'
    )
    cy.get('[data-test=output-messages]').contains('Script completed')
  })

  xit('opens a dialog for ask and returns the value', () => {
    cy.focused().type(
      [
        'value = ask("Enter password:")',
        'puts value',
        'value = ask("Optionally enter password:", true)',
        'puts "blank:#{{}value.empty?}"',
        'value = ask("Enter default password:", 67890)',
        'puts value',
        'value = ask("Enter SECRET password:", false, true)',
        'wait',
        'puts value',
      ].join('\n')
    )
    // Force click because we probably scrolled and the Start button is hidden
    cy.get('[data-test=start-button]').click({force: true})
    cy.get('.v-dialog', { timeout: 30000 }).should('be.visible').within(() => {
      cy.wait(1000)
      cy.contains('Cancel').click()
    })
    cy.get('[data-test=output-messages]').contains('User input: Cancel')
    // TODO: Popup immediately re-appears
    // cy.get('[data-test=state]').should('have.value', 'paused')

    // Clicking go re-launches the dialog
    // cy.get('[data-test=go-button]').click()
    cy.get('.v-dialog').should('be.visible').within(() => {
      // Since there was no default the Ok button is disabled
      cy.contains('Ok').should('be.disabled')
      cy.get('input').type('12345')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=output-messages]').contains('12345')
    cy.get('.v-dialog').should('be.visible').within(() => {
      // Since nothing is required the Ok button is enabled
      cy.contains('Ok').should('be.enabled')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=output-messages]').contains('blank:true')
    cy.get('.v-dialog').should('be.visible').within(() => {
      // Verify the default value
      cy.get('input').should('have.value', '67890')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=output-messages]').contains('67890')
    cy.get('.v-dialog').should('be.visible').within(() => {
      cy.get('input').type('abc123!')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=state]').should('have.value', 'waiting')
    // Verify we're not outputting the secret password on input
    cy.get('[data-test=output-messages]').should('not.contain', 'abc123!')
    // Once we restart we should see it since we print it
    cy.get('[data-test=go-button]').click()
    cy.get('[data-test=output-messages]').contains('abc123!')
  })

  xit('opens a dialog with buttons for message_box, vertical_message_box', () => {
    cy.focused().type(
      [
        'value = message_box("Select", "ONE", "TWO", "THREE")',
        'puts value',
        'value = vertical_message_box("Select", "FOUR", "FIVE", "SIX")',
        'puts value',
      ].join('\n')
    )
    cy.get('[data-test=start-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('Cancel').click()
    })
    cy.get('[data-test=output-messages]').contains('User input: Cancel')
    cy.get('[data-test=state]').should('have.value', 'waiting')

    // Clicking Go re-launches the dialog
    cy.get('[data-test=go-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('TWO').click()
    })
    cy.get('.v-dialog').should('be.visible').should('not.exist')

    cy.get('.v-dialog').should('be.visible').within(() => {
      cy.contains('FOUR').click().wait(1000)
    })
    cy.wait(1000)
    cy.get('[data-test=state]').should('have.value', 'stopped')
    cy.get('[data-test=output-messages]').contains('TWO')
    cy.get('[data-test=output-messages]').contains('FOUR')
  })

  xit('opens a dialog with dropdowns for combo_box', () => {
    cy.focused().type(
      [
        'value = combo_box("Select value from combo", "abc123", "def456")',
        'puts value',
      ].join('\n')
    )
    cy.get('[data-test=start-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('Cancel').click()
    })
    cy.get('[data-test=output-messages]').contains('User input: Cancel')
    cy.get('[data-test=state]').should('have.value', 'waiting')

    // Clicking go re-launches the dialog
    cy.get('[data-test=go-button]').click()
    cy.get('.v-dialog').should('be.visible').within(() => {
      cy.get('[data-test=prompt-select]').click()
    })
    cy.get('[data-test=state]').should('have.value', 'waiting')

    // This check has to be outside the .v-dialog since it's a floating menu
    cy.get('.v-list-item__title').contains('def456').click()
    cy.contains('Ok').click().wait(1000)

    cy.get('[data-test=state]').should('have.value', 'stopped')
    cy.get('[data-test=output-messages]').contains('User input: def456')
  })

  xit('opens a dialog for prompt', () => {
    // Default choices for prompt is Ok and Cancel
    cy.focused().type(['value = prompt("Continue?")', 'puts value'].join('\n'))
    cy.get('[data-test=start-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('Continue?')
      cy.contains('Cancel').click()
    })
    cy.get('[data-test=output-messages]').contains('User input: Cancel')
    cy.get('[data-test=state]').should('have.value', 'paused')
    // Clicking Go re-executes the prompt
    cy.get('[data-test=go-button]').click()
    cy.get('.v-dialog').should('be.visible').within(() => {
      cy.contains('Continue?')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=output-messages]').contains('Ok')
  })

  xit('enable environment dialog for prompt and cancel', () => {
    cy.focused().type(
      ['value = ENV["USER"]', 'puts "env user: " + value'].join('\n')
    )
    cy.get('[data-test=env-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.get('[data-test=tmp-environment-key-input]').type('user')
      cy.get('[data-test=tmp-environment-value-input]').type('FOOBAR')
      cy.get('[data-test=add-temp-environment]').click()
      cy.wait(1000)
      cy.get('[data-test=environment-dialog-cancel]').click()
    })
    cy.get('[data-test=output-messages]').should(
      'not.contain',
      'env user: FOOBAR'
    )
  })

  xit('enable environment dialog for prompt and start', () => {
    cy.focused().type(
      ['value = ENV["USER"]', 'puts "env user: " + value'].join('\n')
    )
    cy.get('[data-test=env-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.get('[data-test=tmp-environment-key-input]').type('user')
      cy.get('[data-test=tmp-environment-value-input]').type('FOOBAR')
      cy.get('[data-test=add-temp-environment]').click()
      cy.wait(1000)
      cy.get('[data-test=environment-dialog-start]').click()
    })
    cy.get('[data-test=output-messages]', { timeout: 30000 }).contains(
      'env user: FOOBAR'
    )
    cy.get('[data-test=output-messages]', { timeout: 30000 }).contains(
      'Script completed'
    )
  })
})
