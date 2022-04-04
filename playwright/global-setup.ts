// global-setup.ts
import { chromium, FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  const { baseURL } = config.projects[0].use;
  const browser = await chromium.launch();
  const page = await browser.newPage();

  await page.goto(`${baseURL}/login`);
  // Just wait a bit and ensure everything is truly loaded
  await new Promise((resolve) => setTimeout(resolve, 2000));

  // On the initial load you might get the Clock out of sync dialog
  if (await page.$('text=Clock out of sync')) {
    await page.locator('text=Don\'t show this again').click();
    await page.locator('button:has-text("Dismiss")').click();
  }

  if (await page.$('text=Enter the password')) {
    await page.fill('data-test=new-password', 'password');
    await page.locator('button:has-text("Login")').click();
  } else {
    await page.fill('data-test=new-password', 'password');
    await page.fill('data-test=confirm-password', 'password');
    await page.click('data-test=set-password');
  }

  // Save signed-in state to 'storageState.json'.
  await page.context().storageState({  path: 'storageState.json' });
  await browser.close();
};

export default globalSetup;
