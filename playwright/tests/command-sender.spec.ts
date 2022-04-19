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
  await page.goto('/tools/cmdsender')
  await expect(page.locator('.v-app-bar')).toContainText('Command Sender')
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page)
})

// Helper function to select a parameter dropdown
async function selectValue(page, param, value) {
  await page.locator(`tr:has-text("${param}") [data-test="cmd-param-select"]`).click()
  await page.locator(`text=${value}`).click()
  await expect(page.locator('tr:has-text("TYPE")')).toContainText(value)
}

// Helper function to set parameter value
async function setValue(page, param, value) {
  await page.locator(`tr:has-text("${param}") [data-test="cmd-param-value"]`).fill(value)
  // Trigger the update handler that sets the drop down by pressing Enter
  await page.locator(`tr:has-text("${param}") [data-test="cmd-param-value"]`).press('Enter')
  await checkValue(page, param, value)
}

// Helper function to check parameter value
async function checkValue(page, param, value) {
  expect(await page.inputValue(`tr:has-text("${param}") [data-test="cmd-param-value"]`)).toMatch(
    value
  )
}

// Helper function to check command history
async function checkHistory(page, value) {
  expect(await page.inputValue('[data-test=sender-history]')).toMatch(value)
}

//
// Test the basic functionality of the application
//
test('selects a target and packet', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'ABORT')
  await page.locator('button:has-text("Send")').click()
  await expect(page.locator('main')).toContainText('cmd("INST ABORT") sent')
})

test('displays INST COLLECT using the route', async ({ page }) => {
  await page.goto('/tools/cmdsender/INST/COLLECT')
  await expect(page.locator('main')).toContainText('INST')
  await expect(page.locator('main')).toContainText('COLLECT')
  await expect(page.locator('main')).toContainText('Starts a collect')
  await expect(page.locator('main')).toContainText('Parameters')
  await expect(page.locator('main')).toContainText('DURATION')
})

test('displays state parameters with drop downs', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'COLLECT')
  await selectValue(page, 'TYPE', 'SPECIAL')
  await checkValue(page, 'TYPE', '1')
  await selectValue(page, 'TYPE', 'NORMAL')
  await checkValue(page, 'TYPE', '0')
})

test('supports manually entered state values', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'COLLECT')
  await setValue(page, 'TYPE', '3')
  // Typing in the state value should automatically switch the state
  await expect(page.locator('tr:has-text("TYPE")')).toContainText('MANUALLY ENTERED')

  // Manually typing in an existing state value should change the state drop down
  await setValue(page, 'TYPE', '0x0')
  await expect(page.locator('tr:has-text("TYPE")')).toContainText('NORMAL')
  // Switch back to MANUALLY ENTERED
  await selectValue(page, 'TYPE', 'MANUALLY ENTERED')
  await setValue(page, 'TYPE', '3')
  await page.locator('button:has-text("Send")').click()
  await expect(page.locator('main')).toContainText(
    'Status: cmd("INST COLLECT with TYPE 3, DURATION 1, OPCODE 171, TEMP 0") sent'
  )
  await checkHistory(page, 'cmd("INST COLLECT with TYPE 3, DURATION 1, OPCODE 171, TEMP 0")')
})

test('warns for hazardous commands', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'CLEAR')
  await expect(page.locator('main')).toContainText('Clears counters')
  await page.locator('button:has-text("Send")').click()
  await page.locator('button:has-text("No")').click()
  await expect(page.locator('main')).toContainText('Hazardous command not sent')
  await page.locator('button:has-text("Send")').click()
  await page.locator('button:has-text("Yes")').click()
  await expect(page.locator('main')).toContainText('("INST CLEAR") sent')
  await checkHistory(page, 'cmd("INST CLEAR")')
})

test('warns for required parameters', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'COLLECT')
  await page.locator('button:has-text("Send")').click()
  // Break apart the checks so we have output flexibily in the future
  await expect(page.locator('.v-dialog')).toContainText('Error sending')
  await expect(page.locator('.v-dialog')).toContainText('INST COLLECT TYPE')
  await expect(page.locator('.v-dialog')).toContainText('not in valid range')
  await page.locator('button:has-text("Ok")').click()
})

