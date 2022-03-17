// @ts-check
import { test, expect } from "@playwright/test";
import { Utilities } from "../utilities";
import { format, add, sub } from "date-fns";
import * as fs from "fs";

let utils;
test.beforeEach(async ({ page }) => {
  await page.goto("/tools/dataextractor");
  await expect(page.locator("body")).toContainText("Data Extractor");
  await page.locator(".v-app-bar__nav-icon").click();
  utils = new Utilities(page);
  await utils.sleep(500);
});

test("loads and saves the configuration", async ({ page }) => {
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP1");
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");

  let config = "spec" + Math.floor(Math.random() * 10000);
  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator("text=Save Configuration").click();
  await page
    .locator('[data-test="name-input-save-config-dialog"]')
    .fill(config);
  await page.locator('button:has-text("Ok")').click();
  // Clear the success toast
  await page.locator('button:has-text("Dismiss")').click();

  // This also works but it relies on a Vuetify attribute
  // await expect(page.locator('[role=listitem]')).toHaveCount(2)
  await expect(page.locator("[data-test=itemList] > div")).toHaveCount(2);
  await page.locator('[data-test="deleteAll"]').click();
  await expect(page.locator("[data-test=itemList] > div")).toHaveCount(0);

  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator("text=Open Configuration").click();
  await page.locator(`td:has-text("${config}")`).click();
  await page.locator('button:has-text("Ok")').click();
  // Clear the success toast
  await page.locator('button:has-text("Dismiss")').click();
  await expect(page.locator("[data-test=itemList] > div")).toHaveCount(2);

  // Delete this test configuation
  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator("text=Open Configuration").click();
  // Note: Only works if you don't have any other configs saved
  await page.locator('[data-test="item-delete"]').click();
  await page.locator('button:has-text("Delete")').click();
  await page.locator('[data-test="open-config-cancel-btn"]').click();
});

test("validates dates and times", async ({ page }) => {
  // Date validation
  const d = new Date();
  await expect(page.locator("text=Required")).not.toBeVisible();
  await page.locator("[data-test=startDate]").fill("");
  await expect(page.locator("text=Required")).toBeVisible();
  // Since we just started we're only able to fill in the day
  await page.locator("[data-test=startDate]").type("01");
  await expect(page.locator("text=Required")).not.toBeVisible();
  // Time validation
  await page.locator("[data-test=startTime]").fill("");
  await expect(page.locator("text=Required")).toBeVisible();
  await page.locator("[data-test=startTime]").fill("12:15:15");
  await expect(page.locator("text=Required")).not.toBeVisible();
});

test("won't start with 0 items", async ({ page }) => {
  await expect(page.locator("text=Process")).toBeDisabled();
});

test("warns with duplicate item", async ({ page }) => {
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");
  await page.locator('[data-test="select-send"]').click(); // Send again
  await expect(
    page.locator("text=This item has already been added")
  ).toBeVisible();
});

test("warns with no time delta", async ({ page }) => {
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");
  await page.locator("text=Process").click();
  await expect(
    page.locator("text=Start date/time is equal to end date/time")
  ).toBeVisible();
});

test("warns with no data", async ({ page }) => {
  const start = sub(new Date(), { seconds: 10 });
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await page.locator('label:has-text("Command")').click();
  let utils = new Utilities(page);
  await utils.selectTargetPacketItem(
    "INST",
    "ARYCMD",
    "RECEIVED_TIMEFORMATTED"
  );
  await page.locator("text=Process").click();
  await expect(page.locator("text=No data found")).toBeVisible();
});

test("cancels a process", async ({ page }) => {
  const start = sub(new Date(), { minutes: 2 });
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await page
    .locator("[data-test=endTime]")
    .fill(format(add(start, { hours: 1 }), "HH:mm:ss"));
  await utils.selectTargetPacketItem("INST", "ADCS", "CCSDSVER");
  await page.locator("text=Process").click();
  await expect(
    page.locator("text=End date/time is greater than current date/time")
  ).toBeVisible();
  await new Promise((resolve) => setTimeout(resolve, 2000)); // Allow the download to start

  const [download] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Cancel initiates the download
    page.locator("text=Cancel").click(),
  ]);
  // Wait for the download process to complete
  await download.path();

  // Ensure the Cancel button goes back to Process
  await expect(page.locator("text=Process")).toBeVisible();
});

test("adds an entire target", async ({ page }) => {
  await utils.selectTargetPacketItem("INST");
  expect(
    await page.locator("[data-test=itemList] > div").count()
  ).toBeGreaterThan(50);
});

test("adds an entire packet", async ({ page }) => {
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS");
  expect(await page.locator("[data-test=itemList] > div").count()).toBeLessThan(
    50
  );
  expect(
    await page.locator("[data-test=itemList] > div").count()
  ).toBeGreaterThan(10);
});

