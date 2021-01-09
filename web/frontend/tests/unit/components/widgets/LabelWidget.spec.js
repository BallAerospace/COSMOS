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
import LabelWidget from '@/components/widgets/LabelWidget'

describe('LabelWidget', () => {
  it('displays text', () => {
    const wrapper = utils.createShallowWrapper(LabelWidget, {
      propsData: {
        parameters: ['test'],
      },
    })
    expect(wrapper.find('span').element.textContent).toEqual('test')
  })
})
