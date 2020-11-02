// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

Cypress.Commands.add('chooseVSelect', (inputLabel, selection) => {
  cy.get('label')
    .contains(new RegExp(`^${inputLabel}$`, 'i'))
    .click({ force: true })

  cy.get('.v-list-item__title')
    .contains(new RegExp(`^${selection}$`, 'i'))
    .click()
})

Cypress.Commands.add(
  'selectTargetPacketItem',
  (target, packet, item = null) => {
    cy.get('[data-test=select-target]').click({ force: true })
    cy.get('.v-list-item__title')
      .contains(new RegExp(`^${target}$`, 'i'))
      .click()
    cy.get('[data-test=select-packet]').click({ force: true })
    cy.get('.v-list-item__title')
      .contains(new RegExp(`^${packet}$`, 'i'))
      .click()
    if (item) {
      cy.get('[data-test=select-item]').click({ force: true })
      cy.get('.v-list-item__title')
        .contains(new RegExp(`^${item}$`, 'i'))
        .click()
    }
  }
)

Cypress.Commands.add('hideNav', () => {
  cy.get('.v-navigation-drawer').then(($drawer) => {
    if (Cypress.dom.isVisible($drawer)) {
      cy.get('.v-app-bar__nav-icon').click({ force: true })
    }
  })
})

Cypress.Commands.add('showNav', () => {
  cy.get('.v-navigation-drawer').then(($drawer) => {
    if (!Cypress.dom.isVisible($drawer)) {
      cy.get('.v-app-bar__nav-icon').click({ force: true })
    }
  })
})
