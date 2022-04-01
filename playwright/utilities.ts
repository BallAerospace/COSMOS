import { Page, expect } from "@playwright/test";
export class Utilities {
  readonly page: Page;
  constructor(page: Page) {
    this.page = page;
  }
  async sleep(time) {
    await new Promise((resolve) => setTimeout(resolve, time));
  }
  async selectTargetPacketItem(target: string, packet: string, item: string) {
    await this.page.locator("data-test=select-target").click();
    await this.page
      .locator(`.v-list-item__title:text-matches("^${target}$")`)
      .click();
    await expect(this.page.locator("data-test=select-target")).toContainText(target)
    if (packet) {
      await this.page.locator("data-test=select-packet").click();
      await this.page
        .locator(`.v-list-item__title:text-matches("^${packet}$")`)
        .click();
      await expect(this.page.locator("data-test=select-packet")).toContainText(packet)
      if (item) {
        await this.page.locator("data-test=select-item").click();
        await this.page
          .locator(`.v-list-item__title:text-matches("^${item}$")`)
          .click();
        await expect(this.page.locator("data-test=select-item")).toContainText(item)
      }
    }
  }
  async addTargetPacketItem(target: string, packet: string, item: string) {
    await this.selectTargetPacketItem(target, packet, item);
    await this.page.locator('[data-test="select-send"]').click();
  }
}
