// @ts-check
import { test, expect } from "playwright-test-coverage";

test.beforeEach(async ({ page }) => {
  await page.goto("/tools/scriptrunner");
  await expect(page.locator("body")).toContainText("Script Runner");
  await page.locator(".v-app-bar__nav-icon").click();
});

test("finds text on page", async ({ page }) => {
  // Have to fill on an editable area like the textarea
  var string = `cosmos is a command and control system
cosmos can send commands and execute scripts
cosmos is everything I thought it could be`;
  await page.locator("textarea").fill(string);
  await page.locator('[data-test="Script Runner-Edit"]').click();
  await page.locator('[data-test="Script Runner-Edit-Find"] >> text=Find').click();
  await page.locator('[placeholder="Search for"]').fill('cosmos');
  await page.locator('text=3 of 3');
  await page.locator('textarea').press('Escape');

  await page.locator('[data-test="Script Runner-Edit"]').click();
  await page.locator('[data-test="Script Runner-Edit-Replace"] >> text=Replace').click();
  await page.locator('[placeholder="Search for"]').fill('cosmos');
  await page.locator('[placeholder="Replace with"]').fill('COSMOS');
  await page.locator('text=All').nth(1).click(); // Replace All
  await page.locator('textarea').press('Escape');
  await page.locator('textarea').press('Control+f');
  await page.locator('[placeholder="Search for"]').fill('cosmos');
  await page.locator('text=3 of 3')
  await page.locator('text=Aa').click();
  await page.locator('text=0 of 0')
})
