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
