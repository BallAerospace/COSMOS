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
import { Utilities } from '../../utilities'

let utils
test.beforeEach(async ({ page }) => {
  await page.goto('/tools/cmdtlmserver/cmd-packets')
  await expect(page.locator('.v-app-bar')).toContainText('CmdTlmServer')
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page)
})

test('displays the list of command', async ({ page }) => {
  // When we ask for just text there are no spaces
  await expect(page.locator('text=INSTABORT')).toBeVisible()
  await expect(page.locator('text=INSTCLEAR')).toBeVisible()
  await expect(page.locator('text=INSTCOLLECT')).toBeVisible()
  await expect(page.locator('text=EXAMPLESTART')).toBeVisible()
})

test('displays the command count', async ({ page }) => {
  await expect(page.locator('text=INSTCOLLECT')).toBeVisible()
  expect(
    parseInt(await page.locator('text=INSTCOLLECT >> td >> nth=2').textContent())
  ).toBeGreaterThan(0)
})

test('displays a raw command', async ({ page }) => {
  await expect(page.locator('text=INSTCOLLECT')).toBeVisible()
  await page.locator('text=INSTCOLLECT >> td >> nth=3').click()
  await expect(page.locator('.v-dialog')).toContainText('Raw Command Packet: INST COLLECT')
  await expect(page.locator('.v-dialog')).toContainText('Received Time:')
  await expect(page.locator('.v-dialog')).toContainText('Count:')
  expect(await page.inputValue('.v-dialog textarea')).toMatch('Address')
  expect(await page.inputValue('.v-dialog textarea')).toMatch('00000000:')

  await utils.download(page, '[data-test=download]', function (contents) {
    expect(contents).toMatch('Raw Command Packet: INST COLLECT')
    expect(contents).toMatch('Received Time:')
    expect(contents).toMatch('Count:')
    expect(contents).toMatch('Address')
    expect(contents).toMatch('00000000:')
  })
  await page.locator('.v-dialog').press('Escape')
  await expect(page.locator('.v-dialog')).not.toBeVisible()
})

test('links to command sender', async ({ page }) => {
  await expect(page.locator('text=INSTCOLLECT')).toBeVisible()
  const [newPage] = await Promise.all([
    page.context().waitForEvent('page'),
    await page.locator('text=INSTCOLLECT >> td >> nth=4').click(),
  ])
  await expect(newPage.locator('.v-app-bar')).toContainText('Command Sender', { timeout: 30000 })
  await expect(newPage.locator('id=openc3-tool')).toContainText(
    'Starts a collect on the INST target'
  )
})
