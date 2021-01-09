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

import utils from './utils'
import AppFooter from '@/AppFooter'
import Vuetify from 'vuetify'

describe('AppFooter', () => {
  it('shows footer tag line', () => {
    const wrapper = utils.createShallowWrapper(AppFooter)
    expect(wrapper.html()).toContain('COSMOS')
  })
  it('toggles the theme', () => {
    let vuetify = new Vuetify({
      mocks: {
        $vuetify: {
          theme: {
            dark: false, // TODO: For some reason starting with true doesn't work
          },
        },
      },
    })
    const wrapper = utils.createShallowWrapper(AppFooter, { vuetify })
    expect(wrapper.vm.$vuetify.theme.dark).toBe(false)
    wrapper.vm.toggleTheme()
    expect(wrapper.vm.$vuetify.theme.dark).toBe(true)
  })
})
