/// <reference types="cypress" />
import { mount, mountCallback } from 'cypress-vue-unit-test'
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
      expect(Cypress.vue.$store.state.tlmViewerItems[0]).to.eql({
        target: 'TGT',
        packet: 'PKT',
        item: 'ITEM',
        type: 'RAW',
      })
      Cypress.vue.$store.commit('tlmViewerUpdateValues', [['hello'], []])
    })
    cy.get('[data-test=array-widget]').should('have.value', 'hello')
  })
})
