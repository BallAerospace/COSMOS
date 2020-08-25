describe('CmdTlmServer Status', () => {
  it('displays the current limits set', () => {
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.get('.v-tab')
      .contains('Status')
      .click()
    cy.get('[data-test=limits-set', { timeout: 10000 }).contains('DEFAULT')
  })
})
