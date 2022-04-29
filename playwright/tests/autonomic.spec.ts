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
  await expect(page.locator('.v-app-bar')).toContainText('Autonomic')
  await page.locator('.v-app-bar__nav-icon').click()
}

test('test overview page create trigger group', async ({ page }) => {
  await openPage(page, 'overview')
  // groups
  await utils.download(page, '[data-test="group-download"]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
  // Open dialog and cancel and do not create the trigger group
  await page.locator('[data-test=new-group]').click()
  await page.locator('[data-test=group-input-name]').fill('Alpha')
  await page.locator('[data-test=group-create-cancel-btn]').click()
  // Open dialog and create the trigger group
  await page.locator('[data-test=new-group]').click()
  await page.locator('[data-test=group-input-name]').fill('Alpha')
  await page.locator('[data-test=group-create-submit-btn]').click()
  // events
  await page.locator('[data-test=events-clear]').click()
  await page.locator('[data-test=confirm-dialog-clear]').click()
  await utils.download(page, '[data-test=events-download]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
})

test('test trigger page', async ({ page }) => {
  await openPage(page, 'triggers')
  // download json of triggers
  await utils.download(page, '[data-test=trigger-download]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
  // Open dialog and cancel and do not create the trigger
  await page.locator('[data-test=new-trigger]').click()
  // select FLOAT as operand
  await page.locator('[data-test=trigger-operand-left-type]').click()
  await page
    .locator('[data-test=trigger-operand-left-type-FLOAT] div:has-text("FLOAT")')
    .first()
    .click()
  await page.locator('[data-test=trigger-operand-left-float]').fill('12345')
  // reset
  await page.locator('[data-test=trigger-create-reset-icon]').click()
  // select STRING as operand
  await page.locator('[data-test=trigger-operand-left-type]').click()
  await page.locator('[data-test=trigger-operand-left-type-STRING]').click()
  await page.locator('[data-test=trigger-operand-left-string]').fill('This should be a string')
  // reset
  await page.locator('[data-test=trigger-create-reset-icon]').click()
  // select LIMIT as operand
  await page.locator('[data-test=trigger-operand-left-type]').click()
  await page.locator('[data-test=trigger-operand-left-type-LIMIT]').click()
  await page.locator('[data-test=trigger-operand-left-color]').click()
  await page.locator('[data-test=trigger-operand-left-color-YELLOW]').click()
  await page.locator('[data-test=trigger-operand-left-limit]').click()
  await page.locator('[data-test=trigger-operand-left-limit-LOW]').click()
  // reset
  await page.locator('[data-test=trigger-create-reset-icon]').click()
  // select ITEM as operand
  await page.locator('[data-test=trigger-operand-left-type]').click()
  await page.locator('[data-test=trigger-operand-left-type-ITEM]').click()
  // STEP 2
  await page.locator('[data-test=trigger-create-step-two-btn]').click()
  // select FLOAT as right operand
  await page.locator('[data-test=trigger-operand-right-type]').click()
  await page
    .locator('[data-test=trigger-operand-right-type-FLOAT] div:has-text("FLOAT")')
    .first()
    .click()
  await page.locator('[data-test=trigger-operand-right-float]').fill('0')
  // STEP 3
  await page.locator('[data-test=trigger-create-step-three-btn]').click()
  //
  await page.locator('[data-test=trigger-create-select-operator]').click()
  // QUOTES REQUIRED else the ">" will not be selected
  await page.locator('[data-test="trigger-create-select-operator->"]').click()
  //
  await page.locator('[data-test=trigger-create-submit-btn]').click()
  await utils.sleep(100)
})

test('test reactions page', async ({ page }) => {
  await openPage(page, 'reactions')
  // download json of reactions
  await utils.download(page, '[data-test=reaction-download]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
  //
  await page.locator('[data-test=new-reaction]').click()
  await page.locator('[data-test=reaction-select-triggers]').click()
  await page.locator('[data-test=reaction-select-trigger-0]').click()
  //
  await page.locator('[data-test=reaction-create-step-two-btn]').click()
  //
  await page.locator('div[role="radiogroup"] div:has-text("Command")').click()
  await page.locator('[data-test=reaction-action-command]').fill('FOO CLEAR')
  // Add the action to the reaction
  await page.locator('[data-test=reaction-action-add-action-btn]').click()
  // Remove the action
  await page.locator('[data-test=reaction-action-remove-0]').click()
  //
  await page.locator('div[role="radiogroup"] div:has-text("Command")').click()
  await page.locator('[data-test=reaction-action-command]').fill('INST CLEAR')
  // Add the action to the reaction
  await page.locator('[data-test=reaction-action-add-action-btn]').click()
  //
  await page.locator('[data-test=reaction-create-step-three-btn]').click()
  //
  await page.locator('[data-test=reaction-snooze-input]').fill('333')
  await page.locator('[data-test=reaction-description-input]').fill('INST CLEAR on Alpha Trigger')
  //
  await page.locator('[data-test=reaction-create-submit-btn]').click()
  await utils.sleep(100)
})

test('test reaction card actions', async ({ page }) => {
  await openPage(page, 'reactions')
  //
  await utils.sleep(100)
  await page.locator('[data-test=reaction-deactivate-icon-0]').click()
  await utils.sleep(100)
  await page.locator('[data-test=reaction-activate-icon-0]').click()
  await utils.sleep(100)
  await page.locator('[data-test=reaction-delete-icon-0]').click()
  await utils.sleep(100)
})

test('test trigger card actions', async ({ page }) => {
  await openPage(page, 'triggers')
  //
  await utils.sleep(100)
  await page.locator('[data-test=trigger-deactivate-icon-0]').click()
  await utils.sleep(100)
  await page.locator('[data-test=trigger-activate-icon-0]').click()
  await utils.sleep(100)
  await page.locator('[data-test=trigger-delete-icon-0]').click()
  await utils.sleep(100)
})

test('test overview page delete trigger group', async ({ page }) => {
  await openPage(page, 'overview')
  // Delete trigger group and press cancel
  await page.locator('[data-test=delete-group-0]').click()
  await page.locator('[data-test=confirm-dialog-cancel]').click()
  // Delete trigger group and press delete
  await page.locator('[data-test=delete-group-0]').click()
  await page.locator('[data-test=confirm-dialog-delete]').click()
  //
  await utils.sleep(100)
  // groups
  await utils.download(page, '[data-test="group-download"]', function (contents) {
    expect(contents).toContain('[]') // % is empty array
  })
})
