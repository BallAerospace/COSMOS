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
import { test, expect } from "playwright-test-coverage";
import { Utilities } from "../utilities";
import { format, add, sub } from "date-fns";

let utils;
test.beforeEach(async ({ page }) => {
  await page.goto("/tools/tlmgrapher");
  await expect(page.locator("body")).toContainText("Telemetry Grapher");
  await page.locator(".v-app-bar__nav-icon").click();
  utils = new Utilities(page);
});

test("adds items to a graph, starts, pauses, resumes and stops", async ({
  page,
}) => {
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP1");
  await page.locator('button:has-text("Add Item")').click();
  await expect(page.locator("#chart0")).toContainText("TEMP1");
  utils.sleep(3000); // Wait for graphing to occur
  // Add another item while it is already graphing
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");
  await page.locator('button:has-text("Add Item")').click();
  await expect(page.locator("#chart0")).toContainText("TEMP2");
  // Use the graph buttons first
  await page.locator("[data-test=pause-graph").click();
  utils.sleep(1000); // Wait for graphing to pause
  await page.locator("[data-test=start-graph").click();
  utils.sleep(1000); // Wait for graphing to resume
  // Use the graph menu now
  await page.locator('[data-test="Telemetry Grapher-Graph"]').click();
  await page.locator("text=Pause").click();
  utils.sleep(1000); // Wait for graphing to pause
  await page.locator('[data-test="Telemetry Grapher-Graph"]').click();
  await page.locator("text=Start").click();
  utils.sleep(1000); // Wait for graphing to resume
  await page.locator('[data-test="Telemetry Grapher-Graph"]').click();
  await page.locator("text=Stop").click();
  utils.sleep(1000); // Wait for graphing to stop
});

test("adds multiple graphs", async ({ page }) => {
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP1");
  await page.locator('button:has-text("Add Item")').click();
  await expect(page.locator("#chart0")).toContainText("TEMP1");
  utils.sleep(1000); // Wait for graphing to occur
  await page.locator('[data-test="Telemetry Grapher-Graph"]').click();
  await page.locator("text=Add Graph").click();
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP2");
  await page.locator('button:has-text("Add Item")').click();
  await expect(page.locator("#chart1")).toContainText("TEMP2");
  await expect(page.locator("#chart1")).not.toContainText("TEMP1");
  await expect(page.locator("#chart0")).not.toContainText("TEMP2");
  // Close the charts
  await page.locator("[data-test=close-graph-icon]").first().click();
  await expect(page.locator("#chart0")).not.toBeVisible();
  await expect(page.locator("#chart1")).toBeVisible();
  await page.locator("[data-test=close-graph-icon]").click();
  await expect(page.locator("#chart1")).not.toBeVisible();
});

test("minimizes, shrinks and expands a graph", async ({ page }) => {
  await utils.sleep(500); // allow chart to fully render
  // Get ElementHandle to the chart
  const chart = await page.$("#chart0");
  const origBox = await chart.boundingBox();
  // Minimize / maximized the graph
  await page.locator("[data-test=minimize-screen-icon]").click();
  const minimizeBox = await chart.boundingBox();
  console.log(minimizeBox);
  // Exact box is 124.51, 24. Height shouldn't change but
  // width might as it includes the title and icons so give more leeway.
  expect(minimizeBox.width).toBeLessThan(130);
  expect(minimizeBox.height).toBeLessThan(25);
  await page.locator("[data-test=maximize-screen-icon]").click();
  const maximizeBox = await chart.boundingBox();
  expect(maximizeBox.width).toBe(origBox.width);
  expect(maximizeBox.height).toBe(origBox.height);

  await page.locator("[data-test=expand-width]").click();
  const expandWidthBox = await chart.boundingBox();
  // Check that we're now double with only 1 digit of precision
  expect(expandWidthBox.width / origBox.width).toBeCloseTo(2, 1);
  expect(expandWidthBox.height).toBe(origBox.height);
  await page.locator("[data-test=collapse-width]").click();
  const collapseWidthBox = await chart.boundingBox();
  expect(collapseWidthBox.width).toBe(origBox.width);
  expect(collapseWidthBox.height).toBe(origBox.height);

  await page.locator("[data-test=collapse-height]").click();
  const collapseHeightBox = await chart.boundingBox();
  // Check that we're half with only 1 digit of precision
  expect(origBox.height / collapseHeightBox.height).toBeCloseTo(2, 1);
  expect(collapseHeightBox.width).toBe(origBox.width);
  await page.locator("[data-test=expand-height]").click();
  const expandHeightBox = await chart.boundingBox();
  expect(expandHeightBox.width).toBe(origBox.width);
  expect(expandHeightBox.height).toBe(origBox.height);

  await page.locator("[data-test=collapse-all]").click();
  const minBox = await chart.boundingBox();
  await page.locator("[data-test=expand-all]").click();
  const maxBox = await chart.boundingBox();
  // Check that we're double with only 1 digit of precision
  expect(maxBox.height / minBox.height).toBeCloseTo(2, 1);
  expect(maxBox.width / minBox.width).toBeCloseTo(2, 1);
  await page.locator("[data-test=collapse-all]").click();
  const minBox2 = await chart.boundingBox();
  expect(minBox2.width).toBe(minBox.width);
  expect(minBox2.height).toBe(minBox.height);
});

test("edits a graph", async ({ page }) => {
  await utils.selectTargetPacketItem("INST", "HEALTH_STATUS", "TEMP1");
  await page.locator('button:has-text("Add Item")').click();
  await expect(page.locator("#chart0")).toContainText("TEMP1");
  utils.sleep(3000); // Wait for graphing to occur
  await page.locator("[data-test=edit-graph-icon]").click();
  await expect(page.locator(".v-dialog")).toContainText("Edit Graph");
  await page.locator('[data-test="edit-graph-title"]').fill("Test Graph Title");

  const start = sub(new Date(), { minutes: 2 });
  await page
    .locator('text=Start Date >> [data-test="dateChooser"]')
    .fill(format(start, "MM/DD/YYYY"));
  await page
    .locator('text=Start Time >> [data-test="timeChooser"]')
    .fill(format(start, "HH:mm:ss"));
  await page.locator('[data-test="graph-min-y"]').fill("-50");
  await page.locator('[data-test="graph-max-y"]').fill("50");
  await page.locator('button:has-text("Ok")').click();
  // Validate our settings
  await expect(page.locator("#chart0")).toContainText("Test Graph Title");
  await expect(page.locator("#chart0")).toContainText("-50");
  await expect(page.locator("#chart0")).toContainText("50");
  utils.sleep(5000); // Allow data to flow
});
