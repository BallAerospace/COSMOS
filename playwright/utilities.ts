import { Page } from '@playwright/test';
export class Utilities {
  readonly page: Page
  constructor(page:Page) {
    this.page=page
  }
  async selectTargetPacketItem(target: string, packet: string, item: string) {
    await this.page.locator('data-test=select-target').click();
    await this.page.locator(`.v-list-item__title:text-matches("^${target}$")`).click();
    if (packet) {
      await this.page.locator('data-test=select-packet').click();
      await this.page.locator(`.v-list-item__title:text-matches("^${packet}$")`).click();
      if (item) {
        await this.page.locator('data-test=select-item').click();
        await this.page.locator(`.v-list-item__title:text-matches("^${item}$")`).click();
      }
    }
    await this.page.locator('[data-test="select-send"]').click();
  }
}
