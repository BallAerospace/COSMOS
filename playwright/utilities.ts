import { Page, expect } from '@playwright/test'
import * as fs from 'fs'
export class Utilities {
  readonly page: Page
  constructor(page: Page) {
    this.page = page
  }
  async sleep(time) {
    await new Promise((resolve) => setTimeout(resolve, time))
  }
  async selectTargetPacketItem(target: string, packet: string, item: string) {
    await this.page.locator('[data-test=select-target] i').click()
    await this.page.locator(`div[role="option"] div:text-matches("^${target}$")`).click()
    expect(await this.page.inputValue('[data-test=select-target] input')).toMatch(target)
    if (packet) {
      await this.page.locator('[data-test=select-packet] i').click()
      await this.page.locator(`div[role="option"] div:text-matches("^${packet}$")`).click()
      expect(await this.page.inputValue('[data-test=select-packet] input')).toMatch(packet)
      if (item) {
        await this.page.locator('[data-test=select-item] i').click()
        await this.page.locator(`div[role="option"] div:text-matches("^${item}$")`).click()
        expect(await this.page.inputValue('[data-test=select-item] input')).toMatch(item)
      } else {
        // If we're only selecting a packet wait for items to populate
        await this.sleep(500)
      }
    } else {
      // If we're only selecting a target wait for packets to populate
      await this.sleep(500)
    }
  }
  async addTargetPacketItem(target: string, packet: string, item: string) {
    await this.selectTargetPacketItem(target, packet, item)
    await this.page.locator('[data-test="select-send"]').click()
  }

  async download(page, locator, validator = null) {
    const [download] = await Promise.all([
      // Start waiting for the download
      page.waitForEvent('download'),
      // Initiate the download
      page.locator(locator).click(),
    ])
    // Wait for the download process to complete
    const path = await download.path()
    const contents = await fs.readFileSync(path, {
      encoding: 'utf-8',
    })
    if (validator) {
      validator(contents)
    }
  }
}
