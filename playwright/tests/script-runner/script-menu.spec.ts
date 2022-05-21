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
import { format } from 'date-fns'
import { Utilities } from '../../utilities'

test.beforeEach(async ({ page }) => {
  await page.goto('/tools/scriptrunner')
  await expect(page.locator('.v-app-bar')).toContainText('Script Runner')
  await page.locator('.v-app-bar__nav-icon').click()
  // Close the dialog that says how many running scripts there are
  await page.locator('button:has-text("Close")').click()
})

test('view started scripts', async ({ page }) => {
  const utils = new Utilities(page)
  // Have to fill on an editable area like the textarea
  await page.locator('textarea').fill(`
  puts "now we wait"
  wait
  puts "now we're done"
  `)
  // NOTE: We can't check that there are no running scripts because
  // the tests run in parallel and there actually could be running scripts

  // Start the script
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('waiting', {
    timeout: 20000,
  })
  // Traverse up to get the name of the running script
  const filename = await page.locator('[data-test=filename]').locator('xpath=../div').textContent()

  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text="View Started Scripts"').click()
  await utils.sleep(1000)
  // Each section has a Refresh button so click the first one
  await page.locator('button:has-text("Refresh")').first().click()
  await expect(page.locator('[data-test=running-scripts]')).toContainText(
    format(new Date(), 'yyyy_MM_dd')
  )

  // Get out of the Running Scripts sheet
  await page.locator('#cosmos-menu >> text=Script Runner').click({ force: true })
  await page.locator('[data-test=go-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped')
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text="View Started Scripts"').click()
  await utils.sleep(1000)
  await page.locator('button:has-text("Refresh")').first().click()
  await expect(page.locator('[data-test=running-scripts]')).not.toContainText(filename)
  await page.locator('button:has-text("Refresh")').nth(1).click()
  await expect(page.locator('[data-test=completed-scripts]')).toContainText(filename)
})

test('sets environment variables', async ({ page }) => {
  await page.locator('textarea').fill(`puts "ENV:#{ENV['KEY']}"`)
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Show Environment').click()
  await page.locator('[data-test=env-key]').fill('KEY')
  await page.locator('[data-test=env-value]').fill('VALUE')
  await page.locator('[data-test=add-env]').click()
  await page.locator('#cosmos-menu >> text=Script Runner').click({ force: true })

  await page.locator('[data-test=env-button]').click()
  await page.locator('div[role="button"]:has-text("Select Environment Options")').click()
  await page.locator('div[role="option"]:has-text("KEY=VALUE")').click()
  await page.locator('[data-test=environment-dialog-save]').click()

  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped', {
    timeout: 20000,
  })
  await expect(page.locator('[data-test=output-messages]')).toContainText('ENV:VALUE')
  await page.locator('[data-test=clear-log]').click()
  await page.locator('button:has-text("Clear")').click()
  await expect(page.locator('[data-test=output-messages]')).not.toContainText('ENV:VALUE')
  // Re-run and ensure the env vars are still set
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('[data-test=state]')).toHaveValue('stopped', {
    timeout: 20000,
  })
  await expect(page.locator('[data-test=output-messages]')).toContainText('ENV:VALUE')
})

test('sets metadata', async ({ page }) => {
  await page.locator('textarea').fill(`
  puts get_metadata()
  set_metadata({ 'setkey' => 1 })
  result = get_metadata()
  puts result
  update_metadata(result['start'], { 'setkey' => 2, 'updatekey' => 3 })
  puts get_metadata()
  input_metadata()
  puts get_metadata()
  `)
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Show Metadata').click()
  await page.locator('[data-test=new-metadata-icon]').click()
  await page.keyboard.press('Tab')
  await page.keyboard.type('metakey')
  await page.keyboard.press('Tab')
  await page.keyboard.type('metaval')
  await page.locator('[data-test=metadata-dialog-save]').click()

  await page.locator('[data-test=start-button]').click()
  await expect(page.locator('.v-dialog')).toBeVisible({
    timeout: 20000,
  })
  await page.locator('[data-test=new-metadata-icon]').click()
  // key is 0 based and we should already have 2 entries
  await page.locator('[data-test=key-2]').click()
  await page.keyboard.type('inputkey')
  await page.keyboard.press('Tab')
  await page.keyboard.type('inputvalue')
  await page.locator('[data-test=metadata-dialog-save]').click()

  await expect(page.locator('[data-test=state]')).toHaveValue('stopped', {
    timeout: 20000,
  })
  await expect(page.locator('[data-test=output-messages]')).toContainText('"setkey"=>1')
  await expect(page.locator('[data-test=output-messages]')).toContainText('"setkey"=>2')
  await expect(page.locator('[data-test=output-messages]')).toContainText('"updatekey"=>3')
  await expect(page.locator('[data-test=output-messages]')).toContainText(
    '"inputkey"=>"inputvalue"'
  )
})

test('ruby syntax check', async ({ page }) => {
  await page.locator('textarea').fill('puts "TEST"')
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Ruby Syntax Check').click()
  await expect(page.locator('.v-dialog')).toContainText('Syntax OK')
  await page.locator('.v-dialog >> button').click()

  await page.locator('textarea').fill(`
  puts "MORE"
  if true
  puts "TRUE"
  `)
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Ruby Syntax Check').click()
  await expect(page.locator('.v-dialog')).toContainText('syntax error')
  await page.locator('.v-dialog >> button').click()
})

test('mnemonic check', async ({ page }) => {
  await page.locator('textarea').fill(`
  cmd("INST ABORT")
  `)
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Mnemonic Check').click()
  await expect(page.locator('.v-dialog')).toContainText('Everything looks good!')
  await page.locator('button:has-text("Ok")').click()

  await page.locator('textarea').fill(`
  cmd("BLAH ABORT")
  cmd("INST ABORT with ANGER")
  `)
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=Mnemonic Check').click()
  await expect(page.locator('.v-dialog')).toContainText('Target "BLAH" does not exist')
  await expect(page.locator('.v-dialog')).toContainText(
    'Command "INST ABORT" param "ANGER" does not exist'
  )
  await page.locator('button:has-text("Ok")').click()
})

test('view instrumented script', async ({ page }) => {
  await page.locator('textarea').fill('puts "HI"')
  await page.locator('[data-test=script-runner-script]').click()
  await page.locator('text=View Instrumented Script').click()
  await expect(page.locator('.v-dialog')).toContainText('binding')
  await page.locator('button:has-text("Ok")').click()
})

// Remaining menu items tested in other script-runner tests
