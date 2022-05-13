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
  await page.goto('/tools/packetviewer')
  await expect(page.locator('.v-app-bar')).toContainText('Packet Viewer')
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page)
})

// Checks the ITEM value against a regular expression.
async function matchItem(page, item, regex) {
  // Poll since inputValue is immediate
  await expect
    .poll(async () => {
      return await page.inputValue(`tr:has(td:text-is("${item}")) input`)
    })
    .toMatch(regex)
}

test('displays INST HEALTH_STATUS & polls the api', async ({ page }) => {
  // Verify we can hit it using the route
  await page.goto('/tools/packetviewer/INST/HEALTH_STATUS')
  await utils.inputValue(page, '[data-test=select-target] input', 'INST')
  await utils.inputValue(page, '[data-test=select-packet] input', 'HEALTH_STATUS')
  await expect(page.locator('id=cosmos-tool')).toContainText('Health and status') // Description

  page.on('request', (request) => {
    expect(request.url()).toMatch('/cosmos-api/api')
  })
  page.on('response', (response) => {
    expect(response.status()).toBe(200)
  })
  await utils.sleep(2000)
})

test('selects a target and packet to display', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'IMAGE')
  await utils.inputValue(page, '[data-test=select-target] input', 'INST')
  await utils.inputValue(page, '[data-test=select-packet] input', 'IMAGE')
  await expect(page.locator('id=cosmos-tool')).toContainText('Packet with image data')
  await expect(page.locator('id=cosmos-tool')).toContainText('BYTES')
})

test('gets details with right click', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await page.locator('tr:has-text("CCSDSVER") td >> nth=2').click({ button: 'right' })
  await page.locator('text=Details').click()
  await expect(page.locator('.v-dialog')).toContainText('INST HEALTH_STATUS CCSDSVER')
})

test('stops posting to the api after closing', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'ADCS')
  let requestCount = 0
  page.on('request', () => {
    requestCount++
  })
  await utils.sleep(2000)
  // Commenting out the next two lines causes the test to fail
  await page.goto('/tools/tablemanager') // No API requests
  await expect(page.locator('.v-app-bar')).toContainText('Table Manager')
  const count = requestCount
  await utils.sleep(2000) // Allow potential API requests to happen
  expect(requestCount).toBe(count) // no change
})

// Changing the polling rate is fraught with danger because it's all
// about waiting for changes and detecting changes
test('changes the polling rate', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await page.locator('[data-test=packet-viewer-file]').click()
  await page.locator('[data-test=packet-viewer-file-options]').click()
  await page.locator('.v-dialog input').fill('5000')
  await page.locator('.v-dialog input').press('Enter')
  await page.locator('.v-dialog').press('Escape')
  const received = await page.inputValue('tr:has-text("RECEIVED_COUNT") input')
  await utils.sleep(7000)
  const received2 = await page.inputValue('tr:has-text("RECEIVED_COUNT") input')
  expect(received2 - received).toBeLessThanOrEqual(6) // Allow slop
  expect(received2 - received).toBeGreaterThanOrEqual(4) // Allow slop
  // Set it back
  await page.locator('[data-test=packet-viewer-file]').click()
  await page.locator('[data-test=packet-viewer-file-options]').click()
  await page.locator('.v-dialog input').fill('1000')
  await page.locator('.v-dialog input').press('Enter')
  await page.locator('.v-dialog').press('Escape')
})

//
// Test the View menu
//
test('displays formatted items with units by default', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await page.locator('[aria-label="Next page"]').click()
  // Check for exactly 3 decimal points followed by units
  await matchItem(page, 'TEMP1', /^-?\d+\.\d{3}\s\S$/)
})

test('displays formatted items with units', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await page.locator('[aria-label="Next page"]').click()
  await page.locator('[data-test=packet-viewer-view]').click()
  await page.locator('text=Formatted Items with Units').click()
  // Check for exactly 3 decimal points followed by units
  await matchItem(page, 'TEMP1', /^-?\d+\.\d{3}\s\S$/)
})

test('displays raw items', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await page.locator('[aria-label="Next page"]').click()
  await page.locator('[data-test=packet-viewer-view]').click()
  await page.locator('text=Raw').click()
  // // Check for a raw number 1 to 99999
  await matchItem(page, 'TEMP1', /^\d{1,5}$/)
})

test('displays converted items', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await page.locator('[aria-label="Next page"]').click()
  await page.locator('[data-test=packet-viewer-view]').click()
  await page.locator('text=Converted').click()
  // Check for unformatted decimal points (4+)
  await matchItem(page, 'TEMP1', /^-?\d+\.\d{4,}$/)
})

test('displays formatted items', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await page.locator('[aria-label="Next page"]').click()
  await page.locator('[data-test=packet-viewer-view]').click()
  // Use text-is because we have to match exactly since there is
  // also a 'Formatted Items with Units' option
  await page.locator(':text-is("Formatted Items")').click()
  // Check for exactly 3 decimal points
  await matchItem(page, 'TEMP1', /^-?\d+\.\d{3}$/)
})

test('hides ignored items', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await expect(page.locator('text=CCSDSVER')).toBeVisible()
  await page.locator('[data-test=packet-viewer-view]').click()
  await page.locator('text=Hide Ignored').click()
  await expect(page.locator('text=CCSDSVER')).not.toBeVisible()
  await page.locator('[data-test=packet-viewer-view]').click()
  await page.locator('text=Hide Ignored').click()
  await expect(page.locator('text=CCSDSVER')).toBeVisible()
})

test('displays derived last', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  // First row is the header: Index, Name, Value so grab second (1)
  await expect(page.locator('tr').nth(1)).toContainText('PACKET_TIMESECONDS')
  await page.locator('[data-test=packet-viewer-view]').click()
  await page.locator('text=Display Derived').click()
  await expect(page.locator('tr').nth(1)).toContainText('CCSDSVER')
})
