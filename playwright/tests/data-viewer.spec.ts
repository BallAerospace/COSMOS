// @ts-check
import { test, expect } from "playwright-test-coverage";
import { Utilities } from "../utilities";
import * as fs from "fs";

let utils;
test.beforeEach(async ({ page }) => {
  await page.goto("/tools/dataviewer");
  await expect(page.locator("body")).toContainText("Data Viewer");
  await page.locator(".v-app-bar__nav-icon").click();
  utils = new Utilities(page);
});

test("loads and saves the configuration", async ({ page }) => {
  // Setup a tab
  await page.locator('[data-test="new-tab"]').click();
  await page.locator('text=New Tab').click({
    button: 'right'
  });
  await page.locator('[data-test="context-menu-rename"]').click();
  await page.locator('[data-test="rename-tab-input"]').fill('Test1');
  await page.locator('[data-test="rename"]').click();
  await page.locator('[data-test=new-packet]').click()
  await utils.selectTargetPacketItem('INST', 'ADCS')
  await page.locator('[data-test="add-packet-button"]').click();

  // Setup another tab
  await page.locator('[data-test="new-tab"]').click();
  await page.locator('text=New Tab').click({
    button: 'right'
  });
  await page.locator('[data-test="context-menu-rename"]').click();
  await page.locator('[data-test="rename-tab-input"]').fill('Test2');
  await page.locator('[data-test="rename"]').click();
  await page.locator('div[role="tab"]:has-text("Test2")').click();
  // Get the last data-test=new-packet (on the new tab)
  await page.locator('[data-test=new-packet] >> nth=-1').click()
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS')
  await page.locator('[data-test="add-packet-button"]').click();

  let config = "spec" + Math.floor(Math.random() * 10000);
  await page.locator('[data-test="Data\\ Viewer-File"]').click();
  await page.locator("text=Save Configuration").click();
  await page
    .locator('[data-test="name-input-save-config-dialog"]')
    .fill(config);
  await page.locator('button:has-text("Ok")').click();

  // Reload page
  await page.reload()
  // Verify the config automatically comes back
  await page.locator('div[role="tab"]:has-text("Test1")').click();
  await expect(page.locator('text=INST ADCS')).toBeVisible();
  await page.locator('div[role="tab"]:has-text("Test2")').click();
  await expect(page.locator('text=INST HEALTH_STATUS')).toBeVisible();

  // Delete the tabs
  await page.locator('div[role="tab"]:has-text("Test1")').click({
    button: 'right'
  });
  await page.locator('[data-test="context-menu-delete"]').click();
  await page.locator('div[role="tab"]:has-text("Test2")').click({
    button: 'right'
  });
  await page.locator('[data-test="context-menu-delete"]').click();

  await page.locator('[data-test="Data\\ Viewer-File"]').click();
  await page.locator("text=Open Configuration").click();
  await page.locator(`td:has-text("${config}")`).click();
  await page.locator('button:has-text("Ok")').click();

  // Verify the config again
  await page.locator('div[role="tab"]:has-text("Test1")').click();
  await expect(page.locator('text=INST ADCS')).toBeVisible();
  await page.locator('div[role="tab"]:has-text("Test2")').click();
  await expect(page.locator('text=INST HEALTH_STATUS')).toBeVisible();

  // Delete this test configuation
  await page.locator('[data-test="Data\\ Viewer-File"]').click();
  await page.locator("text=Open Configuration").click();
  // Note: Only works if you don't have any other configs saved
  await page.locator('[data-test="item-delete"]').click();
  await page.locator('button:has-text("Delete")').click();
  await page.locator('[data-test="open-config-cancel-btn"]').click();
});

test('adds a raw packet to a new tab', async ({ page }) => {
  await page.locator('[data-test=new-tab]').click()
  await page.locator('[data-test=new-packet]').click()
  await utils.selectTargetPacketItem('INST', 'ADCS')
  await page.locator('[data-test=add-packet-button]').click()
  await page.locator('[data-test=start-button]').click()
  await utils.sleep(500)
  expect(await page.inputValue('[data-test=dump-component-text-area]')).toMatch('00000010:')
  expect(await page.inputValue('[data-test=dump-component-text-area]')).toMatch('00000020:')
})

