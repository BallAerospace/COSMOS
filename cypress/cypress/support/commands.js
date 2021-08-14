/*
# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
*/

// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

Cypress.Commands.add('chooseVSelect', (inputLabel, selection, options = {}) => {
  cy.get('label')
    .contains(new RegExp(`^${inputLabel}$`, 'i'))
    .click({ force: true })

  const selectionExpression = options.fuzzy ? selection : `^${selection}$`
  const list = cy.get(options.selectionElement || '.v-list-item__title')
  let el
  if (options.index) {
    el = list.eq(options.index)
    el.contains(new RegExp(selectionExpression, 'i'))
  } else {
    el = list.contains(new RegExp(selectionExpression, 'i'))
  }
  el.click({ force: true })
})

Cypress.Commands.add(
  'selectTargetPacketItem',
  (target, packet = null, item = null) => {
    cy.get('[data-test=select-target]').click({ force: true })
    cy.contains('.v-list-item__title', new RegExp(`^${target}$`, 'i')).click({
      force: true,
    })
    if (packet) {
      cy.get('[data-test=select-packet]').click({ force: true })
      cy.contains('.v-list-item__title', new RegExp(`^${packet}$`, 'i')).click({
        force: true,
      })
      if (item) {
        cy.get('[data-test=select-item]').click({ force: true })
        cy.contains('.v-list-item__title', new RegExp(`^${item}$`, 'i')).click({
          force: true,
        })
      }
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