test('warns for hazardous parameters', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'COLLECT')
  await selectValue(page, 'TYPE', 'SPECIAL')
  await page.locator('button:has-text("Send")').click()
  await page.locator('button:has-text("No")').click()
  await expect(page.locator('main')).toContainText('Hazardous command not sent')
  await page.locator('button:has-text("Send")').click()
  await page.locator('button:has-text("Yes")').click()
  await expect(page.locator('main')).toContainText(
    '("INST COLLECT with TYPE 1, DURATION 1, OPCODE 171, TEMP 0") sent'
  )
  await checkHistory(page, 'cmd("INST COLLECT with TYPE 1, DURATION 1, OPCODE 171, TEMP 0")')
})

test('handles float values and scientific notation', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'FLTCMD')
  await setValue(page, 'FLOAT32', '123.456')
  await setValue(page, 'FLOAT64', '12e3')
  await page.locator('button:has-text("Send")').click()
  await expect(page.locator('main')).toContainText(
    '("INST FLTCMD with FLOAT32 123.456, FLOAT64 12000") sent'
  )
  await checkHistory(page, 'cmd("INST FLTCMD with FLOAT32 123.456, FLOAT64 12000")')
})

test('handles array values', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'ARYCMD')
  await setValue(page, 'ARRAY', '10')
  await page.locator('button:has-text("Send")').click()
  await expect(page.locator('.v-dialog')).toContainText('must be an Array')
  await page.locator('button:has-text("Ok")').click()
  await setValue(page, 'ARRAY', '[1,2,3,4]')
  await page.locator('button:has-text("Send")').click()
  await expect(page.locator('main')).toContainText(
    'cmd("INST ARYCMD with ARRAY [ 1, 2, 3, 4 ], CRC 0") sent'
  )
  await checkHistory(page, 'cmd("INST ARYCMD with ARRAY [ 1, 2, 3, 4 ], CRC 0")')
})

// // TODO: This needs work
// it.skip('handles string values', async ({ page }) => {
//   cy.vistest('/tools/cmdsender/INST/ASCIICMD')
//   cy.hideNav()
//   cy.wait(1000)
//   await expect(page.locator('main')).toContainText('ASCII command')
//   await page.locator('button:has-text("Send")').click();
// })

test('gets details with right click', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'COLLECT')
  await page.locator('text=Collect type').click({ button: 'right' })
  await page.locator('text=Details').click()
  await expect(page.locator('.v-dialog')).toContainText('INST COLLECT TYPE')
  await page.locator('.v-dialog').press('Escape')
  await expect(page.locator('.v-dialog')).not.toBeVisible()
})

test('executes commands from history', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'CLEAR')
  await page.locator('button:has-text("Send")').click()
  await page.locator('.v-dialog button:has-text("Yes")').click()
  await expect(page.locator('main')).toContainText('cmd("INST CLEAR") sent')
  await checkHistory(page, 'cmd("INST CLEAR")')
  // Re-execute the command from the history
  await page.locator('[data-test=sender-history]').click()
  await page.locator('[data-test=sender-history]').press('ArrowUp')
  await page.locator('[data-test=sender-history]').press('Enter')
  await page.locator('.v-dialog button:has-text("Yes")').click()
  // Now history says it was sent twice (2)
  await expect(page.locator('main')).toContainText('cmd("INST CLEAR") sent. (2)')
  await page.locator('[data-test=sender-history]').click()
  await page.locator('[data-test=sender-history]').press('ArrowUp')
  await page.locator('[data-test=sender-history]').press('Enter')
  await page.locator('.v-dialog button:has-text("Yes")').click()
  // Now history says it was sent three times (3)
  await expect(page.locator('main')).toContainText('cmd("INST CLEAR") sent. (3)')

  // Send a different command: INST SETPARAMS
  await utils.selectTargetPacketItem('INST', 'SETPARAMS')
  await page.locator('button:has-text("Send")').click()
  await expect(page.locator('main')).toContainText(
    'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 1") sent.'
  )
  // History should now contain both commands
  await checkHistory(page, 'cmd("INST CLEAR")')
  await checkHistory(
    page,
    'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 1")'
  )
  // Re-execute command
  await page.locator('[data-test=sender-history]').click()
  await page.locator('[data-test=sender-history]').press('ArrowUp')
  await page.locator('[data-test=sender-history]').press('ArrowUp')
  await page.locator('[data-test=sender-history]').press('ArrowDown')
  await page.locator('[data-test=sender-history]').press('Enter')
  await expect(page.locator('main')).toContainText(
    'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 1") sent. (2)'
  )
  // Edit the existing SETPARAMS command and then send
  // This is somewhat fragile but not sure how else to edit
  await page.locator('[data-test=sender-history]').click()
  await page.locator('[data-test=sender-history]').press('ArrowLeft')
  await page.locator('[data-test=sender-history]').press('ArrowLeft')
  await page.locator('[data-test=sender-history]').press('ArrowLeft')
  await page.locator('[data-test=sender-history]').press('Backspace')
  await page.locator('[data-test=sender-history]').type('5')
  await page.locator('[data-test=sender-history]').press('Enter')
  await expect(page.locator('main')).toContainText(
    'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 5") sent.'
  )
  // History should now contain CLEAR and both SETPARAMS commands
  await checkHistory(page, 'cmd("INST CLEAR")')
  await checkHistory(
    page,
    'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 1")'
  )
  await checkHistory(
    page,
    'cmd("INST SETPARAMS with VALUE1 1, VALUE2 1, VALUE3 1, VALUE4 1, VALUE5 5")'
  )
})

