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

test.beforeEach(async ({ page }) => {
  await page.goto('/tools/scriptrunner')
  await expect(page.locator('.v-app-bar')).toContainText('Script Runner')
  await page.locator('.v-app-bar__nav-icon').click()
})

test('finds text on page', async ({ page }) => {
  // Have to fill on an editable area like the textarea
  var string = `cosmos is a command and control system
cosmos can send commands and execute scripts
cosmos is everything I thought it could be`
  await page.locator('textarea').fill(string)
  await page.locator('[data-test=script-runner-edit]').click()
  await page.locator('[data-test=script-runner-edit-find] >> text=Find').click()
  await page.locator('[placeholder="Search for"]').fill('cosmos')
  await page.locator('text=3 of 3')
  await page.locator('textarea').press('Escape')

  await page.locator('[data-test=script-runner-edit]').click()
  await page.locator('[data-test=script-runner-edit-replace] >> text=Replace').click()
  await page.locator('[placeholder="Search for"]').fill('cosmos')
  await page.locator('[placeholder="Replace with"]').fill('COSMOS')
  await page.locator('text=All').nth(1).click() // Replace All
  await page.locator('textarea').press('Escape')
  await page.locator('textarea').press('Control+f')
  await page.locator('[placeholder="Search for"]').fill('cosmos')
  await page.locator('text=3 of 3')
  await page.locator('text=Aa').click()
  await page.locator('text=0 of 0')
})
