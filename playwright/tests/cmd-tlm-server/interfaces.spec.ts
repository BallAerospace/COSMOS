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

test('disconnects & connects an interface', async ({ page }) => {
  await page.goto('/tools/cmdtlmserver/interfaces')
  await expect(page.locator('.v-app-bar')).toContainText('CmdTlmServer')
  await page.locator('.v-app-bar__nav-icon').click()

  await expect(page.locator('tr:has-text("INST_INT") td >> nth=2')).toContainText('CONNECTED')
  await page.locator('tr:has-text("INST_INT") td >> nth=1').click()
  await expect(page.locator('tr:has-text("INST_INT") td >> nth=2')).toContainText('DISCONNECTED')
  await expect(page.locator('[data-test=log-messages]')).toContainText('INST_INT: Disconnect')
  await page.locator('tr:has-text("INST_INT") td >> nth=1').click()
  await expect(page.locator('tr:has-text("INST_INT") td >> nth=2')).toContainText('CONNECTED')
  await expect(page.locator('[data-test=log-messages]')).toContainText(
    'INST_INT: Connection Success'
  )
})
