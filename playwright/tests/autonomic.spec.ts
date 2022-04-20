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
  utils = new Utilities(page)
})

async function openPage(page, name) {
  await page.goto(`/tools/autonomic/${name}`)
  await expect(page.locator('body')).toContainText('Autonomic')
  await page.locator('.v-app-bar__nav-icon').click()
}

test('test overview page create trigger group', async ({ page }) => {
  await openPage(page, 'overview')
  // groups
  await utils.download(page, '[data-test="group-download"]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
  // Open dialog and cancel and do not create the trigger group
  await page.locator('[data-test="new-group"]').click()
  await page.locator('[data-test="group-input-name"]').fill('Alpha')
  await page.locator('[data-test="group-create-cancel-btn"]').click()
  // Open dialog and create the trigger group
  await page.locator('[data-test="new-group"]').click()
  await page.locator('[data-test="group-input-name"]').fill('Alpha')
  await page.locator('[data-test="group-create-submit-btn"]').click()
  // events
  await page.locator('[data-test="events-clear"]').click()
  await page.locator('[data-test="confirm-dialog-clear"]').click()
  await utils.download(page, '[data-test="events-download"]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
})

test('test trigger page', async ({ page }) => {
  await openPage(page, 'triggers')
    // download json of triggers
  await utils.download(page, '[data-test="trigger-download"]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
  // Open dialog and cancel and do not create the trigger
  await page.locator('[data-test="new-trigger"]').click()
  // select ITEM as operand
  await page.locator('[data-test="trigger-operand-left-type"]').click()
  await page.locator('[data-test="trigger-operand-left-type-ITEM"]').click()
  // reset
  await page.locator('[data-test="trigger-create-reset-icon"]').click();
  // select FLOAT as operand
  await page.locator('[data-test="trigger-operand-left-type"]').click()
  await page.locator('[data-test="trigger-operand-left-type-FLOAT"] div:has-text("FLOAT")').first().click();
  // reset
  await page.locator('[data-test="trigger-create-reset-icon"]').click();
  // select STRING as operand
  await page.locator('[data-test="trigger-operand-left-type"]').click()
  await page.locator('[data-test="trigger-operand-left-type-STRING"]').click()
  // reset
  await page.locator('[data-test="trigger-create-reset-icon"]').click();
  // select LIMIT as operand
  await page.locator('[data-test="trigger-operand-left-type"]').click()
  await page.locator('[data-test="trigger-operand-left-type-LIMIT"]').click()
  await page.locator('[data-test="trigger-operand-left-color-RED"]').click();
})

test('test reactions page', async ({ page }) => {
  await openPage(page, 'reactions')
    // download json of reactions
  await utils.download(page, '[data-test="reaction-download"]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
  // Open dialog and cancel and do not create the trigger
  await page.locator('[data-test="new-reaction"]').click()
})

test('test overview page delete trigger group', async ({ page }) => {
  await openPage(page, 'overview')
  // Delete trigger group and press cancel
  await page.locator('[data-test="delete-group-0"]').click()
  await page.locator('[data-test="confirm-dialog-cancel"]').click()
  // Delete trigger group and press delete
  await page.locator('[data-test="delete-group-0"]').click()
  await page.locator('[data-test="confirm-dialog-delete"]').click()
})