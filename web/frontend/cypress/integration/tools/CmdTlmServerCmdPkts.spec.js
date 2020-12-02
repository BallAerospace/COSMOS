describe('CmdTlmServer CmdPackets', () => {
  it('displays the list of command', () => {
    cy.visit('/cmd-tlm-server/cmd-packets')
    cy.hideNav()
    cy.get('[data-test=cmd-packets-table]', { timeout: 10000 })
      .contains('ABORT')
      .parent('tr')
      .within(() => {
        // all searches are automatically rooted to the found tr element
        cy.get('td').eq(0).contains('INST') // either INST or INST2
      })
    cy.get('[data-test=cmd-packets-table]')
      .contains('COLLECT')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST') // either INST or INST2
      })
    cy.get('[data-test=cmd-packets-table]')
      .contains('EXAMPLE')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(1).contains('START')
      })
  })
  it('displays the command count', () => {
    cy.visit('/cmd-tlm-server/cmd-packets')
    cy.hideNav()
    cy.get('[data-test=cmd-packets-table]', { timeout: 10000 })
      .contains('ABORT')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td').eq(2).invoke('text').as('cmdCnt')
      })
    cy.visit('/command-sender/INST/ABORT')
    cy.hideNav()
    cy.contains('Aborts a collect')
    cy.get('button').contains('Send').click()
    cy.visit('/cmd-tlm-server/cmd-packets')
    cy.hideNav()
    cy.get('[data-test=cmd-packets-table]', { timeout: 10000 })
      .contains('ABORT')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td')
          .eq(2)
          .invoke('text')
          .then((cmdCnt2) => {
            cy.get('@cmdCnt').then((value) => {
              expect(parseInt(cmdCnt2)).to.eq(parseInt(value) + 1)
            })
          })
      })
  })

  it('displays a raw command', () => {
    // Send a command to ensure it's there
    cy.visit('/command-sender/INST/ABORT')
    cy.hideNav()
    cy.contains('Aborts a collect')
    cy.get('button').contains('Send').click()
    cy.visit('/cmd-tlm-server/cmd-packets')
    cy.hideNav()
    cy.get('[data-test=cmd-packets-table]', { timeout: 10000 })
      .contains('ABORT')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td').eq(3).click()
      })
    cy.get('.v-dialog').within(() => {
      cy.contains('Raw Command Packet: INST ABORT')
      cy.contains(/Packet Time: \d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/)
      cy.contains(/Received Time: \d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/)
      cy.get('textarea').invoke('val').should('include', 'Address')
      cy.get('textarea').invoke('val').should('include', '00000000:')
    })
    cy.get('.v-dialog').type('{esc}')
    // Make sure we can re-open the raw dialog
    cy.get('[data-test=cmd-packets-table]')
      .contains('ABORT')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td').eq(3).click()
      })
    cy.get('.v-dialog').within(() => {
      cy.contains('Raw Command Packet: INST ABORT')
    })
    cy.get('.v-dialog').type('{esc}')
  })

  it('links to command sender', () => {
    cy.visit('/cmd-tlm-server/cmd-packets', {
      onBeforeLoad(win) {
        cy.stub(win, 'open').as('windowOpen')
      },
    })

    cy.hideNav()
    cy.get('[data-test=cmd-packets-table]', { timeout: 10000 })
      .contains('ABORT')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td').eq(4).click()
      })
    cy.get('@windowOpen').should('be.calledWith', '/command-sender/INST/ABORT')
  })
})
