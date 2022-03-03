/*
# Copyright 2022 Ball Aerospace & Technologies Corp.
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

describe('AdminSettings', () => {
  beforeEach(() => {
    cy.visit('/tools/admin/settings')
    cy.hideNav()
    cy.wait(1000)
  })

  it('resets clock sync warning suppression', function () {
    window.localStorage['suppresswarning__clock_out_of_sync_with_server'] = true
    cy.reload()
    cy.wait(1000)
    cy.get('[data-test=selectAllSuppressedWarnings]').check({ force: true })
    cy.get('[data-test=resetSuppressedWarnings]').click({ force: true })
    cy.then(() => {
      expect(
        window.localStorage['suppresswarning__clock_out_of_sync_with_server']
      ).to.eq(undefined)
    })
  })

  it('clears recent configs', function () {
    const configName = `test-${Math.random()}`
    cy.visit('/tools/dataViewer')
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save Configuration').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.get('[data-test=name-input-save-config-dialog]')
        .clear()
        .type(configName)
      cy.contains('Ok')
        .click()
        .wait(1000)
        .then(() => {
          expect(window.localStorage['lastconfig__data_viewer']).to.eq(
            configName
          )
        })
    })
    cy.visit('/tools/admin/settings')
    cy.get('[data-test=selectAllLastConfigs]').check({ force: true })
    cy.get('[data-test=clearLastConfigs]').click()
    cy.then(() => {
      expect(window.localStorage['lastconfig__data_viewer']).to.eq(undefined)
    })
  })

  it('sets a classification banner', function () {
    const bannerText = 'test classification banner'
    const bannerHeight = '32'
    const bannerTextColor = 'aaa'
    const bannerBackgroundColor = '123'
    cy.get('[data-test=classificationBannerText]').clear().type(bannerText)
    cy.get('[data-test=displayTopBanner]').check({ force: true })
    cy.get('[data-test=classificationBannerTopHeight]')
      .clear()
      .type(bannerHeight)
    cy.chooseVSelect('Background color', 'Custom', {
      selectionElement: '.v-list-item--link',
      fuzzy: true,
    })
    cy.get('[data-test=classificationBannerCustomBackgroundColor]')
      .clear()
      .type(bannerBackgroundColor)
    cy.chooseVSelect('Font color', 'Custom', {
      selectionElement: '.v-list-item--link',
      fuzzy: true,
      index: 17,
    })
    cy.get('[data-test=classificationBannerCustomFontColor]')
      .clear()
      .type(bannerTextColor)
    cy.get('[data-test=saveClassificationBanner]').click()
    cy.reload()
    cy.get('#app').should(
      'have.attr',
      'style',
      `--classification-text:"${bannerText.toUpperCase()}"; --classification-font-color:#${bannerTextColor.toUpperCase()}; --classification-background-color:#${bannerBackgroundColor.toUpperCase()}; --classification-height-top:${bannerHeight}px; --classification-height-bottom:0px;`
    )
  })
})