test('adds a decom packet to a new tab', async ({ page }) => {
  await page.locator('[data-test=new-tab]').click()
  await page.locator('[data-test=new-packet]').click()
  await utils.selectTargetPacketItem('INST', 'ADCS')
  await page.locator('text=Decom').click()
  await expect(page.locator('[data-test=add-packet-value-type]')).toBeVisible()
  await page.locator('[data-test=add-packet-button]').click()
  await page.locator('[data-test=start-button]').click()
  await expect(page.locator(".v-window-item > div")).toHaveCount(1);
  await utils.sleep(500)
  expect(await page.inputValue('[data-test=dump-component-text-area]')).toMatch('POSX:')
  expect(await page.inputValue('[data-test=dump-component-text-area]')).toMatch('POSY:')
  expect(await page.inputValue('[data-test=dump-component-text-area]')).toMatch('POSZ:')
  expect(await page.inputValue('[data-test=dump-component-text-area]')).not.toMatch('00000010:')
  // add another packet to the existing connection
  await page.locator('[data-test=new-packet]').click()
  await utils.selectTargetPacketItem('INST', 'ADCS')
  await page.locator('[data-test=add-packet-button]').click()
  await expect(page.locator(".v-window-item > div")).toHaveCount(2);
})

test('renames a tab', async ({ page }) => {
  await page.locator('[data-test=new-tab]').click()
  await page.locator('[data-test=tab]').click({ button: 'right' })
  await page.locator('[data-test=context-menu-rename] > div').click()
  await page.locator('[data-test=rename-tab-input]').fill('Testing tab name')
  await page.locator('[data-test=rename]').click()
  await expect(page.locator(".v-tab")).toHaveText("Testing tab name")
  await page.locator('[data-test=tab]').click({ button: 'right' })
  await page.locator('[data-test=context-menu-rename] > div').click()
  await page.locator('[data-test=rename-tab-input]').fill('Cancel this')
  await page.locator('[data-test=cancel-rename]').click()
  await expect(page.locator(".v-tab")).toHaveText("Testing tab name")
})

test('deletes a component and tab', async ({ page }) => {
  await page.locator('[data-test=new-tab]').click()
  await page.locator('[data-test=new-packet]').click()
  await utils.selectTargetPacketItem('INST', 'ADCS')
  await page.locator('[data-test=add-packet-button]').click()
  await expect(page.locator('.v-window-item > .v-card > .v-card__title')).toHaveText('INST ADCS')
  await page.locator('[data-test=delete-packet]').click()
  await expect(page.locator('.v-window-item > .v-card > .v-card__title')).toHaveText('This tab is empty')
  await page.locator('[data-test=tab]').click({ button: 'right' })
  await page.locator('[data-test=context-menu-delete] > div').click()
  await expect(page.locator('.v-card > .v-card__title').first()).toHaveText("You're not viewing any packets")
})

test('controls playback', async ({ page }) => {
  await page.locator('[data-test=new-tab]').click()
  await page.locator('[data-test=new-packet]').click()
  await utils.selectTargetPacketItem('INST', 'ADCS')
  await page.locator('[data-test=add-packet-button]').click()
  await page.locator('[data-test=start-button]').click()
  await utils.sleep(1000) // Allow a few packets to come in
  await page.locator('[data-test=dump-component-play-pause]').click()
  await utils.sleep(500) // Ensure it's stopped and draws the last packet contents
  let content: string = await page.inputValue('[data-test=dump-component-text-area]')
  // Step back and forth
  await page.locator('[aria-label="prepend icon"]').click();
  expect(content).not.toEqual(await page.inputValue('[data-test=dump-component-text-area]'))
  await page.locator('[aria-label="append icon"]').click();
  expect(content).toEqual(await page.inputValue('[data-test=dump-component-text-area]'))
  // Resume
  await page.locator('[data-test=dump-component-play-pause]').click()
  expect(content).not.toEqual(await page.inputValue('[data-test=dump-component-text-area]'))
  // Stop
  await page.locator('[data-test="stop-button"]').click();
  await utils.sleep(500) // Ensure it's stopped and draws the last packet contents
  content = await page.inputValue('[data-test=dump-component-text-area]')
  await utils.sleep(500) // Wait for potential changes
  expect(content).toEqual(await page.inputValue('[data-test=dump-component-text-area]'))
})

