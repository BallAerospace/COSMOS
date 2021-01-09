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
import AppNav from '@/AppNav'

describe('AppNav', () => {
  let options = {}
  let vuetifyOptions = {}
  beforeEach(() => {
    options = {
      mocks: {
        $route: {
          meta: {
            title: 'title',
            icon: 'icon',
          },
        },
        $router: {
          options: {
            routes: [
              {
                name: 'Route0Name',
                path: '/route0-path',
                meta: {
                  title: 'Route0Title',
                  icon: 'Route0Icon',
                },
              },
              {
                name: 'Route1Name',
                path: '/route1-path',
                meta: {
                  title: 'Route1Title',
                  icon: 'Route1Icon',
                },
              },
            ],
          },
        },
      },
      stubs: ['rux-clock', 'router-link', 'router-view'],
    }
    vuetifyOptions = {
      breakpoint: {
        mobileBreakpoint: 0,
      },
    }
  })
  it('shows links based on routes', () => {
    const wrapper = utils.createShallowWrapper(AppNav, options, vuetifyOptions)
    var link = wrapper.findAll('v-list-item-stub').at(0)
    expect(link.find('v-list-item-title-stub').text()).toBe('COSMOS')
    var link = wrapper.findAll('v-list-item-stub').at(1)
    expect(link.find('v-list-item-title-stub').text()).toBe('Route0Title')
    expect(link.find('v-icon-stub').text()).toBe('Route0Icon')
    var link = wrapper.findAll('v-list-item-stub').at(2)
    expect(link.find('v-list-item-title-stub').text()).toBe('Route1Title')
    expect(link.find('v-icon-stub').text()).toBe('Route1Icon')
  })
})
