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

/// <reference types="cypress" />
import { mount } from 'cypress-vue-unit-test'
import ArrayWidget from '@/components/widgets/ArrayWidget.vue'
import store from '../../../src/store'
import Vuex from 'vuex'

describe('ArrayWidget', () => {
  it('displays non array values', () => {
    mount(ArrayWidget, {
      propsData: { value: 'test', limitsState: 'RED' },
    })
    cy.get('[data-test=array-widget]').should('have.value', 'test')
  })
  it('displays array values with spaces', () => {
    mount(ArrayWidget, {
      propsData: { value: ['test', 'two'], limitsState: 'RED' },
    })
    cy.get('[data-test=array-widget]').should('have.value', 'test two')
  })
  it('inserts a newline every 4th value', () => {
    mount(ArrayWidget, {
      propsData: {
        value: ['one', 'two', 'three', 'four', 'five'],
        limitsState: 'RED',
      },
    })
    cy.get('[data-test=array-widget]').should(
      'have.value',
      'one two three four\nfive'
    )
  })
  it('takes a width parameter', () => {
    mount(ArrayWidget, {
      propsData: {
        value: ['test'],
        limitsState: 'RED',
        parameters: ['TGT', 'PKT', 'ITEM', 200],
      },
    })
    cy.get('.v-input').should('have.css', 'width', '200px')
  })
  it('takes a height parameter', () => {
    mount(ArrayWidget, {
      propsData: {
        value: ['test'],
        limitsState: 'RED',
        parameters: ['TGT', 'PKT', 'ITEM', null, 300],
      },
    })
    cy.get('.v-input').should('have.css', 'height', '300px')
  })
  it('takes a formatter parameter', () => {
    mount(ArrayWidget, {
      propsData: {
        value: [10, 11, 12],
        limitsState: 'RED',
        parameters: ['TGT', 'PKT', 'ITEM', null, null, '0x%X'],
      },
    })
    cy.get('[data-test=array-widget]').should('have.value', '0xA 0xB 0xC')
  })
  it('takes an items per row parameter', () => {
    mount(ArrayWidget, {
      propsData: {
        value: [10, 11, 12, 13],
        limitsState: 'RED',
        parameters: ['TGT', 'PKT', 'ITEM', null, null, null, 2],
      },
    })
    cy.get('[data-test=array-widget]').should('have.value', '10 11\n12 13')
  })
  it('takes a conversion parameter', () => {
    const extensions = {
      plugins: [Vuex],
      mixin: [{ store }],
    }
    mount(ArrayWidget, {
      extensions,
      propsData: {
        parameters: ['TGT', 'PKT', 'ITEM', null, null, null, null, 'RAW'],
      },
    }).then(() => {
      expect(Cypress.vue.$store.state.tlmViewerItems[0]).to.eql(
        'TGT__PKT__ITEM__RAW'
      )
      Cypress.vue.$store.commit('tlmViewerUpdateValues', [['hello', 'GREEN']])
    })
    cy.get('[data-test=array-widget]').should('have.value', 'hello')
  })
})