test('changes display settings', async ({ page }) => {
  await page.locator('[data-test=new-tab]').click()
  await page.locator('[data-test=new-packet]').click()
  await utils.selectTargetPacketItem('INST', 'ADCS')
  await page.locator('[data-test=add-packet-button]').click()
  await page.locator('[data-test=start-button]').click()
  await utils.sleep(1000) // Allow a few packets to come in
  await page.locator('[data-test=dump-component-open-settings]').click()
  await expect(page.locator('[data-test=display-settings-card]')).toBeVisible()
  await page.locator('text=ASCII').click()
  await page.locator('text=/^Top$/').click() // Be specific to avoid matching 'Stop'
  await page.locator('text=Show line address').click()
  await page.locator('text=Show timestamp').click()
  // check number input validation
  await page.locator('[data-test=dump-component-settings-num-bytes]').fill('0')
  await page.locator('[data-test="dump-component-settings-num-bytes"]').press('Enter'); // fire the validation
  await expect(page.locator('[data-test=dump-component-settings-num-bytes]')).toHaveValue("1")
  await page.locator('[data-test=dump-component-settings-num-packets]').fill('0')
  await page.locator('[data-test="dump-component-settings-num-packets"]').press('Enter'); // fire the validation
  await expect(page.locator('[data-test=dump-component-settings-num-packets]')).toHaveValue("1")
  await page.locator('[data-test=dump-component-settings-num-packets]').fill('101')
  await page.locator('[data-test="dump-component-settings-num-packets"]').press('Enter'); // fire the validation
  await expect(page.locator('[data-test=dump-component-settings-num-packets]')).toHaveValue("100")
})

test('downloads a file', async ({ page }) => {
  await page.locator('[data-test=new-tab]').click()
  await page.locator('[data-test=new-packet]').click()
  await utils.selectTargetPacketItem('INST', 'ADCS')
  await page.locator('[data-test=add-packet-button]').click()
  await page.locator('[data-test=start-button]').click()
  await utils.sleep(1000) // Allow a few packets to come in
  await page.locator('[data-test=dump-component-play-pause]').click()

  const [download] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator('[data-test="dump-component-download"]').click()
  ]);
  // Wait for the download process to complete
  const path = await download.path();
  const contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  expect(contents).toEqual(await page.inputValue('[data-test=dump-component-text-area]'))
})

// test('validates start and end time inputs', async ({ page }) => {
//   // validate start date
//   await page.locator('[data-test=startDate]').clear()
//   await page.locator('.container').should('contain', 'Required')
//   await page.locator('[data-test=startDate]').clear().type('2020-01-01')
//   await page.locator('.container').should('not.contain', 'Invalid')
//   // validate start time
//   await page.locator('[data-test=startTime]').clear()
//   await page.locator('.container').should('contain', 'Required')
//   await page.locator('[data-test=startTime]').clear().type('12:15:15')
//   await page.locator('.container').should('not.contain', 'Invalid')

//   // validate end date
//   await page.locator('[data-test=endDate]').clear().type('2020-01-01')
//   await page.locator('.container').should('not.contain', 'Invalid')
//   // validate end time
//   await page.locator('[data-test=endTime]').clear().type('12:15:15')
//   await page.locator('.container').should('not.contain', 'Invalid')
// })

// test('validates start and end time values', async ({ page }) => {
//   // validate future start date
//   await page.locator('[data-test=startDate]').clear().type('4000-01-01') // If this version of COSMOS is still used 2000 years from now, this test will need to be updated
//   await page.locator('[data-test=startTime]').clear().type('12:15:15')
//   await page.locator('[data-test=start-button]').click()
//   await page.locator('.warning').should('contain', 'Start date/time is in the future!')

//   // validate start/end time equal to each other
//   await page.locator('[data-test=startDate]').clear().type('2020-01-01')
//   await page.locator('[data-test=startTime]').clear().type('12:15:15')
//   await page.locator('[data-test=endDate]').clear().type('2020-01-01')
//   await page.locator('[data-test=endTime]').clear().type('12:15:15')
//   await page.locator('[data-test=start-button]').click()
//   await page.locator('.warning').should(
//     'contain',
//     'Start date/time is equal to end date/time!'
//   )

//   // validate future end date
//   await page.locator('[data-test=startDate]').clear().type('2020-01-01')
//   await page.locator('[data-test=startTime]').clear().type('12:15:15')
//   await page.locator('[data-test=endDate]').clear().type('4000-01-01')
//   await page.locator('[data-test=endTime]').clear().type('12:15:15')
//   await page.locator('[data-test=start-button]').click()
//   await page.locator('.warning').should(
//     'contain',
//     'Note: End date/time is greater than current date/time. Data will continue to stream in real-time until 4000-01-01 12:15:15 is reached.'
//   )
// })
