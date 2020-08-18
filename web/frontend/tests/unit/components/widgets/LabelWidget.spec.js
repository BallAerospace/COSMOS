import utils from './../../utils'
import LabelWidget from '@/components/widgets/LabelWidget'

describe('LabelWidget', () => {
  it('displays text', () => {
    const wrapper = utils.createShallowWrapper(LabelWidget, {
      propsData: {
        parameters: ['test']
      }
    })
    expect(wrapper.find('span').element.textContent).toEqual('test')
  })
})
