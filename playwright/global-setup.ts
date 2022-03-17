// global-setup.ts
import { chromium, FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  const { baseURL } = config.projects[0].use;
  const browser = await chromium.launch();
  const page = await browser.newPage();

  await page.goto(`${baseURL}/login`);

  if (await page.$('text=Create a')) {
    await page.fill('data-test=new-password', 'password');
    await page.fill('data-test=confirm-password', 'password');
    await page.click('data-test=set-password');
  } else {
    await page.locator('text=Enter the password')
    await page.fill('data-test=new-password', 'password');
    await page.locator('button:has-text("Login")').click();
  }

  // Save signed-in state to 'storageState.json'.
  await page.context().storageState({  path: 'storageState.json' });
  await browser.close();
};

export default globalSetup;
