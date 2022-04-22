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
  await page.goto('/tools/cmdtlmserver/targets')
  await expect(page.locator('.v-app-bar')).toContainText('CmdTlmServer')
  await page.locator('.v-app-bar__nav-icon').click()
})

test('displays the list of targets', async ({ page }) => {
  await expect(page.locator('[data-test=targets-table]')).toContainText('INST')
  await expect(page.locator('[data-test=targets-table]')).toContainText('INST2')
  await expect(page.locator('[data-test=targets-table]')).toContainText('EXAMPLE')
  await expect(page.locator('[data-test=targets-table]')).toContainText('TEMPLATED')
})

test('displays the command & telemetry count', async ({ page }) => {
  await expect(page.locator('[data-test=targets-table]')).toContainText('INST')
  expect(
    parseInt(await page.locator('tr:has-text("INST_INT") td >> nth=2').textContent())
  ).toBeGreaterThan(1)
  expect(
    parseInt(await page.locator('tr:has-text("INST_INT") td >> nth=3').textContent())
  ).toBeGreaterThan(50)
})
