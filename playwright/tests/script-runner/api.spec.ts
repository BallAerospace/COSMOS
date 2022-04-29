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
  // Close the dialog that says how many running scripts there are
  await page.locator('button:has-text("Close")').click()
})

test('opens a target file', async ({ page }) => {
  await page.locator('textarea').fill(`
  put_target_file("INST/test.txt", "file contents")
  file = get_target_file("INST/test.txt")
  puts file.read
  file.delete
  delete_target_file("INST/test.txt")
  get_target_file("INST/test.txt") # Causes error

  file = get_target_file("INST/screens/web.txt")
  web = file.read
  web += 'LABEL "TEST"'
  put_target_file("INST/screens/web.txt", web)
  file = get_target_file("INST/screens/web.txt")
  if file.read.include?("TEST")
    puts "Edited web"
  end
  file = get_target_file("INST/screens/web.txt", original: true)
  if !file.read.include?("TEST")
    puts "Original web"
  end
  `)

  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('error', {
    timeout: 30000,
  })
  await expect(page.locator('[data-test=output-messages]')).toContainText(
    'Writing DEFAULT/targets_modified/INST/test.txt'
  )
  await expect(page.locator('[data-test=output-messages]')).toContainText(
    'Reading DEFAULT/targets_modified/INST/test.txt'
  )
  await expect(page.locator('[data-test=output-messages]')).toContainText('file contents')
  await expect(page.locator('[data-test=output-messages]')).toContainText(
    'Deleting DEFAULT/targets_modified/INST/test.txt'
  )
  // Restart after the error
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText(
    'Reading DEFAULT/targets_modified/INST/screens/web.txt'
  )
  await expect(page.locator('[data-test=output-messages]')).toContainText('Edited web')
  await expect(page.locator('[data-test=output-messages]')).toContainText(
    'Reading DEFAULT/targets/INST/screens/web.txt'
  )
  await expect(page.locator('[data-test=output-messages]')).toContainText('Original web')
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')
})
