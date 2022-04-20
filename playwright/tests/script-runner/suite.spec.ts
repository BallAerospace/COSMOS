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
import { Utilities } from '../../utilities'

let utils
test.beforeEach(async ({ page }) => {
  await page.goto('/tools/scriptrunner')
  await expect(page.locator('.v-app-bar')).toContainText('Script Runner')
  await page.locator('.v-app-bar__nav-icon').click()
  // Close the dialog that says how many running scripts there are
  if (await page.$('text=Enter the password')) {
    await page.locator('button:has-text("Close")').click()
  }
  utils = new Utilities(page)
})

async function saveAs(page, filename: string) {
  await page.locator('[data-test=Script Runner-File]').click()
  await page.locator('text=Save As...').click()
  await page.locator('[data-test=file-open-save-filename]').fill(`INST/procedures/${filename}`)
  await page.locator('[data-test=file-open-save-submit-btn]').click()
  // It can take a bit for the suite to parse and render so give extra time
  await expect(page.locator('[data-test=start-suite]')).toBeVisible({
    timeout: 10000,
  })
  expect(await page.locator('#sr-controls')).toContainText(`INST/procedures/${filename}`)
}

async function deleteFile(page) {
  await page.locator('[data-test=Script Runner-File]').click()
  await page.locator('text=Delete File').click()
  await page.locator('button:has-text("Delete")').click()
}

// Run by clicking on the passed startLocator and then wait for the results dialog
// Call the checker function to verify the textarea has the desired results
// and finally click OK to close the dialog
async function runAndCheckResults(page, startLocator, validator, download = false) {
  await page.locator(startLocator).click()
  // After script starts the Script Start/Go and all Suite buttons should be disabled
  await expect(page.locator('[data-test=start-suite]')).toBeDisabled()
  await expect(page.locator('[data-test=start-group]')).toBeDisabled()
  await expect(page.locator('[data-test=start-script]')).toBeDisabled()
  await expect(page.locator('[data-test=setup-suite]')).toBeDisabled()
  await expect(page.locator('[data-test=setup-group]')).toBeDisabled()
  await expect(page.locator('[data-test=teardown-suite]')).toBeDisabled()
  await expect(page.locator('[data-test=teardown-group]')).toBeDisabled()
  // Wait for the results ... allow for additional time
  await expect(page.locator('.v-dialog')).toContainText('Script Results', {
    timeout: 30000,
  })
  // Allow the caller to validate the results
  validator(await page.inputValue('.v-dialog >> textarea'))

  // Downloading the report is additional processing so we make it optional
  if (download) {
    await utils.download(page, 'button:has-text("Download")', function (contents) {
      expect(contents).toContain('Test Report')
      validator(contents)
    })
  }
  await page.locator('button:has-text("Ok")').click()
}

test('loads Suite controls when opening a suite', async ({ page }) => {
  // Open the file
  await page.locator('[data-test=Script Runner-File]').click()
  await page.locator('text=Open File').click()
  await utils.sleep(1000)
  await page.locator('[data-test=file-open-save-search]').type('my_script_')
  await utils.sleep(500)
  await page.locator('[data-test=file-open-save-search]').type('suite')
  await page.locator('text=script_suite >> nth=0').click() // nth=0 because INST, INST2
  await page.locator('[data-test=file-open-save-submit-btn]').click()
  expect(await page.locator('#sr-controls')).toContainText(`INST/procedures/my_script_suite.rb`)
  // Verify defaults in the Suite options
  await expect(page.locator('[data-test=pause-on-error]')).toBeChecked()
  await expect(page.locator('[data-test=manual]')).toBeChecked()
  await expect(page.locator('[data-test=continue-after-error]')).toBeChecked()
  await expect(page.locator('[data-test=loop]')).not.toBeChecked()
  await expect(page.locator('[data-test=abort-after-error]')).not.toBeChecked()
  await expect(page.locator('[data-test=break-loop-on-error]')).toBeDisabled()
  // Verify the drop downs are populated
  await expect(page.locator('div[role="button"]:has-text("MySuite")')).toBeEnabled()
  await expect(page.locator('div[role="button"]:has-text("ExampleGroup")')).toBeEnabled()
  await expect(page.locator('div[role="button"]:has-text("script_2")')).toBeEnabled()
  // // Verify Suite Start buttons are enabled
  await expect(page.locator('[data-test=start-suite]')).toBeEnabled()
  await expect(page.locator('[data-test=start-group]')).toBeEnabled()
  await expect(page.locator('[data-test=start-script]')).toBeEnabled()
  // Verify Script Start button is disabled
  await expect(page.locator('[data-test=start-button]')).toBeDisabled()

  // Verify Suite controls go away when loading a normal script
  await page.locator('[data-test=Script Runner-File]').click()
  await page.locator('text=Open File').click()
  await utils.sleep(1000)
  await page.locator('[data-test=file-open-save-search]').type('dis')
  await utils.sleep(500)
  await page.locator('[data-test=file-open-save-search]').type('connect')
  await page.locator('text=disconnect >> nth=0').click() // nth=0 because INST, INST2
  await page.locator('[data-test=file-open-save-submit-btn]').click()
  expect(await page.locator('#sr-controls')).toContainText(`INST/procedures/disconnect.rb`)
  await expect(page.locator('[data-test=start-suite]')).not.toBeVisible()
  await expect(page.locator('[data-test=start-group]')).not.toBeVisible()
  await expect(page.locator('[data-test=start-script]')).not.toBeVisible()
  await expect(page.locator('[data-test=setup-suite]')).not.toBeVisible()
  await expect(page.locator('[data-test=setup-group]')).not.toBeVisible()
  await expect(page.locator('[data-test=teardown-suite]')).not.toBeVisible()
  await expect(page.locator('[data-test=teardown-group]')).not.toBeVisible()
})

