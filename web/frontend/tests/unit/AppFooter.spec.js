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
            dark: false // TODO: For some reason starting with true doesn't work
          }
        }
      }
    })
    const wrapper = utils.createShallowWrapper(AppFooter, { vuetify })
    expect(wrapper.vm.$vuetify.theme.dark).toBe(false)
    wrapper.vm.toggleTheme()
    expect(wrapper.vm.$vuetify.theme.dark).toBe(true)
  })
})
