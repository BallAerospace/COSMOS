// describe('Toggle Theme', () => {
//   test('toggles from dark to light', (browser) => {
//     browser.url('http://localhost:8080')
//     browser.expect
//       .element('#app')
//       .to.have.attribute('class')
//       .which.contains('theme--dark')
//     browser.useXpath().click("//*[contains(text(),'Toggle Theme')]")
//     browser
//       .useCss()
//       .expect.element('#app')
//       .to.have.attribute('class')
//       .which.contains('theme--light')
//   })
// })

describe('Toggle Navigation', () => {
  test('shows and hides the navigation pane', (browser) => {
    browser.url('http://localhost:8080')
    browser.expect.element('.v-navigation-drawer').to.be.visible
    browser.click('button')
    browser.expect.element('.v-navigation-drawer').to.not.be.visible
    browser.click('button')
    browser.expect.element('.v-navigation-drawer').to.be.visible
  })
})
