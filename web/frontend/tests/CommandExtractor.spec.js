import utils from './utils'
import LimitsMonitor from '@/tools/CommandExtractor/CommandExtractor'
import { CosmosApi } from '@/services/cosmos-api'

describe('CommandExtractor', () => {
  it('selects a command from the packet stream', async () => {
    const wrapper = utils.createShallowWrapper(CommandExtractor)
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
