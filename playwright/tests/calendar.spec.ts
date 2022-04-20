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
import { test, expect } from 'playwright-test-coverage'
import { format, add, sub } from 'date-fns'

import { Utilities } from '../utilities'

let utils
test.beforeEach(async ({ page }) => {
  await page.goto('/tools/calendar')
  await expect(page.locator('body')).toContainText('Calendar')
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page)
})

async function formatTime(date) {
  return format(date, 'HH:mm:ss')
}

async function formatDate(date) {
  return format(date, 'yyyy-MM-dd')
}

//
// Test the basic functionality of the application
//
test('test top bar functionality', async ({ page }) => {
  // test the day calendar view
  await page.locator('[data-test=change-type]').click()
  await page.locator('[data-test=type-day]').click()
  await page.locator('[data-test=prev]').click()
  await page.locator('[data-test=next]').click()
  // test the four day calendar view
  await page.locator('[data-test=change-type]').click()
  await page.locator('[data-test=type-four-day]').click()
  await page.locator('[data-test=prev]').click()
  await page.locator('[data-test=next]').click()
  // test the week calendar view
  await page.locator('[data-test=change-type]').click()
  await page.locator('[data-test=type-week]').click()
  await page.locator('[data-test=prev]').click()
  await page.locator('[data-test=next]').click()
  // test the today button
  await page.locator('[data-test=today]').click()
  // test the mini calendar
  await page.locator('[data-test=mini-prev]').click()
  await page.locator('[data-test=mini-next]').click()

  // test settings functionality

  // refresh
  await page.locator('[data-test=settings]').click()
  await page.locator('[data-test=refresh]').click()
  // display time in utc
  await page.locator('[data-test=settings]').click()
  await page.locator('[data-test=display-utc-time]').click()
  // download event list
  await page.locator('[data-test=settings]').click()
  await utils.download(page, '[data-test=download-event-list]', function (contents) {
    expect(contents).toContain('') // % is empty
  })
})

test('test create narration functionality', async ({ page }) => {
  //
  const stopDateTime = add(new Date(), { minutes: 30 })
  const stopDate = await formatDate(stopDateTime)
  const stopTime = await formatTime(stopDateTime)
  // Click create dropdown
  await page.locator('[data-test=create-event]').click()
  await page.locator('[data-test=narrative]').click()
  // Fill
  await page.locator('[data-test=narrative-stop-date]').fill(stopDate)
  await page.locator('[data-test=narrative-stop-time]').fill(stopTime)
  // step two
  await page.locator('[data-test=create-narrative-step-two-btn]').click()
  await page.locator('[data-test=create-narrative-description]').fill('Cancel this test')
  await page.locator('[data-test=create-narrative-cancel-btn]').click()
  // Click create dropdown
  await page.locator('[data-test=create-event]').click()
  await page.locator('[data-test=narrative]').click()
  // Fill
  await page.locator('[data-test=narrative-stop-date]').fill(stopDate)
  await page.locator('[data-test=narrative-stop-time]').fill(stopTime)
  // step two
  await page.locator('[data-test=create-narrative-step-two-btn]').click()
  await page.locator('[data-test=create-narrative-description]').click()
  await page.locator('[data-test=create-narrative-description]').fill('Another test')
  await page.locator('[data-test=create-narrative-submit-btn]').click()
})

test('test create metadata functionality', async ({ page }) => {
  //
  const startDateTime = sub(new Date(), { minutes: 30 })
  const startDate = await formatDate(startDateTime)
  const startTime = await formatTime(startDateTime)
  // Click create dropdown
  await page.locator('[data-test=create-event]').click()
  await page.locator('[data-test=metadata]').click()
  // Fill
  await page.locator('text=Input Metadata Time').click()
  await page.locator('[data-test=metadata-start-date]').fill(startDate)
  await page.locator('[data-test=metadata-start-time]').fill(startTime)
  // step two
  await page.locator('[data-test=create-metadata-step-two-btn]').click()
  await page.locator('[data-test=new-metadata-icon]').click()
  await page.locator('[data-test=key-0]').fill('version')
  await page.locator('[data-test=value-0]').fill('0')
  await page.locator('[data-test=new-metadata-icon]').click()
  await page.locator('[data-test=key-1]').fill('remove')
  await page.locator('[data-test=value-1]').fill('this')
  await page.locator('[data-test=delete-metadata-icon-1]').click()
  await page.locator('[data-test=create-metadata-cancel-btn]').click()
  // Click create dropdown
  await page.locator('[data-test=create-event]').click()
  await page.locator('[data-test=metadata]').click()
  // Fill
  await page.locator('text=Input Metadata Time').click()
  await page.locator('[data-test=metadata-start-date]').fill(startDate)
  await page.locator('[data-test=metadata-start-time]').fill(startTime)
  // step two
  await page.locator('[data-test=create-metadata-step-two-btn]').click()
  await page.locator('[data-test=new-metadata-icon]').click()
  await page.locator('[data-test=key-0]').fill('version')
  await page.locator('[data-test=value-0]').fill('1')
  await page.locator('[data-test=create-metadata-submit-btn]').click()
})

