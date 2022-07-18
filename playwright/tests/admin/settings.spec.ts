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
# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
*/

// @ts-check
import { test, expect } from 'playwright-test-coverage'

test('resets clock sync warning suppression', async ({ page }) => {
  await page.goto('/tools/admin/settings')
  await expect(page.locator('.v-app-bar')).toContainText('Administrator')
  await page.locator('.v-app-bar__nav-icon').click()

  await page.evaluate(
    `window.localStorage['suppresswarning__clock_out_of_sync_with_server'] = true`
  )
  await page.reload()
  // Must force due to "subtree intercepts pointer events"
  await page.locator('[data-test=select-all-suppressed-warnings]').click({ force: true })
  await page.locator('[data-test=reset-suppressed-warnings]').click()
  await expect(page.locator('id=openc3-tool')).toContainText('No warnings to reset')
})

test('clears recent configs', async ({ page }) => {
  await page.goto('/tools/dataviewer')
  let config = 'spec' + Math.floor(Math.random() * 10000)
  await page.locator('[data-test="data-viewer-file"]').click()
  await page.locator('text=Save Configuration').click()
  await page.locator('[data-test="name-input-save-config-dialog"]').fill(config)
  await page.locator('button:has-text("Ok")').click()
  let localStorage = await page.evaluate(() => window.localStorage)
  expect(localStorage['lastconfig__data_viewer']).toBe(config)

  await page.goto('/tools/admin/settings')
  await expect(page.locator('.v-app-bar')).toContainText('Administrator')
  await expect(page.locator('id=openc3-tool')).toContainText(config)
  // Must force due to "subtree intercepts pointer events"
  await page.locator('[data-test=select-all-last-configs]').click({ force: true })
  await page.locator('[data-test=clear-last-configs]').click()
  await expect(page.locator('id=openc3-tool')).not.toContainText(config)
  localStorage = await page.evaluate(() => window.localStorage)
  expect(localStorage['lastconfig__data_viewer']).toBe(undefined)
})

test('sets a classification banner', async ({ page }) => {
  await page.goto('/tools/admin/settings')
  await expect(page.locator('.v-app-bar')).toContainText('Administrator')
  await page.locator('.v-app-bar__nav-icon').click()

  const bannerText = 'Test Classification Banner'
  const bannerHeight = '32'
  const bannerTextColor = 'Orange'
  const bannerBackgroundColor = '123'
  await page.check('text=Display top banner')
  await page.locator('[data-test=classification-banner-text]').fill(bannerText)
  await page.locator('[data-test=classification-banner-top-height]').fill(bannerHeight)
  await page.locator('data-test=classification-banner-background-color').click()
  await page.locator('.v-list-item:has-text("Custom")').click()
  await page
    .locator('[data-test=classification-banner-custom-background-color]')
    .fill(bannerBackgroundColor)
  await page.locator('data-test=classification-banner-font-color').click()
  await page.locator(`.v-list-item:has-text("${bannerTextColor}") >> nth=1`).click()
  await page.locator('[data-test=save-classification-banner]').click()
  await page.reload()
  await expect(page.locator('#app')).toHaveAttribute(
    'style',
    // Chrome doesn't have spaces after the colon and Firefox does
    new RegExp(
      `--classification-text:\\s?"${bannerText}"; --classification-font-color:\\s?${bannerTextColor.toLowerCase()}; --classification-background-color:\\s?#${bannerBackgroundColor}; --classification-height-top:\\s?${bannerHeight}px; --classification-height-bottom:\\s?0px;`
    )
  )
  // Disable the classification banner
  await page.uncheck('text=Display top banner')
  await page.locator('[data-test=save-classification-banner]').click()
  await page.reload()
  await expect(page.locator('#app')).not.toHaveAttribute('style', `--classification-text`)
})

test('changes the source url', async ({ page }) => {
  await page.goto('/tools/admin/settings')
  await expect(page.locator('.v-app-bar')).toContainText('Administrator')
  await page.locator('.v-app-bar__nav-icon').click()

  await page.locator('[data-test=source-url]').fill('https://www.ball.com/aerospace')
  await page.locator('[data-test=save-source-url]').click()
  await page.reload()
  await expect(page.locator('footer a')).toHaveAttribute('href', 'https://www.ball.com/aerospace')
})

// TODO: Test Rubygems URL
