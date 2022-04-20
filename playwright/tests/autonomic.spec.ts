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
  utils = new Utilities(page)
  await page.goto('/tools/autonomic')
  await expect(page.locator('body')).toContainText('Autonomic')
  await page.locator('.v-app-bar__nav-icon').click()
})

test('test overview page', async ({ page }) => {
  // groups
  await utils.download(page, '[data-test=group-download]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
  await page.locator('[data-test=new-group]').click()
  // events
  await page.locator('[data-test=events-clear]').click()
  await utils.download(page, '[data-test=events-download]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
})
