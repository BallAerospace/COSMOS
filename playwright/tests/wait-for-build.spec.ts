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

test('waits for the services to deploy and connect', async ({ page }) => {
  await page.goto('/tools/cmdtlmserver')
  // Check the 3rd column (nth starts at 0) on the row containing INST_INT says CONNECTED
  await expect(page.locator('tr:has-text("INST_INT") td >> nth=2')).toContainText('CONNECTED', {
    timeout: 120000,
  })
  await expect(page.locator('tr:has-text("INST2_INT") td >> nth=2')).toContainText('CONNECTED', {
    timeout: 60000,
  })
})