test('starts a suite', async ({ page }) => {
  await page.locator('textarea').fill(`
  load "cosmos/script/suite.rb"
  class TestGroup < Cosmos::Group
    def test_test; puts "test"; end
  end
  class TestSuite < Cosmos::Suite
    def setup; Cosmos::Group.puts("setup"); end
    def teardown; Cosmos::Group.puts("teardown"); end
    def initialize
      super()
      add_group("TestGroup")
    end
  end
  `)
  await saveAs(page, 'test_suite1.rb')

  // Verify the suite startup, teardown buttons are enabled
  await expect(page.locator('[data-test=setup-suite]')).toBeEnabled()
  await expect(page.locator('[data-test=teardown-suite]')).toBeEnabled()
  await runAndCheckResults(page, '[data-test=setup-suite]', function (textarea) {
    expect(textarea).toMatch('setup:PASS')
    expect(textarea).toMatch('Total Tests: 1')
    expect(textarea).toMatch('Pass: 1')
  })

  // Run suite teardown
  await runAndCheckResults(page, '[data-test=teardown-suite]', function (textarea) {
    expect(textarea).toMatch('teardown:PASS')
    expect(textarea).toMatch('Total Tests: 1')
    expect(textarea).toMatch('Pass: 1')
  })

  // Run suite
  await runAndCheckResults(
    page,
    '[data-test=start-suite]',
    function (textarea) {
      expect(textarea).toMatch('setup:PASS')
      expect(textarea).toMatch('teardown:PASS')
      expect(textarea).toMatch('Total Tests: 3')
      expect(textarea).toMatch('Pass: 3')
    },
    true
  )

  // Rewrite the script but remove setup and teardown
  await page.locator('.ace_content').click()
  await page.keyboard.press('Control+A')
  await page.keyboard.press('Backspace')
  await page.locator('textarea').fill(`
  load "cosmos/script/suite.rb"
  class TestGroup < Cosmos::Group
    def test_test; puts "test"; end
  end
  class TestSuite < Cosmos::Suite
    def initialize
      super()
      add_group("TestGroup")
    end
  end
  `)
  // Verify filename is marked as edited
  // TODO: Not implemented currently
  // expect(await page.locator('[data-test=filename]')).toContainText('*')
  await page.keyboard.press('Control+S')

  // Verify the suite startup, teardown buttons are disabled
  await expect(page.locator('[data-test=setup-suite]')).toBeDisabled()
  await expect(page.locator('[data-test=teardown-suite]')).toBeDisabled()

  await deleteFile(page)
})

