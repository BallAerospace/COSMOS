describe('Toggle Theme', () => {
  it('toggles from dark to light', () => {
    cy.visit('/')
    cy.get('#app').should('have.class', 'theme--dark')
    cy.contains('Toggle Theme').click({ force: true })
    cy.get('#app').should('have.class', 'theme--light')
  })
})

describe('Toggle Navigation', () => {
  it('shows and hides the navigation pane', () => {
    cy.visit('/')
    cy.get('.v-navigation-drawer').should('be.visible')
    cy.get('.v-app-bar__nav-icon').click({ force: true })
    cy.get('.v-navigation-drawer').should('be.hidden')
    cy.get('.v-app-bar__nav-icon').click({ force: true })
    cy.get('.v-navigation-drawer').should('be.visible')
  })
})
