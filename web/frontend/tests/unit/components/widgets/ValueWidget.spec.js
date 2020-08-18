import utils from './../../utils'
import ValueWidget from '@/components/widgets/ValueWidget'

describe('ValueWidget', () => {
  let options = {}
  beforeEach(() => {
    options = {
      propsData: {
        value: null,
        limitsState: null
      },
      mocks: {
        $store: {
          dispatch: () => 0,
          state: {
            tlmViewerValues: [[], [], [], '']
          }
        }
      }
    }
  })

  it('accepts value and limitsState props', () => {
    options.propsData.value = 1.1
    options.propsData.limitsState = 'STALE'
    const wrapper = utils.createWrapper(ValueWidget, options)
    wrapper.setData({ valueId: 0 })
    expect(wrapper.classes()).toContain('cosmos-purple')
    expect(wrapper.find('input').element.value).toBe('1.1')
  })

  it('formats an Array object', async () => {
    options.propsData.value = [1, 2, 3, 4]
    options.propsData.limitsState = 'STALE'
    const wrapper = utils.createWrapper(ValueWidget, options)
    expect(wrapper.find('input').element.value).toBe('[1, 2, 3, 4]')
  })

  it('changes value and color with vuex updates', async () => {
    const wrapper = utils.createWrapper(ValueWidget, options)
    var textInput = wrapper.find('input')
    const limitsStates = [
      { key: 'GREEN_LOW', value: 'cosmos-green' },
      { key: 'GREEN_HIGH', value: 'cosmos-green' },
      { key: 'GREEN', value: 'cosmos-green' },
      { key: 'YELLOW_LOW', value: 'cosmos-yellow' },
      { key: 'YELLOW_HIGH', value: 'cosmos-yellow' },
      { key: 'YELLOW', value: 'cosmos-yellow' },
      { key: 'RED_LOW', value: 'cosmos-red' },
      { key: 'RED_HIGH', value: 'cosmos-red' },
      { key: 'RED', value: 'cosmos-red' },
      { key: 'BLUE', value: 'cosmos-blue' },
      { key: 'STALE', value: 'cosmos-purple' },
      // TODO: Make this work with theme
      { key: 'InvalidState', value: 'cosmos-white' }
    ]

    var value = 1
    for (const state of limitsStates) {
      options.mocks.$store.state.tlmViewerValues = [
        [value],
        [state.key],
        [],
        ''
      ]
      await wrapper.vm.$nextTick()
      expect(wrapper.classes()).toContain(state.value)
      expect(textInput.element.value).toBe(value.toString())
    }
  })
})
