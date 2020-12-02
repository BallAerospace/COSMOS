describe('TlmViewer', () => {
  function showScreen(target, screen) {
    cy.visit('/telemetry-viewer')
    cy.hideNav()
    cy.server()
    cy.route('POST', '/api').as('api')
    cy.chooseVSelect('Select Target', target)
    cy.chooseVSelect('Select Screen', screen)
    cy.contains('Show Screen').click()
    cy.contains(target + ' ' + screen).should('be.visible')
    cy.wait('@api').should((xhr) => {
      expect(xhr.status, 'successful POST').to.equal(200)
    })
    cy.get('.mdi-close-box').click()
    cy.contains(target + ' ' + screen).should('not.exist')
    cy.get('@consoleError').should('not.be.called')
  }

  it('displays INST ADCS', () => {
    showScreen('INST', 'ADCS')
  })
  it('displays INST ARRAY', () => {
    showScreen('INST', 'ARRAY')
  })
  it('displays INST BLOCK', () => {
    showScreen('INST', 'BLOCK')
  })
  it('displays INST COMMANDING', () => {
    showScreen('INST', 'COMMANDING')
  })
  it('displays INST GRAPHS', () => {
    showScreen('INST', 'GRAPHS')
  })
  it('displays INST GROUND', () => {
    showScreen('INST', 'GROUND')
  })
  it('displays INST HS', () => {
    showScreen('INST', 'HS')
  })
  it('displays INST LATEST', () => {
    showScreen('INST', 'LATEST')
  })
  it('displays INST LIMITS', () => {
    showScreen('INST', 'LIMITS')
  })
  it('displays INST OTHER', () => {
    showScreen('INST', 'OTHER')
  })
  it('displays INST PARAMS', () => {
    showScreen('INST', 'PARAMS')
  })
  it('displays INST TABS', () => {
    showScreen('INST', 'TABS')
  })
})
