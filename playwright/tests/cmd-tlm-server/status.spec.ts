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

test('changes the limits set', async ({ page }) => {
  await page.goto('/tools/cmdtlmserver/status')
  await expect(page.locator('.v-app-bar')).toContainText('CmdTlmServer')
  await page.locator('.v-app-bar__nav-icon').click()
  await page.locator('[data-test=limits-set]').click()
  await page.locator(`.v-list-item__title:text-is("TVAC")`).click()
  await page.locator('[data-test=limits-set]').click()
  await page.locator(`.v-list-item__title:text-is("DEFAULT")`).click()
})
