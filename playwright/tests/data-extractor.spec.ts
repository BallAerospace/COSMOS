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
import { format, add, sub } from 'date-fns'

let utils
test.beforeEach(async ({ page }) => {
  await page.goto('/tools/dataextractor')
  await expect(page.locator('.v-app-bar')).toContainText('Data Extractor')
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page)
  await utils.sleep(100)
})

test('loads and saves the configuration', async ({ page }) => {
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')

  let config = 'spec' + Math.floor(Math.random() * 10000)
  await page.locator('[data-test=data-extractor-file]').click()
  await page.locator('text=Save Configuration').click()
  await page.locator('[data-test=name-input-save-config-dialog]').fill(config)
  await page.locator('button:has-text("Ok")').click()
  // Clear the success toast
  await page.locator('button:has-text("Dismiss")').click()

  // This also works but it relies on a Vuetify attribute
  // await expect(page.locator('[role=listitem]')).toHaveCount(2)
  await expect(page.locator('[data-test=item-list] > div')).toHaveCount(2)
  await page.locator('[data-test=delete-all]').click()
  await expect(page.locator('[data-test=item-list] > div')).toHaveCount(0)

  await page.locator('[data-test=data-extractor-file]').click()
  await page.locator('text=Open Configuration').click()
  await page.locator(`td:has-text("${config}")`).click()
  await page.locator('button:has-text("Ok")').click()
  // Clear the success toast
  await page.locator('button:has-text("Dismiss")').click()
  await expect(page.locator('[data-test=item-list] > div')).toHaveCount(2)

  // Delete this test configuation
  await page.locator('[data-test=data-extractor-file]').click()
  await page.locator('text=Open Configuration').click()
  await page.locator(`tr:has-text("${config}") [data-test=item-delete]`).click()
  await page.locator('button:has-text("Delete")').click()
  await page.locator('[data-test=open-config-cancel-btn]').click()
})

test('validates dates and times', async ({ page }) => {
  // Date validation
  const d = new Date()
  await expect(page.locator('text=Required')).not.toBeVisible()
  // await page.locator("[data-test=start-date]").click();
  // await page.keyboard.press('Delete')
  await page.locator('[data-test=start-date]').fill('')
  await expect(page.locator('text=Required')).toBeVisible()
  // Note: Firefox doesn't implement min/max the same way as Chrome
  // Chromium limits you to just putting in the day since it has a min/max value
  // Firefox doesn't apppear to limit at all so you need to enter entire date
  // End result is that in Chromium the date gets entered as the 2 digit year
  // e.g. "22", which is fine because even if you go big it will round down.
  await page.locator('[data-test=start-date]').type(format(d, 'MM'))
  await page.locator('[data-test=start-date]').type(format(d, 'dd'))
  await page.locator('[data-test=start-date]').type(format(d, 'yyyy'))
  await expect(page.locator('text=Required')).not.toBeVisible()
  // Time validation
  await page.locator('[data-test=start-time]').fill('')
  await expect(page.locator('text=Required')).toBeVisible()
  await page.locator('[data-test=start-time]').fill('12:15:15')
  await expect(page.locator('text=Required')).not.toBeVisible()
})

test("won't start with 0 items", async ({ page }) => {
  await expect(page.locator('text=Process')).toBeDisabled()
})

test('warns with duplicate item', async ({ page }) => {
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
  await page.locator('[data-test=select-send]').click() // Send again
  await expect(page.locator('text=This item has already been added')).toBeVisible()
})

test('warns with no time delta', async ({ page }) => {
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
  await page.locator('text=Process').click()
  await expect(page.locator('text=Start date/time is equal to end date/time')).toBeVisible()
})

test('warns with no data', async ({ page }) => {
  const start = sub(new Date(), { seconds: 10 })
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await page.locator('label:has-text("Command")').click()
  await utils.sleep(500) // Allow the command to switch
  await utils.addTargetPacketItem('EXAMPLE', 'START', 'RECEIVED_TIMEFORMATTED')
  await page.locator('text=Process').click()
  await expect(page.locator('text=No data found')).toBeVisible()
})

test('cancels a process', async ({ page }) => {
  const start = sub(new Date(), { minutes: 2 })
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await page.locator('[data-test=end-time]').fill(format(add(start, { hours: 1 }), 'HH:mm:ss'))
  await utils.addTargetPacketItem('INST', 'ADCS', 'CCSDSVER')
  await page.locator('text=Process').click()
  await expect(page.locator('text=End date/time is greater than current date/time')).toBeVisible()
  await utils.sleep(5000)
  await utils.download(page, 'text=Cancel')
  // Ensure the Cancel button goes back to Process
  await expect(page.locator('text=Process')).toBeVisible()
})

