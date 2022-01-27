/*
# Copyright 2022 Ball Aerospace & Technologies Corp.
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
import { mount } from '@cypress/vue'
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