test("add, edits, deletes items", async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 });
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.selectTargetPacketItem("INST", "ADCS", "CCSDSVER");
  await utils.selectTargetPacketItem("INST", "ADCS", "CCSDSTYPE");
  await utils.selectTargetPacketItem("INST", "ADCS", "CCSDSSHF");
  await expect(page.locator("[data-test=itemList] > div")).toHaveCount(3);
  // Delete CCSDSVER by clicking Delete icon
  await page
    .locator(".v-list div:nth-child(1) .v-list-item div:nth-child(3) .v-icon")
    .click();
  await expect(page.locator("[data-test=itemList] > div")).toHaveCount(2);
  // Delete CCSDSTYPE
  await page
    .locator(".v-list div:nth-child(1) .v-list-item div:nth-child(3) .v-icon")
    .click();
  await expect(page.locator("[data-test=itemList] > div")).toHaveCount(1);
  // Edit CCSDSSHF
  await page.locator('[data-test="itemList"] button').first().click();
  await page.locator("text=​Value Type").click();
  await page.locator("text=RAW").click();
  await page.locator('button:has-text("Ok")').click();
  await page.locator(
    '[data-test="itemList"] >> text=INST - ADCS - CCSDSSHF + (RAW)'
  );

  const [download] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator("text=Process").click(),
  ]);
  // Wait for the download process to complete
  const path = await download.path();
  const contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  const lines = contents.split("\n");
  expect(lines[0]).toContain('CCSDSSHF (RAW)')
  expect(lines[1]).not.toContain('FALSE')
  expect(lines[1]).toContain('0')
});

test('processes commands', async ({ page }) => {
  // Preload an ABORT command
  await page.goto("/tools/cmdsender/INST/ABORT");
  await page.locator("[data-test=select-send]").click();
  await page.locator('text=cmd("INST ABORT") sent')

  const start = sub(new Date(), { minutes: 5 })
  await page.goto("/tools/dataextractor");
  await page.locator(".v-app-bar__nav-icon").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await page.locator('label:has-text("Command")').click();

  await utils.selectTargetPacketItem('INST', 'ABORT', 'RECEIVED_TIMEFORMATTED')
  const [download] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator("text=Process").click(),
  ]);
  // Wait for the download process to complete
  const path = await download.path();
  const contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  const lines = contents.split("\n");
  expect(lines[1]).toContain('INST')
  expect(lines[1]).toContain('ABORT')
})

test('creates CSV output', async ({ page }) => {
  const start = sub(new Date(), { minutes: 5 })
  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator("text=Comma Delimited").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')

  const [download] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator("text=Process").click(),
  ]);
  // Wait for the download process to complete
  const path = await download.path();
  const contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  // Check that we handle raw value types set by the demo
  expect(contents).toContain('NaN')
  expect(contents).toContain('Infinity')
  expect(contents).toContain('-Infinity')
  var lines = contents.split('\n')
  expect(lines[0]).toContain('TEMP1')
  expect(lines[0]).toContain('TEMP2')
  expect(lines[0]).toContain(',') // csv
  expect(lines.length).toBeGreaterThan(290) // 5 min at 60Hz is 300 samples
})

test('creates tab delimited output', async ({ page }) => {
  const start = sub(new Date(), { minutes: 5 })
  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator("text=Tab Delimited").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')

  const [download] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator("text=Process").click(),
  ]);
  // Wait for the download process to complete
  const path = await download.path();
  const contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  // Check that we handle raw value types set by the demo
  var lines = contents.split('\n')
  expect(lines[0]).toContain('TEMP1')
  expect(lines[0]).toContain('TEMP2')
  expect(lines[0]).toContain('\t')
  expect(lines.length).toBeGreaterThan(290) // 5 min at 60Hz is 300 samples
})

test('outputs full column names', async ({ page }) => {
  let start = sub(new Date(), { minutes: 1 })
  await page.locator('[data-test="Data\\ Extractor-Mode"]').click();
  await page.locator("text=Full Column Names").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')

  let [download] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator("text=Process").click(),
  ]);
  // Wait for the download process to complete
  let path = await download.path();
  let contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  // Check that we handle raw value types set by the demo
  var lines = contents.split('\n')
  expect(lines[0]).toContain('INST HEALTH_STATUS TEMP1')
  expect(lines[0]).toContain('INST HEALTH_STATUS TEMP2')

  // Switch back and verify
  await page.locator('[data-test="Data\\ Extractor-Mode"]').click();
  await page.locator("text=Normal Columns").click();
  // Create a new end time so we get a new filename
  start = sub(new Date(), { minutes: 2 })
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));

  [download] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator("text=Process").click(),
  ]);
  // Wait for the download process to complete
  path = await download.path();
  contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  // Check that we handle raw value types set by the demo
  var lines = contents.split('\n')
  expect(lines[0]).toContain('TARGET,PACKET,TEMP1,TEMP2')
})