test('adds an entire target', async ({ page }) => {
  await utils.addTargetPacketItem('INST')
  // Since we're checking count() which is instant we need to poll
  await expect.poll(() => page.locator('[data-test=item-list] > div').count()).toBeGreaterThan(50)
})

test('adds an entire packet', async ({ page }) => {
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS')
  // Since we're checking count() which is instant we need to poll
  await expect.poll(() => page.locator('[data-test=item-list] > div').count()).toBeGreaterThan(10)
  // Ensure we didn't add the entire packet like above
  await expect.poll(() => page.locator('[data-test=item-list] > div').count()).toBeLessThan(50)
})

test('add, edits, deletes items', async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 })
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await utils.addTargetPacketItem('INST', 'ADCS', 'CCSDSVER')
  await utils.addTargetPacketItem('INST', 'ADCS', 'CCSDSTYPE')
  await utils.addTargetPacketItem('INST', 'ADCS', 'CCSDSSHF')
  await expect(page.locator('[data-test=item-list] > div')).toHaveCount(3)
  // Delete CCSDSVER by clicking Delete icon
  await page.locator('.v-list div:nth-child(1) .v-list-item div:nth-child(3) .v-icon').click()
  await expect(page.locator('[data-test=item-list] > div')).toHaveCount(2)
  // Delete CCSDSTYPE
  await page.locator('.v-list div:nth-child(1) .v-list-item div:nth-child(3) .v-icon').click()
  await expect(page.locator('[data-test=item-list] > div')).toHaveCount(1)
  // Edit CCSDSSHF
  await page.locator('[data-test=item-list] button').first().click()
  await page.locator('text=Value Type').click()
  await page.locator('text=RAW').click()
  await page.locator('button:has-text("CLOSE")').click()
  await page.locator('[data-test=item-list] >> text=INST - ADCS - CCSDSSHF + (RAW)')

  await utils.download(page, 'text=Process', function (contents) {
    const lines = contents.split('\n')
    expect(lines[0]).toContain('CCSDSSHF (RAW)')
    expect(lines[1]).not.toContain('FALSE')
    expect(lines[1]).toContain('0')
  })
})

test('edit all items', async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 })
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await utils.addTargetPacketItem('INST', 'ADCS')
  expect(await page.locator('[data-test=item-list] > div').count()).toBeGreaterThan(20)
  await page.locator('[data-test=editAll]').click()
  await page.locator('text=Value Type').click()
  await page.locator('text=RAW').click()
  await page.locator('button:has-text("Ok")').click()
  // Spot check a few items ... they have all changed to (RAW)
  await page.locator('[data-test=item-list] >> text=INST - ADCS - CCSDSSHF + (RAW)')
  await page.locator('[data-test=item-list] >> text=INST - ADCS - POSX + (RAW)')
  await page.locator('[data-test=item-list] >> text=INST - ADCS - VELX + (RAW)')
  await page.locator('[data-test=item-list] >> text=INST - ADCS - Q1 + (RAW)')
})

test('processes commands', async ({ page }) => {
  // Preload an ABORT command
  await page.goto('/tools/cmdsender/INST/ABORT')
  await page.locator('[data-test=select-send]').click()
  await page.locator('text=cmd("INST ABORT") sent')
  expect(await page.inputValue('[data-test=sender-history]')).toMatch('cmd("INST ABORT")')

  const start = sub(new Date(), { minutes: 5 })
  await page.goto('/tools/dataextractor')
  await page.locator('.v-app-bar__nav-icon').click()
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await page.locator('label:has-text("Command")').click()
  await utils.sleep(500) // Allow the command to switch
  await utils.addTargetPacketItem('INST', 'ABORT', 'RECEIVED_TIMEFORMATTED')
  await utils.download(page, 'text=Process', function (contents) {
    const lines = contents.split('\n')
    expect(lines[1]).toContain('INST')
    expect(lines[1]).toContain('ABORT')
  })
})

