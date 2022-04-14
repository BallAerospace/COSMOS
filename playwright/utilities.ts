import { Page, expect } from "@playwright/test";
import * as fs from "fs";
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
    await expect(this.page.locator("data-test=select-target")).toContainText(
      target
    );
    if (packet) {
      await this.page.locator("data-test=select-packet").click();
      await this.page
        .locator(`.v-list-item__title:text-matches("^${packet}$")`)
        .click();
      await expect(this.page.locator("data-test=select-packet")).toContainText(
        packet
      );
      if (item) {
        await this.page.locator("data-test=select-item").click();
        await this.page
          .locator(`.v-list-item__title:text-matches("^${item}$")`)
          .click();
        await expect(this.page.locator("data-test=select-item")).toContainText(
          item
        );
      } else {
        // If we're only selecting a packet wait for items to populate
        await this.sleep(500);
      }
    } else {
      // If we're only selecting a target wait for packets to populate
      await this.sleep(500);
    }
  }
  async addTargetPacketItem(target: string, packet: string, item: string) {
    await this.selectTargetPacketItem(target, packet, item);
    await this.page.locator('[data-test="select-send"]').click();
  }

  async download(page, locator, validator) {
    const [download] = await Promise.all([
      // Start waiting for the download
      page.waitForEvent("download"),
      // Initiate the download
      page.locator(locator).click(),
    ]);
    // Wait for the download process to complete
    const path = await download.path();
    const contents = await fs.readFileSync(path, {
      encoding: "utf-8",
    });
    validator(contents);
  }
}
