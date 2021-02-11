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
import LimitsMonitor from '@/tools/LimitsMonitor/LimitsMonitor'
import { CosmosApi } from '@/services/cosmos-api'

describe('LimitsMonitor', () => {
  it('displays a limits message', async () => {
    const wrapper = utils.createShallowWrapper(LimitsMonitor)
    const mockTlm = jest.fn()
    CosmosApi.prototype.tlm = mockTlm
    mockTlm.mockReturnValue(Promise.resolve(10))

    // Note months start with 0 in new Date()
    const data = [new Date(2020, 0, 2, 10, 20, 30), 'LIMITS_SET', 'SET_NAME']
    wrapper.vm.processEvent(data)
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.limitsEventMessages.pop()[0]).toMatch(
      '2020-01-02 10:20:30 INFO: Limits Set Changed to: SET_NAME'
    )
  })
})
