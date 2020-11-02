/// <reference types="cypress" />
import { mount } from 'cypress-vue-unit-test'
import ValueWidget from '@/components/widgets/ValueWidget.vue'

describe('ValueWidget', () => {
  function mountCheckColor(color, cssClass) {
    mount(ValueWidget, {
      propsData: {
        value: 100,
        limitsState: color,
      },
    })
    cy.get('.v-input').should('have.class', cssClass)
  }

  it('sets css class according to limitsState', () => {
    mountCheckColor('GREEN', 'cosmos-green')
    mountCheckColor('GREEN_HIGH', 'cosmos-green')
    mountCheckColor('GREEN_LOW', 'cosmos-green')
    mountCheckColor('YELLOW', 'cosmos-yellow')
    mountCheckColor('YELLOW_HIGH', 'cosmos-yellow')
    mountCheckColor('YELLOW_LOW', 'cosmos-yellow')
    mountCheckColor('RED', 'cosmos-red')
    mountCheckColor('RED_HIGH', 'cosmos-red')
    mountCheckColor('RED_LOW', 'cosmos-red')
    mountCheckColor('BLUE', 'cosmos-blue')
    mountCheckColor('STALE', 'cosmos-purple')
    mountCheckColor('', 'cosmos-white')
  })
})
