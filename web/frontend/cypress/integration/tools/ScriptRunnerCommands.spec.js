describe('ScriptRunner', () => {
  it('prompts for hazardous commands', () => {
    cy.visit('/script-runner')
    cy.focused().type('cmd("INST CLEAR")')
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog', { timeout: 30000 }).within(() => {
      cy.contains('No').click()
    })
    cy.get('[data-test=state]').should('have.value', 'paused')
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog').within(() => {
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
    cy.focused().type('value = ask("Enter luggage password:")\n' + 'puts value')
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog', { timeout: 30000 }).within(() => {
      cy.get('input').type('12345')
      cy.contains('Ok').click()
    })
    cy.get('[data-test=state]').should('have.value', 'stopped')
    cy.get('[data-test=output-messages]').contains('12345')
  })
  it('opens a dialog with buttons for prompt_message_box, prompt_vertical_message_box', () => {
    cy.visit('/script-runner')
    cy.focused().type(
      'value = prompt_message_box("Select", ["ONE", "TWO", "THREE"])\n' +
        'puts value\n' +
        'value = prompt_vertical_message_box("Select", ["FOUR", "FIVE", "SIX"])\n' +
        'puts value'
    )
    cy.get('[data-test=start-go-button]').click()
    cy.get('.v-dialog', { timeout: 30000 }).within(() => {
      cy.contains('TWO').click()
    })
    cy.get('.v-dialog').within(() => {
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
    cy.get('.v-dialog', { timeout: 30000 }).within(() => {
      cy.get('[data-test=select]').click({ force: true })
    })
    // This check has to be outside the .v-dialog since it's a floating menu
    cy.get('.v-list-item__title').contains('def456').click()
    cy.contains('Ok').click()

    cy.get('[data-test=state]').should('have.value', 'stopped')
    cy.get('[data-test=output-messages]').contains('def456')
  })
})
