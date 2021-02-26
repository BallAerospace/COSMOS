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

import utils from './../../utils'
import CommandParameterEditor from '@/tools/CommandSender/CommandParameterEditor.vue'

describe('CommandParameterEditor', () => {
  let options = {}
  beforeEach(() => {
    options = {
      propsData: {
        value: {
          val: '10',
          states: null,
          selected_state: null,
          selected_state_label: '',
          manual_value: null,
        },
      },
    }
  })

  it('creates a simple input without states', () => {
    const wrapper = utils.createWrapper(CommandParameterEditor, options)
    expect(wrapper.find('input').element.value).toBe('10')
  })

  // it('creates state selector with states', () => {
  //   options.propsData.value.states = {
  //     NORMAL: { value: 0 },
  //     SPECIAL: { value: 1, hazardous: true }
  //   }
  //   const wrapper = utils.createWrapper(CommandParameterEditor, options)
  //   console.log(wrapper.html())
  //   console.log(wrapper.find('.v-select__selections > input').element.text())
  //   expect(wrapper.find('input').element.value).toBe('0')
  // })
})
