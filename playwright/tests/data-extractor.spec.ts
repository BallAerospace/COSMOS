// @ts-check
import { test, expect } from "playwright-test-coverage";
import { Utilities } from "../utilities";
import { format, add, sub } from "date-fns";
import * as fs from "fs";

let utils;
test.beforeEach(async ({ page }) => {
  await page.goto("/tools/dataextractor");
  await expect(page.locator("body")).toContainText("Data Extractor");
  await page.locator(".v-app-bar__nav-icon").click();
  utils = new Utilities(page);
});

test("loads and saves the configuration", async ({ page }) => {
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP1");
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");

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
  await page.locator('button:has-text("Delete")').click(); // Confirm the delete
  await page.locator('[data-test="open-config-cancel-btn"]').click();
});

test("validates dates and times", async ({ page }) => {
  // Date validation
  const d = new Date();
  await expect(page.locator("text=Required")).not.toBeVisible();
  // await page.locator("[data-test=startDate]").click();
  // await page.keyboard.press('Delete')
  await page.locator("[data-test=startDate]").fill("");
  await expect(page.locator("text=Required")).toBeVisible();
  // Note: Firefox doesn't implement min/max the same way as Chrome
  // Chromium limits you to just putting in the day since it has a min/max value
  // Firefox doesn't apppear to limit at all so you need to enter entire date
  // End result is that in Chromium the date gets entered as the 2 digit year
  // e.g. "22", which is fine because even if you go big it will round down.
  await page.locator("[data-test=startDate]").type(format(d, "MM"));
  await page.locator("[data-test=startDate]").type(format(d, "dd"));
  await page.locator("[data-test=startDate]").type(format(d, "yyyy"));
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
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");
  await page.locator('[data-test="select-send"]').click(); // Send again
  await expect(
    page.locator("text=This item has already been added")
  ).toBeVisible();
});

test("warns with no time delta", async ({ page }) => {
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");
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
  await utils.addTargetPacketItem(
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
  await utils.addTargetPacketItem("INST", "ADCS", "CCSDSVER");
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
  await utils.addTargetPacketItem("INST");
  await utils.sleep(500); // Allow list to populate
  expect(
    await page.locator("[data-test=itemList] > div").count()
  ).toBeGreaterThan(50);
});

test("adds an entire packet", async ({ page }) => {
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS");
  await utils.sleep(500); // Allow list to populate
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
  await utils.addTargetPacketItem("INST", "ADCS", "CCSDSVER");
  await utils.addTargetPacketItem("INST", "ADCS", "CCSDSTYPE");
  await utils.addTargetPacketItem("INST", "ADCS", "CCSDSSHF");
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
  await page.locator("text=Value Type").click();
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
  expect(lines[0]).toContain("CCSDSSHF (RAW)");
  expect(lines[1]).not.toContain("FALSE");
  expect(lines[1]).toContain("0");
});

test("edit all items", async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 });
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.addTargetPacketItem("INST", "ADCS");
  expect(
    await page.locator("[data-test=itemList] > div").count()
  ).toBeGreaterThan(20);
  await page.locator('[data-test="editAll"]').click();
  await page.locator("text=Value Type").click();
  await page.locator("text=RAW").click();
  await page.locator('button:has-text("Ok")').click();
  // Spot check a few items ... they have all changed to (RAW)
  await page.locator(
    '[data-test="itemList"] >> text=INST - ADCS - CCSDSSHF + (RAW)'
  );
  await page.locator(
    '[data-test="itemList"] >> text=INST - ADCS - POSX + (RAW)'
  );
  await page.locator(
    '[data-test="itemList"] >> text=INST - ADCS - VELX + (RAW)'
  );
  await page.locator(
    '[data-test="itemList"] >> text=INST - ADCS - Q1 + (RAW)'
  );
});

test("processes commands", async ({ page }) => {
  // Preload an ABORT command
  await page.goto("/tools/cmdsender/INST/ABORT");
  await page.locator("[data-test=select-send]").click();
  await page.locator('text=cmd("INST ABORT") sent');

  const start = sub(new Date(), { minutes: 5 });
  await page.goto("/tools/dataextractor");
  await page.locator(".v-app-bar__nav-icon").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await page.locator('label:has-text("Command")').click();

  await utils.addTargetPacketItem("INST", "ABORT", "RECEIVED_TIMEFORMATTED");
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
  expect(lines[1]).toContain("INST");
  expect(lines[1]).toContain("ABORT");
});

