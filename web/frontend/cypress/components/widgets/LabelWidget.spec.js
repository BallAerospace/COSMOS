/// <reference types="cypress" />
import { mount } from 'cypress-vue-unit-test'
import LabelWidget from '@/components/widgets/LabelWidget.vue'

describe('LabelWidget', () => {
  it('displays the first parameter value', () => {
    mount(LabelWidget, { propsData: { parameters: ['Simple Label:'] } })
    cy.contains('[data-test=label]', 'Simple Label:')
  })
  it('changes font family', () => {
    mount(LabelWidget, {
      propsData: { parameters: ['Test of a font', 'courier'] }
    })
    cy.contains('[data-test=label]', 'Test of a font')
      .should('have.css', 'font-family')
      .and('contain', 'courier')
  })
  it('change font size', () => {
    mount(LabelWidget, {
      propsData: { parameters: ['Test of a font', null, 30] }
    })
    cy.contains('[data-test=label]', 'Test of a font')
      .should('have.css', 'font-size')
      .and('contain', '30px')
  })
  it('changes font weight', () => {
    mount(LabelWidget, {
      propsData: { parameters: ['Test of a font', null, null, 'bold'] }
    })
    cy.contains('[data-test=label]', 'Test of a font')
      .should('have.attr', 'style')
      .and('contain', 'bold')
  })
  it('changes font style', () => {
    mount(LabelWidget, {
      propsData: { parameters: ['Test of a font', null, null, null, 'italic'] }
    })
    cy.contains('[data-test=label]', 'Test of a font')
      .should('have.attr', 'style')
      .and('contain', 'italic')
  })
  it('changes everything', () => {
    mount(LabelWidget, {
      propsData: {
        parameters: ['Change Everything!!!', 'Arial', 50, 'bold', 'italic']
      }
    })
    cy.contains('[data-test=label]', 'Change Everything!!!')
      .should('have.css', 'font-family')
      .and('contain', 'Arial')
    cy.get('[data-test=label]')
      .should('have.css', 'font-size')
      .and('contain', '50px')
    cy.get('[data-test=label]')
      .should('have.attr', 'style')
      .and('contain', 'bold')
      .and('contain', 'italic')
  })
})
