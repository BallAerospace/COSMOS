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
