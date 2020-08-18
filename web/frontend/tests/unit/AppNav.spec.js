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
            icon: 'icon'
          }
        },
        $router: {
          options: {
            routes: [
              {
                name: 'Route0Name',
                path: '/route0-path',
                meta: {
                  title: 'Route0Title',
                  icon: 'Route0Icon'
                }
              },
              {
                name: 'Route1Name',
                path: '/route1-path',
                meta: {
                  title: 'Route1Title',
                  icon: 'Route1Icon'
                }
              }
            ]
          }
        }
      },
      stubs: ['rux-clock', 'router-link', 'router-view']
    }
    vuetifyOptions = {
      breakpoint: {
        mobileBreakpoint: 0
      }
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
