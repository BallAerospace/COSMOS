import utils from './../../utils'
import Widget from '@/components/widgets/Widget'

describe('Widget', () => {
  const Component = {
    render() {},
    mixins: [Widget],
  }

  it('computes styles based on settings', () => {
    const wrapper = utils.createWrapper(Component, {
      propsData: {
        settings: [
          ['TEXTALIGN', 'RIGHT'],
          ['PADDING', '5'],
          ['MARGIN', '10'],
          ['BACKCOLOR', 'GREEN'], // Colors can be named or
          ['TEXTCOLOR', 1, 2, 3], // passed as RGB values
          ['BORDERCOLOR', 'RED'],
          ['WIDTH', 15],
          ['HEIGHT', 20],
          ['RAW', 'font-family', 'Courier'],
        ],
      },
    })
    let style = wrapper.vm.computedStyle
    expect(style['text-align']).toBe('right')
    expect(style['padding']).toMatch('5px')
    expect(style['margin']).toMatch('10px')
    expect(style['background-color']).toBe('green')
    expect(style['color']).toBe('rgb(1,2,3)')
    expect(style['border-width']).not.toBeNull()
    expect(style['border-style']).not.toBeNull()
    expect(style['border-color']).toBe('red')
    expect(style['width']).toMatch('15px')
    expect(style['height']).toMatch('20px')
    // RAW values are not transformed at all (upper or lower case)
    expect(style['font-family']).toBe('Courier')
  })
})