test('creates CSV output', async ({ page }) => {
  const start = sub(new Date(), { minutes: 3 })
  await page.locator('[data-test=data-extractor-file]').click()
  await page.locator('text=Comma Delimited').click()
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')

  await utils.download(page, 'text=Process', function (contents) {
    expect(contents).toContain('NaN')
    expect(contents).toContain('Infinity')
    expect(contents).toContain('-Infinity')
    var lines = contents.split('\n')
    expect(lines[0]).toContain('TEMP1')
    expect(lines[0]).toContain('TEMP2')
    expect(lines[0]).toContain(',') // csv
    expect(lines.length).toBeGreaterThan(170) // 3 min at 60Hz is 180 samples
  })
})

test('creates tab delimited output', async ({ page }) => {
  const start = sub(new Date(), { minutes: 3 })
  await page.locator('[data-test=data-extractor-file]').click()
  await page.locator('text=Tab Delimited').click()
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')

  await utils.download(page, 'text=Process', function (contents) {
    var lines = contents.split('\n')
    expect(lines[0]).toContain('TEMP1')
    expect(lines[0]).toContain('TEMP2')
    expect(lines[0]).toContain('\t') // tab delimited
    expect(lines.length).toBeGreaterThan(170) // 3 min at 60Hz is 180 samples
  })
})

test('outputs full column names', async ({ page }) => {
  let start = sub(new Date(), { minutes: 1 })
  await page.locator('[data-test=data-extractor-mode]').click()
  await page.locator('text=Full Column Names').click()
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')

  await utils.download(page, 'text=Process', function (contents) {
    var lines = contents.split('\n')
    expect(lines[0]).toContain('INST HEALTH_STATUS TEMP1')
    expect(lines[0]).toContain('INST HEALTH_STATUS TEMP2')
  })
  await utils.sleep(1000)

  // Switch back and verify
  await page.locator('[data-test=data-extractor-mode]').click()
  await page.locator('text=Normal Columns').click()
  // Create a new end time so we get a new filename
  start = sub(new Date(), { minutes: 2 })
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await utils.download(page, 'text=Process', function (contents) {
    expect(contents).toContain('TARGET,PACKET,TEMP1,TEMP2')
  })
})

test('fills values', async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 })
  await page.locator('[data-test=data-extractor-mode]').click()
  await page.locator('text=Fill Down').click()
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  // Deliberately test with two different packets
  await utils.addTargetPacketItem('INST', 'ADCS', 'CCSDSSEQCNT')
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSSEQCNT')

  await utils.download(page, 'text=Process', function (contents) {
    var lines = contents.split('\n')
    expect(lines[0]).toContain('CCSDSSEQCNT')
    var firstHS = -1
    for (let i = 1; i < lines.length; i++) {
      if (firstHS !== -1) {
        var [tgt1, pkt1, hs1, adcs1] = lines[firstHS].split(',')
        var [tgt2, pkt2, hs2, adcs2] = lines[i].split(',')
        expect(tgt1).toEqual(tgt2) // Both INST
        expect(pkt1).toEqual('HEALTH_STATUS')
        expect(pkt2).toEqual('ADCS')
        expect(parseInt(adcs1) + 1).toEqual(parseInt(adcs2)) // ADCS goes up by one each time
        expect(parseInt(hs1)).toBeGreaterThan(1) // Double check for a value
        expect(hs1).toEqual(hs2) // HEALTH_STATUS should be the same
        break
      } else if (lines[i].includes('HEALTH_STATUS')) {
        // Look for the first line containing HEALTH_STATUS
        // console.log("Found first HEALTH_STATUS on line " + i);
        firstHS = i
      }
    }
  })
})

test('adds Matlab headers', async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 })
  await page.locator('[data-test=data-extractor-mode]').click()
  await page.locator('text=Matlab Header').click()
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await utils.addTargetPacketItem('INST', 'ADCS', 'Q1')
  await utils.addTargetPacketItem('INST', 'ADCS', 'Q2')

  await utils.download(page, 'text=Process', function (contents) {
    expect(contents).toContain('% TARGET,PACKET,Q1,Q2') // % is matlab
  })
})

test('outputs unique values only', async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 })
  await page.locator('[data-test=data-extractor-mode]').click()
  await page.locator('text=Unique Only').click()
  await page.locator('[data-test=start-time]').fill(format(start, 'HH:mm:ss'))
  await utils.addTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSVER')

  await utils.download(page, 'text=Process', function (contents) {
    var lines = contents.split('\n')
    expect(lines[0]).toContain('CCSDSVER')
    expect(lines.length).toEqual(2) // header and a single value
  })
})
