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

// @ts-check
import { test, expect } from 'playwright-test-coverage'
import { Utilities } from '../utilities'

let utils
test.beforeEach(async ({ page }) => {
  await page.goto('/tools/tlmviewer')
  await expect(page.locator('body')).toContainText('Telemetry Viewer')
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page)
  // Throw exceptions on any pageerror events
  page.on('pageerror', (exception) => {
    throw exception
  })
})

async function showScreen(page, target, screen, callback = null) {
  await page.locator('div[role="button"]:has-text("Select Target")').click()
  await page.locator(`.v-list-item__title:text-matches("^${target}$")`).click()
  await page.locator('div[role="button"]:has-text("Select Screen")').click()
  await page.locator(`.v-list-item__title:text-matches("^${screen}$")`).click()
  await page.locator('button:has-text("Show Screen")').click()
  await expect(page.locator(`.v-system-bar:has-text("${target} ${screen}")`)).toBeVisible()
  if (callback) {
    await callback()
  }
  await page.locator('[data-test="closeScreenIcon"]').click()
  await expect(page.locator(`.v-system-bar:has-text("${target} ${screen}")`)).not.toBeVisible()
}

test('displays INST ADCS', async ({ page }) => {
  await showScreen(page, 'INST', 'ADCS')
})

test('displays INST ARRAY', async ({ page }) => {
  await showScreen(page, 'INST', 'ARRAY')
})

test('displays INST BLOCK', async ({ page }) => {
  await showScreen(page, 'INST', 'BLOCK')
})
test('displays INST COMMANDING', async ({ page }) => {
  await showScreen(page, 'INST', 'COMMANDING')
})

test('displays INST GRAPHS', async ({ page }) => {
  await showScreen(page, 'INST', 'GRAPHS')
})

test('displays INST GROUND', async ({ page }) => {
  await showScreen(page, 'INST', 'GROUND')
})

test('displays INST HS', async ({ page }) => {
  await showScreen(page, 'INST', 'HS', async function () {
    await expect(page.locator('text=Health and Status')).toBeVisible()
    await page.locator('[data-test="minimizeScreenIcon"]').click()
    await expect(page.locator('text=Health and Status')).not.toBeVisible()
    await page.locator('[data-test="maximizeScreenIcon"]').click()
    await expect(page.locator('text=Health and Status')).toBeVisible()
  })
})

test('displays INST LATEST', async ({ page }) => {
  await showScreen(page, 'INST', 'LATEST')
})

test('displays INST LIMITS', async ({ page }) => {
  await showScreen(page, 'INST', 'LIMITS')
})

// OTHER not fully implemented
// test("displays INST OTHER", async ({ page }) => {
//   await showScreen(page, "INST", "OTHER");
// });

test('displays INST PARAMS', async ({ page }) => {
  await showScreen(page, 'INST', 'PARAMS')
})

test('displays INST SIMPLE', async ({ page }) => {
  const text = 'TEST' + Math.floor(Math.random() * 10000)
  await showScreen(page, 'INST', 'SIMPLE', async function () {
    await expect(page.locator(`text=${text}`)).not.toBeVisible()
    await page.locator('[data-test="editScreenIcon"]').click()
    await page.locator('[data-test="screenTextInput"]').fill(`
    SCREEN AUTO AUTO 0.5
    LABEL ${text}
    BIG INST HEALTH_STATUS TEMP2
    `)
    await page.locator('button:has-text("Save")').click()
    await expect(page.locator(`text=${text}`)).toBeVisible()
    await page.locator('[data-test="editScreenIcon"]').click()
    await expect(page.locator(`.v-system-bar:has-text("Edit Screen")`)).toBeVisible()
    await utils.download(page, '[data-test="downloadScreenIcon"]', function (contents) {
      expect(contents).toContain(`LABEL ${text}`)
      expect(contents).toContain('BIG INST HEALTH_STATUS TEMP2')
    })
    await page.locator('button:has-text("Cancel")').click()
    await expect(page.locator(`.v-system-bar:has-text("Edit Screen")`)).not.toBeVisible()
  })
})

test('displays INST TABS', async ({ page }) => {
  await showScreen(page, 'INST', 'TABS')
})