test('test create timeline functionality', async ({ page }) => {
  //
  await page.locator('[data-test=create-timeline]').click()
  await page.locator('[data-test=input-timeline-name]').fill('Alpha')
  await page.locator('[data-test=create-timeline-cancel-btn]').click()
  //
  await page.locator('[data-test=create-timeline]').click()
  await page.locator('[data-test=input-timeline-name]').fill('Alpha')
  await page.locator('[data-test=create-timeline-submit-btn]').click()
})

test('test create activity functionality', async ({ page }) => {
  //
  const startDateTime = add(new Date(), { minutes: 90 })
  const startDate = await formatDate(startDateTime)
  const startTime = await formatTime(startDateTime)
  //
  const stopDateTime = add(new Date(), { minutes: 95 })
  const stopDate = await formatDate(stopDateTime)
  const stopTime = await formatTime(stopDateTime)
  // click create dropdown
  await page.locator('[data-test=create-event]').click()
  await page.locator('[data-test=activity]').click()
  // v-select timeline
  await page.locator('[data-test=activity-select-timeline]').click()
  await page.locator('[data-test=activity-select-timeline-Alpha]').click()
  // Fill
  await page.locator('[data-test=activity-start-date]').fill(startDate)
  await page.locator('[data-test=activity-start-time]').fill(startTime)
  await page.locator('[data-test=activity-stop-date]').fill(stopDate)
  await page.locator('[data-test=activity-stop-time]').fill(stopTime)
  // step two
  await page.locator('[data-test=create-activity-step-two-btn]').click()
  // select reserve
  await page.locator('[data-test=activity-select-type]').click()
  await page.locator('[data-test=activity-select-type-RESERVE]').click()
  // select script
  await page.locator('[data-test=activity-select-type]').click()
  await page.locator('[data-test=activity-select-type-SCRIPT]').click()
  // input command
  await page.locator('[data-test=activity-select-type]').click()
  await page.locator('[data-test=activity-select-type-COMMAND]').click()
  await page.locator('[data-test=activity-cmd]').fill('FOO CLEAR')
  await page.locator('[data-test=create-activity-cancel-btn]').click()

  // click create dropdown
  await page.locator('[data-test=create-event]').click()
  await page.locator('[data-test=activity]').click()
  // v-select timeline
  await page.locator('[data-test=activity-select-timeline]').click()
  await page.locator('[data-test=activity-select-timeline-Alpha]').click()
  // Fill
  await page.locator('[data-test=activity-start-date]').fill(startDate)
  await page.locator('[data-test=activity-start-time]').fill(startTime)
  await page.locator('[data-test=activity-stop-date]').fill(stopDate)
  await page.locator('[data-test=activity-stop-time]').fill(stopTime)
  // step two
  await page.locator('[data-test=create-activity-step-two-btn]').click()
  // input command
  await page.locator('[data-test=activity-select-type]').click()
  await page.locator('[data-test=activity-select-type-COMMAND]').click()
  await page.locator('[data-test=activity-cmd]').fill('INST CLEAR')
  await page.locator('[data-test=create-activity-submit-btn]').click()
})

test.fixme('test timeline select and activity delete functionality', async ({ page }) => {
  //
  await page.locator('text=DEFAULT metadata').click()
  await page.locator('#cosmos-menu >> text=Calendar').click()
  //
  await page.locator('text=DEFAULT metadata').click()
  await page.locator('[data-test=delete-metadata]').click()
  await page.locator('button:has-text("Delete")').click()
  //
  await page.locator('text=Another test').click()
  await page.locator('#cosmos-menu >> text=Calendar').click()
  //
  await page.locator('text=Another test').click()
  await page.locator('[data-test=delete-narration]').click()
  await page.locator('button:has-text("Delete")').click()
  //
  await page.locator('[data-test=select-timeline-Alpha]').click()
  //
  await page.locator('text=Alpha command').click()
  await page.locator('#cosmos-menu >> text=Calendar').click()
  //
  await page.locator('text=Alpha command').click()
  await page.locator('[data-test=delete-activity]').click()
  await page.locator('button:has-text("Delete")').click()
})

test.fixme('test delete timeline functionality', async ({ page }) => {
  //
  await page.locator('[data-test=Alpha-options]').click()
  await page.locator('[data-test=Alpha-delete]').click()
  await page.locator('button:has-text("Cancel")').nth(1).click()
  //
  await page.locator('[data-test=Alpha-options]').click()
  await page.locator('[data-test=Alpha-delete]').click()
  await page.locator('button:has-text("Delete")').nth(1).click()
})
