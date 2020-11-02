describe('CmdTlmServer', () => {
  //
  // Test the File menu
  //
  it('changes the polling rate', function () {
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.contains('td', 'CONNECTED')
    cy.wait(1000) // Let things spin up
    cy.get('[data-test=interfaces-table]')
      .contains('INST_INT')
      .parent()
      .children()
      .eq(7)
      .invoke('text')
      .then((rxBytes1) => {
        cy.wait(1500)
        cy.get('[data-test=interfaces-table]')
          .contains('INST_INT')
          .parent()
          .children()
          .eq(7)
          .invoke('text')
          .then((rxBytes2) => {
            expect(rxBytes2).to.not.eq(rxBytes1)
          })
      })

    cy.contains('TEMP1')
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Options').click()
    cy.get('.v-dialog').within(() => {
      cy.get('input').clear().type('5000')
    })
    cy.get('.v-dialog').type('{esc}')
    cy.wait(1000)

    cy.get('[data-test=interfaces-table]')
      .contains('INST_INT')
      .parent()
      .children()
      .eq(7)
      .invoke('text')
      .then((rxBytes1) => {
        cy.wait(2000)
        cy.get('[data-test=interfaces-table]')
          .contains('INST_INT')
          .parent()
          .children()
          .eq(7)
          .invoke('text')
          .then((rxBytes2) => {
            expect(rxBytes2).to.eq(rxBytes1)
          })

        cy.wait(2500)
        cy.get('[data-test=interfaces-table]')
          .contains('INST_INT')
          .parent()
          .children()
          .eq(7)
          .invoke('text')
          .then((rxBytes3) => {
            expect(rxBytes3).to.not.eq(rxBytes1)
          })
      })
  })

  //
  // Test the basic functionality of the application
  //
  it('stops posting to the api after closing', () => {
    // Override the fail handler to catch the expected fail
    Cypress.on('fail', (error) => {
      // Expect a No request error message once the API requests stop
      expect(error.message).to.include('No request ever occurred.')
      return false
    })
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.contains('Log Messages')
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