//
// Test the Mode menu
//
test('ignores range checks', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'COLLECT')
  await selectValue(page, 'TYPE', 'NORMAL') // Ensure TYPE is set since its required
  await setValue(page, 'TEMP', '100')
  await page.locator('button:has-text("Send")').click()
  // Dialog should pop up with error
  await expect(page.locator('.v-dialog')).toContainText('not in valid range')
  await page.locator('button:has-text("Ok")').click()

  // Status should also show error
  await expect(page.locator('main')).toContainText('not in valid range')
  await page.locator('[data-test="Command Sender-Mode"]').click()
  await page.locator('text=Ignore Range Checks').click()
  await page.locator('button:has-text("Send")').click()
  await expect(page.locator('main')).toContainText('TEMP 100") sent')
})

test('displays state values in hex', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'COLLECT')
  await selectValue(page, 'TYPE', 'NORMAL') // Ensure TYPE is set since its required
  await checkValue(page, 'TYPE', '0')
  await page.locator('[data-test="Command Sender-Mode"]').click()
  await page.locator('text=Display State').click()
  await checkValue(page, 'TYPE', '0x0')
})

test('shows ignored parameters', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'ABORT')
  // All the ABORT parameters are ignored so the table shouldn't appear
  await expect(page.locator('main')).not.toContainText('Parameters')
  await page.locator('[data-test="Command Sender-Mode"]').click()
  await page.locator('text=Show Ignored').click()
  await expect(page.locator('main')).toContainText('Parameters') // Now the parameters table is shown
  await expect(page.locator('main')).toContainText('CCSDSVER') // CCSDSVER is one of the parameters
})

// In order to test parameter conversions we have to look at the raw buffer
// Thus we send the INST SET PARAMS command which has a parameter conversion,
// check the raw buffer, then send it with parameter conversions disabled,
// and re-check the raw buffer for a change.
test('disable parameter conversions', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'SETPARAMS')
  await page.locator('button:has-text("Send")').click()
  await page.locator('.v-app-bar__nav-icon').click()

  await page.locator('text=Script Runner').click()
  await expect(page.locator('body')).toContainText('Script Runner')
  await page
    .locator('textarea')
    .fill('puts get_cmd_buffer("INST", "SETPARAMS")["buffer"].formatted')
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test="state"]')).toHaveValue('stopped', { timeout: 10000 })
  await expect(page.locator('[data-test="output-messages"]')).toContainText('00000010: 00 02')

  await page.locator('text=Command Sender').click()
  await expect(page.locator('body')).toContainText('Command Sender')
  await page.locator('[data-test="Command Sender-Mode"]').click()
  await page.locator('text=Disable Parameter').click()

  await utils.selectTargetPacketItem('INST', 'SETPARAMS')
  await page.locator('button:has-text("Send")').click()

  await page.locator('text=Script Runner').click()
  await expect(page.locator('body')).toContainText('Script Runner')
  await page
    .locator('textarea')
    .fill('puts get_cmd_buffer("INST", "SETPARAMS")["buffer"].formatted')
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test="state"]')).toHaveValue('stopped', { timeout: 10000 })
  await expect(page.locator('[data-test="output-messages"]')).toContainText('00000010: 00 01')
})
