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
  await page.goto('/tools/tablemanager')
  await expect(page.locator('.v-app-bar')).toContainText('Table Manager')
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page)
})

//
// Test the File menu
//
test('creates a binary file', async ({ page }) => {
  await page.locator('[data-test=table-manager-file]').click()
  await page.locator('text=New').click()
  await page.locator('[data-test=file-open-save-search]').type('MCConfig')
  await page.locator('text=MCConfigurationTable >> nth=0').click() // nth=0 because INST, INST2
  await page.locator('[data-test=file-open-save-submit-btn]').click()
  await expect(page.locator('id=cosmos-tool')).toContainText('MC_CONFIGURATION')
  expect(await page.locator('.v-tab').count()).toBe(1)
  await expect(page.locator(['[data-test=definitionFilename]']).inputValue()).toMatch(
    'INST/tables/config/MCConfigurationTable_def.txt'
  )
  await expect(page.locator(['[data-test=filename]']).inputValue()).toMatch(
    'INST/tables/bin/MCConfigurationTable.bin'
  )
})

test('opens a binary file', async ({ page }) => {
  await page.locator('[data-test=table-manager-file]').click()
  await page.locator('text=Open').click()
  await page.locator('[data-test=file-open-save-search]').type('ConfigTables.bin')
  await page.locator('text=ConfigTables >> nth=0').click()
  await page.locator('[data-test=file-open-save-submit-btn]').click()
  await expect(page.locator('id=cosmos-tool')).toContainText('MC_CONFIGURATION')
  await expect(page.locator('id=cosmos-tool')).toContainText('TLM_MONITORING')
  await expect(page.locator('id=cosmos-tool')).toContainText('PPS_SELECTION')
  expect(await page.locator('.v-tab').count()).toBe(3)
  await expect(page.locator(['[data-test=definitionFilename]']).inputValue()).toMatch(
    'INST/tables/config/ConfigTables_def.txt'
  )
  await expect(page.locator(['[data-test=filename]']).inputValue()).toMatch(
    'INST/tables/bin/ConfigTables.bin'
  )

  // Test searching
  expect(await page.locator('tr').count()).toBe(12)
  await page.locator('div label:text("Search") input').fill('UNEDIT')
  await expect.poll(() => page.locator('tr').count()).toBe(4)

  // cy.get('div label').contains('Search').siblings('input').as('search')
  // cy.get('@search').type('UNEDIT')
  // cy.get('tr').should('have.length', 4)
  // // TODO would be fun to test that these are disabled
  // // cy.get('tr').each(($el, index, $list) => {
  // //   // Need to get the 'tr td div'
  // //   expect($el).to.have.class('v-input--is-disabled')
  // // })
  // cy.get('@search').clear()
  // cy.get('tr').should('have.length', 12)
})
