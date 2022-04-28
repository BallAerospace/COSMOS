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

test('prompts for hazardous commands', async ({ page }) => {
  await page.locator('textarea').fill('cmd("INST CLEAR")')
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('.v-dialog')).toContainText('Hazardous Command', {
    timeout: 20000,
  })
  await page.locator('.v-dialog >> button:has-text("No")').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('waiting')
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('.v-dialog')).toContainText('Hazardous Command')
  await page.locator('.v-dialog >> button:has-text("Yes")').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')
})

test('does not hazardous prompt for cmd_no_hazardous_check, cmd_no_checks', async ({ page }) => {
  await page.locator('textarea').fill(`
  cmd_no_hazardous_check("INST CLEAR")
  cmd_no_checks("INST CLEAR")
  `)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped', {
    timeout: 20000,
  })
})

test('errors for out of range command parameters', async ({ page }) => {
  await page.locator('textarea').fill(`cmd("INST COLLECT with DURATION 11, TYPE 'NORMAL'")`)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('error', {
    timeout: 20000,
  })
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')
  await expect(page.locator('[data-test=output-messages]')).toContainText('11 not in valid range')
})

test('does not out of range error for cmd_no_range_check, cmd_no_checks', async ({ page }) => {
  await page.locator('textarea').fill(`
  cmd_no_range_check("INST COLLECT with DURATION 11, TYPE 'NORMAL'")
  cmd_no_checks("INST COLLECT with DURATION 11, TYPE 'NORMAL'")
  `)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped', {
    timeout: 20000,
  })
})

test('opens a dialog for ask and returns the value', async ({ page }) => {
  await page.locator('textarea').fill(`
  value = ask("Enter password:")
  puts value
  value = ask("Optionally enter password:", true)
  puts "blank:#{value.empty?}"
  value = ask("Enter default password:", 67890)
  puts value
  value = ask("Enter SECRET password:", false, true)
  wait
  puts value
  `)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('.v-dialog')).toBeVisible({
    timeout: 20000,
  })
  await page.locator('.v-dialog >> button:has-text("Cancel")').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('User input: Cancel')
  await expect(page.locator('[data-test=state]')).toHaveValue('paused')

  // Clicking go re-launches the dialog
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('.v-dialog >> button:has-text("Ok")')).toBeDisabled()
  await page.locator('.v-dialog >> input').type('12345')
  await page.locator('.v-dialog >> button:has-text("Ok")').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('12345')
  // Now nothing is required so OK is enabled
  await expect(page.locator('.v-dialog >> button:has-text("Ok")')).toBeEnabled()
  await page.locator('.v-dialog >> button:has-text("Ok")').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('blank:true')
  // Verify the default value
  expect(await page.inputValue('[data-test=ask-value-input]')).toMatch('67890')
  await page.locator('.v-dialog >> button:has-text("Ok")').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('67890')
  // Now type the secret password
  await page.locator('.v-dialog >> input').type('abc123!')
  await page.locator('.v-dialog >> button:has-text("Ok")').click()

  await expect(page.locator('[data-test=state]')).toHaveValue('waiting')
  // Verify we're not outputting the secret password on input
  await expect(page.locator('[data-test=output-messages]')).not.toContainText('abc123!')
  // Once we restart we should see it since we print it
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('abc123!')
})

test('opens a dialog with buttons for message_box, vertical_message_box', async ({ page }) => {
  await page.locator('textarea').fill(`
  value = message_box("Select", "ONE", "TWO", "THREE")
  puts value
  value = vertical_message_box("Select", "FOUR", "FIVE", "SIX")
  puts value
  `)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('.v-dialog')).toBeVisible({
    timeout: 20000,
  })
  await page.locator('.v-dialog >> button:has-text("Cancel")').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('User input: Cancel')
  await expect(page.locator('[data-test=state]')).toHaveValue('paused')

  // Clicking Go re-launches the dialog
  await page.locator('[data-test=go-button]').click()
  await page.locator('.v-dialog >> button:has-text("TWO")').click()
  await page.locator('.v-dialog >> button:has-text("FOUR")').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')
  await expect(page.locator('[data-test=output-messages]')).toContainText('TWO')
  await expect(page.locator('[data-test=output-messages]')).toContainText('FOUR')
})

test('opens a dialog with dropdowns for combo_box', async ({ page }) => {
  await page.locator('textarea').fill(`
  value = combo_box("Select value from combo", "abc123", "def456")
  puts value
  `)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('.v-dialog')).toBeVisible({
    timeout: 20000,
  })
  await page.locator('.v-dialog >> button:has-text("Cancel")').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('User input: Cancel')
  await expect(page.locator('[data-test=state]')).toHaveValue('paused')

  // Clicking go re-launches the dialog
  await page.locator('[data-test=go-button]').click()
  await page.locator('[data-test=prompt-select]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('waiting')
  await page.locator('div[role="listbox"] >> text=def456').click()
  await page.locator('.v-dialog >> button:has-text("Ok")').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')
  await expect(page.locator('[data-test=output-messages]')).toContainText('User input: def456')
})

test('opens a dialog for prompt', async ({ page }) => {
  // Default choices for prompt is Ok and Cancel
  await page.locator('textarea').fill(`
  value = prompt("Continue?")
  puts value
  `)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('.v-dialog')).toBeVisible({
    timeout: 20000,
  })
  await expect(page.locator('.v-dialog')).toContainText('Continue?')
  await page.locator('.v-dialog >> button:has-text("Cancel")').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('User input: Cancel')
  await expect(page.locator('[data-test=state]')).toHaveValue('paused')

  // Clicking Go re-executes the prompt
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('.v-dialog')).toContainText('Continue?')
  await page.locator('.v-dialog >> button:has-text("Ok")').click()
  await expect(page.locator('[data-test=output-messages]')).toContainText('Ok')
})