test('starts a group', async ({ page }) => {
  await page.locator('textarea').fill(`
  load "cosmos/script/suite.rb"
  class TestGroup1 < Cosmos::Group
    def setup; Cosmos::Group.puts("setup"); end
    def teardown; Cosmos::Group.puts("teardown"); end
    def test_test1; puts "test"; end
  end
  class TestGroup2 < Cosmos::Group
    def test_test2; puts "test"; end
  end
  class TestSuite < Cosmos::Suite
    def initialize
      super()
      add_group("TestGroup1")
      add_group("TestGroup2")
    end
  end
  `)
  await saveAs(page, 'test_suite2.rb')

  // Verify the group startup, teardown buttons are enabled
  await expect(page.locator('[data-test=setup-group]')).toBeEnabled()
  await expect(page.locator('[data-test=teardown-group]')).toBeEnabled()
  await runAndCheckResults(page, '[data-test=setup-group]', function (textarea) {
    expect(textarea).toMatch('setup:PASS')
    expect(textarea).toMatch('Total Tests: 1')
    expect(textarea).toMatch('Pass: 1')
  })

  // Run group teardown
  await runAndCheckResults(page, '[data-test=teardown-group]', function (textarea) {
    expect(textarea).toMatch('teardown:PASS')
    expect(textarea).toMatch('Total Tests: 1')
    expect(textarea).toMatch('Pass: 1')
  })

  // Run group
  await runAndCheckResults(page, '[data-test=start-group]', function (textarea) {
    expect(textarea).toMatch('setup:PASS')
    expect(textarea).toMatch('teardown:PASS')
    expect(textarea).toMatch('Total Tests: 3')
    expect(textarea).toMatch('Pass: 3')
  })

  // Rewrite the script but remove setup and teardown
  await page.locator('.ace_content').click()
  await page.keyboard.press('Control+A')
  await page.keyboard.press('Backspace')
  await page.locator('textarea').fill(`
  load "cosmos/script/suite.rb"
  class TestGroup1 < Cosmos::Group
    def test_test1; puts "test"; end
  end
  class TestGroup2 < Cosmos::Group
    def test_test2; puts "test"; end
  end
  class TestSuite < Cosmos::Suite
    def initialize
      super()
      add_group("TestGroup1")
      add_group("TestGroup2")
    end
  end
  `)
  // Verify filename is marked as edited
  // TODO: Not implemented currently
  // expect(await page.locator('[data-test=filename]')).toContainText('*')
  await page.keyboard.press('Control+S')

  // Verify the group startup, teardown buttons are disabled
  await expect(page.locator('[data-test=setup-group]')).toBeDisabled()
  await expect(page.locator('[data-test=teardown-group]')).toBeDisabled()

  await deleteFile(page)
})

test('starts a script', async ({ page }) => {
  await page.locator('textarea').fill(`
  load "cosmos/script/suite.rb"
  class TestGroup < Cosmos::Group
    def test_test1; puts "test1"; end
    def test_test2; puts "test2"; end
  end
  class TestSuite < Cosmos::Suite
    def initialize
      super()
      add_group("TestGroup")
    end
  end
  `)
  await saveAs(page, 'test_suite3.rb')
  // Run script
  await runAndCheckResults(page, '[data-test=start-script]', function (textarea) {
    expect(textarea).toMatch('test1')
    expect(textarea).toMatch('Total Tests: 1')
    expect(textarea).toMatch('Pass: 1')
  })
  await deleteFile(page)
})

test('handles manual mode', async ({ page }) => {
  await page.locator('textarea').fill(`
  load "cosmos/script/suite.rb"
  class TestGroup < Cosmos::Group
    def test_test1; Cosmos::Group.puts "manual1" if $manual; end
    def test_test2; Cosmos::Group.puts "manual2" unless $manual; end
  end
  class TestSuite < Cosmos::Suite
    def initialize
      super()
      add_group("TestGroup")
    end
  end
  `)
  await saveAs(page, 'test_suite4.rb')

  // Run group
  await runAndCheckResults(page, '[data-test=start-group]', function (textarea) {
    expect(textarea).toMatch('Manual = true')
    expect(textarea).toMatch('manual1')
    expect(textarea).not.toMatch('manual2')
    expect(textarea).toMatch('Total Tests: 2')
    expect(textarea).toMatch('Pass: 2')
  })
  await page.locator('label:has-text("Manual")').click() // uncheck Manual
  // Run group
  await runAndCheckResults(page, '[data-test=start-group]', function (textarea) {
    expect(textarea).toMatch('Manual = false')
    expect(textarea).not.toMatch('manual1')
    expect(textarea).toMatch('manual2')
    expect(textarea).toMatch('Total Tests: 2')
    expect(textarea).toMatch('Pass: 2')
  })
  await deleteFile(page)
})
