describe('ScriptRunner Commands', () => {
  it('downloads the log messages', () => {
    cy.visit('/script-runner')
    cy.focused().type('puts "This is a test"')
    cy.get('[data-test=start-go-button]').click()
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'stopped'
    )
    cy.get('[data-test=output-messages]').contains('Script completed')
    cy.get('[data-test=download-log]').click()
    // TODO: Not sure how to verify this download takes place
  })

  it('prompts for hazardous commands', () => {
    cy.visit('/script-runner')
    cy.focused().type('cmd("INST CLEAR")')
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('No').click()
    })
    cy.get('[data-test=state]').should('have.value', 'paused')
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Yes').click()
    })
    cy.get('[data-test=state]').should('have.value', 'stopped')
    cy.get('[data-test=output-messages]').contains('Script completed')
  })

  it('does not hazardous prompt for cmd_no_hazardous_check, cmd_no_checks', () => {
    cy.visit('/script-runner')
    cy.focused().type(
      'cmd_no_hazardous_check("INST CLEAR")\ncmd_no_checks("INST CLEAR")'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'stopped'
    )
    cy.get('[data-test=output-messages]').contains('Script completed')
  })

  it('errors for out of range command parameters', () => {
    cy.visit('/script-runner')
    cy.focused().type('cmd("INST COLLECT with DURATION 11, TYPE \'NORMAL\'")')
    cy.get('[data-test=start-go-button]').click()
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'error'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('[data-test=output-messages]').contains('Script completed')
    cy.get('[data-test=output-messages]').contains('11 not in valid range')
  })

  it('does not out of range error for cmd_no_range_check, cmd_no_checks', () => {
    cy.visit('/script-runner')
    cy.focused().type(
      'cmd_no_range_check("INST COLLECT with DURATION 11, TYPE \'NORMAL\'")\n' +
        'cmd_no_checks("INST COLLECT with DURATION 11, TYPE \'NORMAL\'")'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('[data-test=state]', { timeout: 30000 }).should(
      'have.value',
      'stopped'
    )
    cy.get('[data-test=output-messages]').contains('Script completed')
  })

  it('opens a dialog for ask and returns the value', () => {
    cy.visit('/script-runner')
    cy.focused().type(
      'value = ask("Enter password:")\n' +
        'puts value\n' +
        'value = ask("Optionally enter password:", true)\n' +
        'puts "blank:#{{}value.empty?}"\n' +
        'value = ask("Enter default password:", 67890)\n' +
        'puts value\n' +
        'value = ask("Enter SECRET password:", false, true)\n' +
        'wait\n' +
        'puts value'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('Cancel').click()
    })
    cy.get('[data-test=output-messages]').contains('User input: Cancel')
    cy.get('[data-test=state]').should('have.value', 'paused')

    // Clicking go re-launches the dialog
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible').within(() => {
      // Since there was no default the Ok button is disabled
      cy.contains('Ok').should('be.disabled')
      cy.get('input').type('12345')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=output-messages]').contains('12345')
    cy.get('.v-dialog:visible').within(() => {
      // Since nothing is required the Ok button is enabled
      cy.contains('Ok').should('be.enabled')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=output-messages]').contains('blank:true')
    cy.get('.v-dialog:visible').within(() => {
      // Verify the default value
      cy.get('input').should('have.value', '67890')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=output-messages]').contains('67890')
    cy.get('.v-dialog:visible').within(() => {
      cy.get('input').type('abc123!')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=state]').should('have.value', 'waiting')
    // Verify we're not outputting the secret password on input
    cy.get('[data-test=output-messages]').should('not.contain', 'abc123!')
    // Once we restart we should see it since we print it
    cy.get('[data-test=start-go-button]').click()
    cy.get('[data-test=output-messages]').contains('abc123!')
  })

  it('opens a dialog with buttons for prompt_message_box, prompt_vertical_message_box', () => {
    cy.visit('/script-runner')
    cy.focused().type(
      'value = prompt_message_box("Select", ["ONE", "TWO", "THREE"])\n' +
        'puts value\n' +
        'value = prompt_vertical_message_box("Select", ["FOUR", "FIVE", "SIX"])\n' +
        'puts value\n'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('Cancel').click()
    })
    cy.get('[data-test=output-messages]').contains('User input: Cancel')
    cy.get('[data-test=state]').should('have.value', 'paused')

    // Clicking Go re-launches the dialog
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('TWO').click()
    })
    cy.get('.v-dialog:visible').should('not.exist')

    cy.get('.v-dialog:visible').within(() => {
      cy.contains('FOUR').click()
    })
    cy.get('[data-test=state]').should('have.value', 'stopped')
    cy.get('[data-test=output-messages]').contains('TWO')
    cy.get('[data-test=output-messages]').contains('FOUR')
  })

  it('opens a dialog with dropdowns for prompt_combo_box', () => {
    cy.visit('/script-runner')
    cy.focused().type(
      'value = prompt_combo_box("Select", ["abc123", "def456"])\n' +
        'puts value\n'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('Cancel').click()
    })
    cy.get('[data-test=output-messages]').contains('User input: Cancel')
    cy.get('[data-test=state]').should('have.value', 'paused')

    // Clicking go re-launches the dialog
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.get('[data-test=select]').click({ force: true })
    })
    cy.get('[data-test=state]').should('have.value', 'paused')

    // This check has to be outside the .v-dialog since it's a floating menu
    cy.get('.v-list-item__title').contains('def456').click()
    cy.contains('Ok').click()

    cy.get('[data-test=state]').should('have.value', 'stopped')
    cy.get('[data-test=output-messages]').contains('def456')
  })

  it('opens a dialog for prompt_dialog_box', () => {
    cy.visit('/script-runner')
    // Default choices for prompt_dialog_box is Yes and No
    cy.focused().type(
      'value = prompt_dialog_box("This is a Title!")\n' +
        'puts value\n' +
        'value = prompt_dialog_box("Are you tired?", "Extra message")\n' +
        'puts value\n' +
        'value = prompt_dialog_box("Choose Your Adventure", "Sun vs Moon", ["Day", "Night"])\n' +
        'puts value\n'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('This is a Title!')
      cy.contains('Yes').click()
    })
    cy.get('[data-test=output-messages]').contains('true') // Yes => true
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Are you tired?')
      cy.contains('Extra message')
      cy.contains('No').click()
    })
    cy.get('[data-test=output-messages]').contains('false') // No => false
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Day').click()
    })
    cy.get('[data-test=output-messages]').contains('Day')
  })

  it('opens a dialog for prompt_to_continue', () => {
    cy.visit('/script-runner')
    // Default choices for prompt_to_continue is Ok and Cancel
    cy.focused().type(
      'value = prompt_to_continue("Continue?")\n' + 'puts value\n'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible', { timeout: 30000 }).within(() => {
      cy.contains('Continue?')
      cy.contains('Cancel').click()
    })
    cy.get('[data-test=output-messages]').contains('User input: Cancel')
    cy.get('[data-test=state]').should('have.value', 'paused')
    // Clicking Go re-executes the prompt_to_continue
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.contains('Continue?')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=output-messages]').contains('Ok')
  })
})