test("creates CSV output", async ({ page }) => {
  const start = sub(new Date(), { minutes: 5 });
  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator("text=Comma Delimited").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP1");
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");

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
  expect(contents).toContain("NaN");
  expect(contents).toContain("Infinity");
  expect(contents).toContain("-Infinity");
  var lines = contents.split("\n");
  expect(lines[0]).toContain("TEMP1");
  expect(lines[0]).toContain("TEMP2");
  expect(lines[0]).toContain(","); // csv
  expect(lines.length).toBeGreaterThan(290); // 5 min at 60Hz is 300 samples
});

test("creates tab delimited output", async ({ page }) => {
  const start = sub(new Date(), { minutes: 5 });
  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator("text=Tab Delimited").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP1");
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");

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
  var lines = contents.split("\n");
  expect(lines[0]).toContain("TEMP1");
  expect(lines[0]).toContain("TEMP2");
  expect(lines[0]).toContain("\t");
  expect(lines.length).toBeGreaterThan(290); // 5 min at 60Hz is 300 samples
});

test("outputs full column names", async ({ page }) => {
  let start = sub(new Date(), { minutes: 1 });
  await page.locator('[data-test="Data\\ Extractor-Mode"]').click();
  await page.locator("text=Full Column Names").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP1");
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");

  const [download1] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator("text=Process").click(),
  ]);
  // Wait for the download process to complete
  let path = await download1.path();
  let contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  // Check that we handle raw value types set by the demo
  var lines = contents.split("\n");
  expect(lines[0]).toContain("INST HEALTH_STATUS TEMP1");
  expect(lines[0]).toContain("INST HEALTH_STATUS TEMP2");
  await utils.sleep(1000);

  // Switch back and verify
  await page.locator('[data-test="Data\\ Extractor-Mode"]').click();
  await page.locator("text=Normal Columns").click();
  // Create a new end time so we get a new filename
  start = sub(new Date(), { minutes: 2 });
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));

  const [download2] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent("download"),
    // Initiate the download
    page.locator("text=Process").click(),
  ]);
  // Wait for the download process to complete
  path = await download2.path();
  contents = await fs.readFileSync(path, {
    encoding: "utf-8",
  });
  // Check that we handle raw value types set by the demo
  var lines = contents.split("\n");
  expect(lines[0]).toContain("TARGET,PACKET,TEMP1,TEMP2");
});

test("fills values", async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 });
  await page.locator('[data-test="Data\\ Extractor-Mode"]').click();
  await page.locator("text=Fill Down").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  // Deliberately test with two different packets
  await utils.addTargetPacketItem("INST", "ADCS", "CCSDSSEQCNT");
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "CCSDSSEQCNT");

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
  var lines = contents.split("\n");
  expect(lines[0]).toContain("CCSDSSEQCNT");
  var firstHS = -1;
  for (let i = 1; i < lines.length; i++) {
    if (firstHS !== -1) {
      var [tgt1, pkt1, hs1, adcs1] = lines[firstHS].split(",");
      var [tgt2, pkt2, hs2, adcs2] = lines[i].split(",");
      expect(tgt1).toEqual(tgt2); // Both INST
      expect(pkt1).toEqual("HEALTH_STATUS");
      expect(pkt2).toEqual("ADCS");
      expect(parseInt(adcs1) + 1).toEqual(parseInt(adcs2)); // ADCS goes up by one each time
      expect(parseInt(hs1)).toBeGreaterThan(1); // Double check for a value
      expect(hs1).toEqual(hs2); // HEALTH_STATUS should be the same
      break;
    } else if (lines[i].includes("HEALTH_STATUS")) {
      // Look for the first line containing HEALTH_STATUS
      // console.log("Found first HEALTH_STATUS on line " + i);
      firstHS = i;
    }
  }
});

test("adds Matlab headers", async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 });
  await page.locator('[data-test="Data\\ Extractor-Mode"]').click();
  await page.locator("text=Matlab Header").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.addTargetPacketItem("INST", "ADCS", "Q1");
  await utils.addTargetPacketItem("INST", "ADCS", "Q2");

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
  var lines = contents.split("\n");
  expect(lines[0]).toContain("% TARGET,PACKET,Q1,Q2");
});

test("outputs unique values only", async ({ page }) => {
  const start = sub(new Date(), { minutes: 1 });
  await page.locator('[data-test="Data\\ Extractor-Mode"]').click();
  await page.locator("text=Unique Only").click();
  await page.locator("[data-test=startTime]").fill(format(start, "HH:mm:ss"));
  await utils.addTargetPacketItem("INST", "HEALTH_STATUS", "CCSDSVER");

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
  var lines = contents.split("\n");
  expect(lines[0]).toContain("CCSDSVER");
  expect(lines.length).toEqual(2); // header and a single value
});