// test('fills values', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.get('.v-toolbar').contains('Mode').click({force: true})
//   cy.contains(/Fill Down/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   // Deliberately test with two different packets
//   await utils.selectTargetPacketItem('INST', 'ADCS', 'CCSDSSEQCNT')
//   cy.contains('Add Item').click()
//   await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSSEQCNT')
//   cy.contains('Add Item').click()
//   page.locator("text=Process").click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.split('\n')
//     expect(lines[0]).toContain('CCSDSSEQCNT')
//     var firstHS = -1
//     for (let i = 1; i < lines.length; i++) {
//       if (firstHS !== -1) {
//         var [tgt1, pkt1, hs1, adcs1] = lines[firstHS].split(',')
//         var [tgt2, pkt2, hs2, adcs2] = lines[i].split(',')
//         expect(tgt1).to.eq(tgt2) // Both INST
//         expect(pkt1).to.eq('HEALTH_STATUS')
//         expect(pkt2).to.eq('ADCS')
//         expect(parseInt(adcs1) + 1).to.eq(parseInt(adcs2)) // ADCS goes up by one each time
//         expect(parseInt(hs1)).toBeGreaterThan(1) // Double check for a value
//         expect(hs1).to.eq(hs2) // HEALTH_STATUS should be the same
//         break
//       } else if (lines[i].includes('HEALTH_STATUS')) {
//         // Look for the first line containing HEALTH_STATUS
//         console.log('Found first HEALTH_STATUS on line ' + i)
//         firstHS = i
//       }
//     }
//   })
// })

// test('adds Matlab headers', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.get('.v-toolbar').contains('Mode').click({force: true})
//   cy.contains(/Matlab Header/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   await utils.selectTargetPacketItem('INST', 'ADCS', 'Q1')
//   cy.contains('Add Item').click()
//   await utils.selectTargetPacketItem('INST', 'ADCS', 'Q2')
//   cy.contains('Add Item').click()
//   page.locator("text=Process").click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.split('\n')
//     expect(lines[0]).toContain('% TARGET,PACKET,Q1,Q2')
//   })
// })

// test('outputs unique values only', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.get('.v-toolbar').contains('Mode').click({force: true})
//   cy.contains(/Unique Only/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSVER')
//   cy.contains('Add Item').click()
//   page.locator("text=Process").click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     console.log(contents)
//     var lines = contents.split('\n')
//     expect(lines[0]).toContain('CCSDSVER')
//     expect(lines.length).to.eq(2) // header and a single value
//   })
// })

// Playwright Test Generator output:
//   // Click label:has-text("Command")
//   await page.locator('label:has-text("Command")').click();
//   // Click text=Day
//   await page.locator('text=Day').click();
//   // Click .v-input--radio-group__input div:nth-child(2) .v-input--selection-controls__input .v-input--selection-controls__ripple >> nth=0
//   await page.locator('.v-input--radio-group__input div:nth-child(2) .v-input--selection-controls__input .v-input--selection-controls__ripple').first().click();
//   // Click div[role="button"]:has-text("Select Item")
//   await page.locator('div[role="button"]:has-text("Select Item")').click();
//   // Click div:nth-child(4) .col .v-input .v-input__control .v-input__slot .v-input--radio-group__input div .v-input--selection-controls__input .v-input--selection-controls__ripple >> nth=0
//   await page.locator('div:nth-child(4) .col .v-input .v-input__control .v-input__slot .v-input--radio-group__input div .v-input--selection-controls__input .v-input--selection-controls__ripple').first().click();
//   // Click div[role="button"]:has-text("Select ItemTEMP1")
//   await page.locator('div[role="button"]:has-text("Select ItemTEMP1")').click();
//   // Click #list-item-293-13 div:has-text("TEMP2") >> nth=0
//   await page.locator('#list-item-293-13 div:has-text("TEMP2")').first().click();
//   // Click [data-test="select-send"]
//   await page.locator('[data-test="select-send"]').click();
//   // Click div[role="button"]:has-text("Select ItemTEMP2")
//   await page.locator('div[role="button"]:has-text("Select ItemTEMP2")').click();
//   // Click text=TEMP3
//   await page.locator('text=TEMP3').click();
//   // Click [data-test="select-send"]
//   await page.locator('[data-test="select-send"]').click();
//   // Click .v-icon.notranslate.v-icon--link >> nth=0
//   await page.locator('.v-icon.notranslate.v-icon--link').first().click();
//   // Click text=​Value TypeCONVERTED
//   await page.locator('text=​Value TypeCONVERTED').click();
//   // Click text=RAW
//   await page.locator('text=RAW').click();
//   // Click button:has-text("Ok")
//   await page.locator('button:has-text("Ok")').click();
//   // Click .v-list div:nth-child(2) .v-list-item div .v-icon >> nth=0
//   await page.locator('.v-list div:nth-child(2) .v-list-item div .v-icon').first().click();
//   // Click text=Edit INST - HEALTH_STATUS - TEMP2​Value TypeCONVERTED Ok >> button
//   await page.locator('text=Edit INST - HEALTH_STATUS - TEMP2​Value TypeCONVERTED Ok >> button').click();
//   // Click div:nth-child(3) .v-list-item div .v-icon >> nth=0
//   await page.locator('div:nth-child(3) .v-list-item div .v-icon').first().click();
//   // Click text=Edit INST - HEALTH_STATUS - TEMP3​Value TypeCONVERTED Ok >> button
//   await page.locator('text=Edit INST - HEALTH_STATUS - TEMP3​Value TypeCONVERTED Ok >> button').click();
// });
