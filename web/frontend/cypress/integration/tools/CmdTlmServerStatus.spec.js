describe('CmdTlmServer Status', () => {
  it('changes the limits set', () => {
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.get('.v-tab').contains('Status').click()
    cy.wait(1000)
    cy.chooseVSelect('Limits Set', 'TVAC')
    // TODO: This message doesn't appear to be showing up
    // cy.get('[data-test=log-messages]').contains('Setting Limits Set: TVAC')
    cy.chooseVSelect('Limits Set', 'DEFAULT')
    // TODO: This message doesn't appear to be showing up
    // cy.get('[data-test=log-messages]').contains('Setting Limits Set: DEFAULT')
  })
  it('lists API statistics', () => {
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.get('.v-tab').contains('Status').click()
    cy.contains('API Status')
    // TODO what do we really want to display here
  })
  it('lists background tasks', () => {
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.get('.v-tab').contains('Status').click()
    cy.contains('Background Tasks')
    // TODO: Add background tasks to the demo
  })
})
