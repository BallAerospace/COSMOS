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

test('keeps a debug command history', async ({ page }) => {
  // Note we have to escape the { in cypress with {{}
  await page.locator('textarea').fill(`
  x = 12345
  wait
  puts "x:#{x}"
  puts "one"
  puts "two"
  `)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('waiting', {
    timeout: 20000,
  })
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Toggle Debug').click()
  await expect(page.locator('[data-test=debug-text]')).toBeVisible()
  await page.locator('[data-test=debug-text]').type('x')
  await page.keyboard.press('Enter')
  await expect(page.locator('[data-test=output-messages]')).toContainText('12345')
  await page.locator('[data-test=debug-text]').type('puts "abc123!"')
  await page.keyboard.press('Enter')
  await expect(page.locator('[data-test=output-messages]')).toContainText('abc123!')
  await page.locator('[data-test=debug-text]').type('x = 67890')
  await page.keyboard.press('Enter')
  // Test the history
  await page.locator('[data-test=debug-text]').click()
  await page.keyboard.press('ArrowUp')
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('x = 67890')
  await page.keyboard.press('ArrowUp')
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('puts "abc123!"')
  await page.keyboard.press('ArrowUp')
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('x')
  await page.keyboard.press('ArrowUp') // history wraps
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('x = 67890')
  await page.keyboard.press('ArrowDown')
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('x')
  await page.keyboard.press('ArrowDown')
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('puts "abc123!"')
  await page.keyboard.press('ArrowDown')
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('x = 67890')
  await page.keyboard.press('ArrowDown') // history wraps
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('x')
  await page.keyboard.press('Escape') // clear the debug
  expect(await page.inputValue('[data-test=debug-text]')).toMatch('')
  // Step
  await page.locator('[data-test=step-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('paused')
  await page.locator('[data-test=step-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('paused')
  // Go
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')
  // Verify we were able to change the 'x' variable
  await expect(page.locator('[data-test=output-messages]')).toContainText('x:67890')

  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Toggle Debug').click()
  await expect(page.locator('[data-test=debug-text]')).not.toBeVisible()
})

test('retries failed checks', async ({ page }) => {
  await page.locator('textarea').fill('check_expression("1 == 2")')
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('error', {
    timeout: 20000,
  })
  // Check for the initial check message
  await expect(page.locator('[data-test=output-messages]')).toContainText('1 == 2 is FALSE')
  await page.locator('[data-test=pause-retry-button]').click() // Retry
  // Now we should have two error messages
  await expect(
    page.locator('[data-test=output-messages] td:has-text("1 == 2 is FALSE")')
  ).toHaveCount(2)
  await expect(page.locator('[data-test=state]')).toHaveValue('error')
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')
})

test('displays the call stack', async ({ page }) => {
  // Show Call Stack is disabled unless a script is running
  await page.locator('[data-test=script-runner-script]').click()
  // NOTE: This doesn't work in playwright 1.21.0 due to unexpected value "false"
  // await expect(page.locator('text=Show Call Stack')).toBeDisabled()
  // See: https://github.com/microsoft/playwright/issues/13583
  // See: https://github.com/vuetifyjs/vuetify/issues/14968
  // await expect(page.locator('[data-test=script-runner-script-show-call-stack]')).toBeDisabled()
  await expect(page.locator('[data-test=script-runner-script-show-call-stack]')).toHaveAttribute(
    'aria-disabled',
    'true'
  )
  // await expect(page.locator('[data-test=script-runner-script-show-call-stack]')).toBeDisabled()

  await page.locator('textarea').fill(`
  def one
    two()
  end
  def two
    wait
  end
  one()
  `)
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('waiting', {
    timeout: 20000,
  })
  await page.locator('[data-test=pause-retry-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('paused')

  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Show Call Stack').click()
  await expect(page.locator('.v-dialog')).toContainText('Call Stack')
  await page.locator('button:has-text("Ok")').click()
  await page.locator('[data-test=stop-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')

  await page.locator('[data-test=script-runner-script]').click()
  await expect(page.locator('[data-test=script-runner-script-show-call-stack]')).toHaveAttribute(
    'aria-disabled',
    'true'
  )
})

test('displays disconnect icon', async ({ page }) => {
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Toggle Disconnect').click()

  // In Disconnect mode all commands go nowhere, all checks pass,
  // and all waits are immediate (no waiting)
  // Only read-only methods are allowed and tlm methods can take
  // a disconnect kwarg to set a return value
  await page.locator('textarea').fill(`
  count1 = tlm("INST HEALTH_STATUS COLLECTS")
  cmd("INST COLLECT with TYPE 'NORMAL', DURATION 1, TEMP 0")
  wait_check("INST HEALTH_STATUS COLLECTS > #{count1}", 5)
  wait_check_expression("1 == 2", 5)
  wait
  set_tlm("INST HEALTH_STATUS COLLECTS = 50")
  count2 = tlm("INST HEALTH_STATUS COLLECTS")
  puts "total:#{count2 - count1}"
  val = tlm("INST HEALTH_STATUS COLLECTS", disconnect: 100)
  puts "disconnect:#{val}"
  `)

  await page.locator('[data-test=start-button]').click()
  // Runs without stopping
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped', {
    timeout: 20000,
  })
  await expect(page.locator('[data-test=output-messages]')).toContainText(
    'total:0' // collect count does not change
  )
  await expect(page.locator('[data-test=output-messages]')).toContainText('disconnect:100')

  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Toggle Disconnect').click()
})
