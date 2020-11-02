describe('CmdTlmServer TlmPackets', () => {
  it('displays the list of telemetry', () => {
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.get('.v-tab').contains('Tlm Packets').click()
    cy.get('[data-test=tlm-packets-table]', { timeout: 10000 })
      .contains('HEALTH_STATUS')
      .parent('tr')
      .within(() => {
        // all searches are automatically rooted to the found tr element
        cy.get('td').eq(0).contains('INST') // either INST or INST2
      })
    cy.get('[data-test=tlm-packets-table]')
      .contains('ADCS')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST') // either INST or INST2
      })
    cy.get('[data-test=tlm-packets-table]')
      .contains('UNKNOWN')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(1).contains('UNKNOWN')
      })
  })
  it('displays the packet count', () => {
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.get('.v-tab').contains('Tlm Packets').click()
    cy.get('[data-test=tlm-packets-table]', { timeout: 10000 })
      .contains('HEALTH_STATUS')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td').eq(2).invoke('text').as('tlmCnt')
      })
    cy.wait(1500)
    cy.get('[data-test=tlm-packets-table]')
      .contains('HEALTH_STATUS')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td')
          .eq(2)
          .invoke('text')
          .then((tlmCnt2) => {
            cy.get('@tlmCnt').then((value) => {
              expect(parseInt(tlmCnt2)).to.be.greaterThan(parseInt(value))
            })
          })
      })
  })

  it('displays a raw packet', () => {
    cy.visit('/cmd-tlm-server')
    cy.hideNav()
    cy.get('.v-tab').contains('Tlm Packets').click()
    cy.get('[data-test=tlm-packets-table]', { timeout: 10000 })
      .contains('Target Name')
      .click()
    cy.get('[data-test=tlm-packets-table]')
      .contains('HEALTH_STATUS')
      .parent('tr')
      .within(() => {
        cy.get('td').eq(0).contains('INST')
        cy.get('td').eq(3).click()
      })
    cy.get('.v-dialog').within(() => {
      cy.contains('Raw Telemetry Packet: INST HEALTH_STATUS')
      cy.contains(/Packet Time: \d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/)
      cy.contains(/Received Time: \d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2}/)
      cy.get('textarea').invoke('val').should('include', 'Address')
      cy.get('textarea').invoke('val').should('include', '00000000:')
      cy.get('textarea').invoke('val').as('textArea')
    })
    cy.wait(1500)
    cy.get('@textArea').then((value) => {
      cy.get('.v-dialog textarea')
        .invoke('val')
        .then((textarea) => {
          expect(value).to.not.eq(textarea)
        })
    })
    cy.get('.v-dialog').contains('Pause').click()
    cy.wait(500) // Give it a bit to actually Pause
    // Ensure it has paused the output
    cy.get('.v-dialog').within(() => {
      cy.get('textarea').invoke('val').as('textArea')
    })
    cy.wait(1500)
    cy.get('@textArea').then((value) => {
      cy.get('.v-dialog textarea')
        .invoke('val')
        .then((textarea) => {
          expect(value).to.eq(textarea)
        })
    })
    // Resume the updates
    cy.get('.v-dialog').contains('Resume').click()
    cy.get('.v-dialog').within(() => {
      cy.get('textarea').invoke('val').as('textArea')
    })
    cy.wait(1500)
    cy.get('@textArea').then((value) => {
      cy.get('.v-dialog textarea')
        .invoke('val')
        .then((textarea) => {
          expect(value).to.not.eq(textarea)
        })
    })
  })

  it('links to packet viewer', () => {
    cy.visit('/cmd-tlm-server', {
      onBeforeLoad(win) {
        cy.stub(win, 'open').as('windowOpen')
      },
    })

    cy.hideNav()
    cy.get('.v-tab').contains('Tlm Packets').click()
    cy.get('[data-test=tlm-packets-table]', { timeout: 10000 })
      .contains('Target Name')
      .click()
    cy.get('[data-test=tlm-packets-table]')
      .contains('HEALTH_STATUS')
      .parent('tr')
      .within(() => {
        cy.get('td')
          .eq(0)
          .contains(/^INST$/)
        cy.get('td').eq(4).click()
      })
    cy.get('@windowOpen').should(
      'be.calledWith',
      '/packet-viewer/INST/HEALTH_STATUS'
    )
  })
})
