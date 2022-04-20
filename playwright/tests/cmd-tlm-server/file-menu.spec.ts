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
import { Utilities } from '../../utilities'
import { sub } from 'date-fns'

let utils
test.beforeEach(async ({ page }) => {
  await page.goto('/tools/cmdtlmserver')
  await expect(page.locator('.v-app-bar')).toContainText('CmdTlmServer')
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page)
})

//
// Test the File menu
//
test('changes the polling rate', async ({ page }) => {
  await page.locator('[data-test=cmdtlmserver-file]').click()
  await page.locator('text=Options').click()
  await page.locator('.v-dialog input').fill('5000')
  await page.locator('.v-dialog').press('Escape')
  await utils.sleep(1000)
  let rxbytes = await page.$('tr:has-text("INST_INT") td >> nth=7')
  const count1 = await rxbytes.textContent()
  await utils.sleep(2500)
  expect(await rxbytes.textContent()).toBe(count1)
  await utils.sleep(2500)
  // Now it's been more than 5s so it shouldn't match
  expect(await rxbytes.textContent()).not.toBe(count1)
})

//
// Test the basic functionality of the application
//
test('stops posting to the api after closing', async ({ page }) => {
  let requestCount = 0
  page.on('request', () => {
    requestCount++
  })
  await utils.sleep(2000)
  // Commenting out the next two lines causes the test to fail
  await page.goto('/tools/tablemanager') // No API requests
  await expect(page.locator('.v-app-bar')).toContainText('Table Manager')
  const count = requestCount
  await utils.sleep(2000) // Allow potential API requests to happen
  expect(requestCount).toBe(count) // no change
})
