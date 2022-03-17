// @ts-check
import { test, expect } from '@playwright/test';
import { Utilities } from '../utilities';
import { format, add, sub } from 'date-fns'

let utils
test.beforeEach(async ({ page }) => {
  await page.goto('/tools/dataextractor');
  await expect(page.locator('body')).toContainText('Data Extractor');
  await page.locator('.v-app-bar__nav-icon').click()
  utils = new Utilities(page);
});

test('loads and saves the configuration', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')

  let config = 'spec' + Math.floor(Math.random() * 10000)
  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator('text=Save Configuration').click();
  await page.locator('[data-test="name-input-save-config-dialog"]').fill(config);
  await page.locator('button:has-text("Ok")').click();
  // Clear the success toast
  await page.locator('button:has-text("Dismiss")').click();

  // This also works but it relies on a Vuetify attribute
  // await expect(page.locator('[role=listitem]')).toHaveCount(2)
  await expect(page.locator('[data-test=itemList] > div')).toHaveCount(2)
  await page.locator('[data-test="deleteAll"]').click();
  await expect(page.locator('[data-test=itemList] > div')).toHaveCount(0)

  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator('text=Open Configuration').click();
  await page.locator(`td:has-text("${config}")`).click();
  await page.locator('button:has-text("Ok")').click();
  // Clear the success toast
  await page.locator('button:has-text("Dismiss")').click();
  await expect(page.locator('[data-test=itemList] > div')).toHaveCount(2)

  // Delete this test configuation
  await page.locator('[data-test="Data\\ Extractor-File"]').click();
  await page.locator('text=Open Configuration').click();
  // Note: Only works if you don't have any other configs saved
  await page.locator('[data-test="item-delete"]').click();
  await page.locator('button:has-text("Delete")').click();
  await page.locator('[data-test="open-config-cancel-btn"]').click();
});

test('validates dates and times', async ({ page }) => {
  // Date validation
  const d = new Date();
  await expect(page.locator('text=Required')).not.toBeVisible()
  await page.locator('[data-test=startDate]').fill('')
  await expect(page.locator('text=Required')).toBeVisible()
  // Since we just started we're only able to fill in the day
  await page.locator('[data-test=startDate]').type('01')
  await expect(page.locator('text=Required')).not.toBeVisible()
  // Time validation
  await page.locator('[data-test=startTime]').fill('')
  await expect(page.locator('text=Required')).toBeVisible()
  await page.locator('[data-test=startTime]').fill('12:15:15')
  await expect(page.locator('text=Required')).not.toBeVisible()
})

test("won't start with 0 items", async ({ page }) => {
  await expect(page.locator('text=Process')).toBeDisabled()
})

test('warns with duplicate item', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
  await page.locator('[data-test="select-send"]').click(); // Send again
  await expect(page.locator('text=This item has already been added')).toBeVisible()
})

test('warns with no time delta', async ({ page }) => {
  await utils.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
  await page.locator('text=Process').click();
  await expect(page.locator('text=Start date/time is equal to end date/time')).toBeVisible()
})

test('warns with no data', async ({ page }) => {
  const start = sub(new Date(), { seconds: 10 })
  await page.locator('[data-test=startTime]').fill(format(start, 'HH:mm:ss'))
  await page.locator('label:has-text("Command")').click();
  let utils = new Utilities(page);
  await utils.selectTargetPacketItem('INST', 'ARYCMD', 'RECEIVED_TIMEFORMATTED')
  await page.locator('text=Process').click();
  await expect(page.locator('text=No data found')).toBeVisible()
})

test('cancels a process', async ({ page }) => {
  const start = sub(new Date(), { minutes: 2 })
  await page.locator('[data-test=startTime]').fill(format(start, 'HH:mm:ss'))
  await page.locator('[data-test=endTime]').fill(format(add(start, { hours: 1 }), 'HH:mm:ss'))
  await utils.selectTargetPacketItem('INST', 'ADCS', 'CCSDSVER')
  await page.locator('text=Process').click();
  await expect(page.locator('text=End date/time is greater than current date/time')).toBeVisible()
  await new Promise(resolve => setTimeout(resolve, 2000)); // Allow the download to start

  const [ download ] = await Promise.all([
    // Start waiting for the download
    page.waitForEvent('download'),
    // Cancel initiates the download
    page.locator('text=Cancel').click(),
  ]);
  // Wait for the download process to complete
  await download.path();

  // Ensure the Cancel button goes back to Process
  await expect(page.locator('text=Process')).toBeVisible()
})

// test('adds an entire target', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.selectTargetPacketItem('INST')
//   cy.watest(1000)
//   cy.contains('Add Target').click()
//   cy.get('[data-test=itemList]')
//     .find('.v-list-item__content')
//     .should(($items) => {
//       expect($items.length).to.be.greaterThan(50) // Anything bigger than below
//     })
// })

// test('adds an entire packet', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS')
//   cy.contains('Add Packet').click()
//   cy.get('[data-test=itemList]')
//     .find('.v-list-item__content')
//     .should(($items) => {
//       expect($items.length).to.be.greaterThan(20)
//       expect($items.length).to.be.lessThan(50) // Less than the full target
//     })
// })

// test('add, edits, deletes items', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.get('[data-test=startTime]')
//     .clear()
//     .type(formatTime(start))
//   cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSVER')
//   cy.contains('Add Item').click()
//   cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSTYPE')
//   cy.contains('Add Item').click()
//   cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSSHF')
//   cy.contains('Add Item').click()
//   cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 3)
//   // Delete CCSDSVER
//   cy.get('[data-test=itemList]')
//     .find('.v-list-item')
//     .first()
//     .find('button')
//     .eq(1)
//     .click()
//   cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 2)
//   // Delete CCSDSTYPE
//   cy.get('[data-test=itemList]')
//     .find('.v-list-item')
//     .first()
//     .find('button')
//     .eq(1)
//     .click()
//   cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 1)
//   // Edit CCSDSSHF
//   cy.get('[data-test=itemList]')
//     .find('.v-list-item')
//     .first()
//     .find('button')
//     .first()
//     .click()
//   cy.get('.v-dialog:visible').within(() => {
//     cy.get('label').contains('Value Type').click()
//   })
//   cy.get('.v-list-item__title').contains('RAW').click()
//   cy.contains(/CCSDSSHF.*RAW/)
//   // TODO: Hack to close the dialog ... shouldn't be necessary if Vuetify focuses the dialog
//   // see https://github.com/vuetifyjs/vuetify/issues/11257
//   cy.get('.v-dialog:visible').within(() => {
//     cy.get('input').first().focus().type('{esc}', { force: true })
//   })
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.spltest('\n')
//     expect(lines[0]).to.contain('CCSDSSHF (RAW)')
//     expect(lines[1]).to.not.contain('FALSE')
//     expect(lines[1]).to.contain('0')
//   })
// })

// test('processes commands', async ({ page }) => {
//   // Preload an ABORT command
//   cy.vistest('/tools/cmdsender/INST/ABORT')
//   cy.hideNav()
//   // Make sure the Send button is enabled so we're ready
//   cy.get('[data-test=select-send]', { timeout: 20000 }).should('not.have.class', 'v-btn--disabled')
//   cy.get('[data-test=select-send]').click()
//   cy.watest(1000)
//   cy.contains('cmd("INST ABORT") sent')
//   cy.watest(500)

//   const start = sub(new Date(), { minutes: 5 })
//   cy.vistest('/tools/dataextractor')
//   cy.hideNav()
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   cy.get('[data-test=cmd-radio]').click({ force: true })
//   cy.selectTargetPacketItem('INST', 'ABORT', 'RECEIVED_TIMEFORMATTED')
//   cy.contains('Add Item').click()
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.spltest('\n')
//     expect(lines[1]).to.contain('INST')
//     expect(lines[1]).to.contain('ABORT')
//   })
// })

// test('creates CSV output', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 5 })
//   cy.get('.v-toolbar').contains('File').click({force: true})
//   cy.contains(/Comma Delimited/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
//   cy.contains('Add Item').click()
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
//   cy.contains('Add Item').click()
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     // Check that we handle raw value types set by the demo
//     expect(contents).to.contain('NaN')
//     expect(contents).to.contain('Infinity')
//     expect(contents).to.contain('-Infinity')
//     var lines = contents.spltest('\n')
//     expect(lines[0]).to.contain('TEMP1')
//     expect(lines[0]).to.contain('TEMP2')
//     expect(lines[0]).to.contain(',') // csv
//     expect(lines.length).to.be.greaterThan(290) // 5 min at 60Hz is 300 samples
//   })
// })

// test('creates tab delimited output', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 5 })
//   cy.get('.v-toolbar').contains('File').click({force: true})
//   cy.contains(/Tab Delimited/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
//   cy.contains('Add Item').click()
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
//   cy.contains('Add Item').click()
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.txt', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.spltest('\n')
//     expect(lines[0]).to.contain('TEMP1')
//     expect(lines[0]).to.contain('TEMP2')
//     expect(lines[0]).to.contain('\t')
//     expect(lines.length).to.be.greaterThan(290) // 5 min at 60Hz is 300 samples
//   })
// })

// test('outputs full column names', async ({ page }) => {
//   let start = sub(new Date(), { minutes: 1 })
//   cy.get('.v-toolbar').contains('Mode').click({force: true})
//   cy.contains(/Full Column Names/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
//   cy.contains('Add Item').click()
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
//   cy.contains('Add Item').click()
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.spltest('\n')
//     expect(lines[0]).to.contain('INST HEALTH_STATUS TEMP1')
//     expect(lines[0]).to.contain('INST HEALTH_STATUS TEMP2')
//   })
//   // Switch back and verify
//   cy.get('.v-toolbar').contains('Mode').click()
//   cy.contains(/Normal Columns/).click()
//   // Create a new end time so we get a new filename
//   start = sub(new Date(), { minutes: 2 })
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.spltest('\n')
//     expect(lines[0]).to.contain('TARGET,PACKET,TEMP1,TEMP2')
//   })
// })

// test('fills values', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.get('.v-toolbar').contains('Mode').click({force: true})
//   cy.contains(/Fill Down/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   // Deliberately test with two different packets
//   cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSSEQCNT')
//   cy.contains('Add Item').click()
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSSEQCNT')
//   cy.contains('Add Item').click()
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.spltest('\n')
//     expect(lines[0]).to.contain('CCSDSSEQCNT')
//     var firstHS = -1
//     for (let i = 1; i < lines.length; i++) {
//       if (firstHS !== -1) {
//         var [tgt1, pkt1, hs1, adcs1] = lines[firstHS].spltest(',')
//         var [tgt2, pkt2, hs2, adcs2] = lines[i].spltest(',')
//         expect(tgt1).to.eq(tgt2) // Both INST
//         expect(pkt1).to.eq('HEALTH_STATUS')
//         expect(pkt2).to.eq('ADCS')
//         expect(parseInt(adcs1) + 1).to.eq(parseInt(adcs2)) // ADCS goes up by one each time
//         expect(parseInt(hs1)).to.be.greaterThan(1) // Double check for a value
//         expect(hs1).to.eq(hs2) // HEALTH_STATUS should be the same
//         break
//       } else if (lines[i].includes('HEALTH_STATUS')) {
//         // Look for the first line containing HEALTH_STATUS
//         console.log('Found first HEALTH_STATUS on line ' + i)
//         firstHS = i
//       }
//     }
//   })
// })

// test('adds Matlab headers', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.get('.v-toolbar').contains('Mode').click({force: true})
//   cy.contains(/Matlab Header/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   cy.selectTargetPacketItem('INST', 'ADCS', 'Q1')
//   cy.contains('Add Item').click()
//   cy.selectTargetPacketItem('INST', 'ADCS', 'Q2')
//   cy.contains('Add Item').click()
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     var lines = contents.spltest('\n')
//     expect(lines[0]).to.contain('% TARGET,PACKET,Q1,Q2')
//   })
// })

// test('outputs unique values only', async ({ page }) => {
//   const start = sub(new Date(), { minutes: 1 })
//   cy.get('.v-toolbar').contains('Mode').click({force: true})
//   cy.contains(/Unique Only/).click({force: true})
//   cy.get('[data-test=startTime]')
//     .clear({ force: true })
//     .type(formatTime(start))
//   cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSVER')
//   cy.contains('Add Item').click()
//   cy.contains('Process').click()
//   cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv', {
//     timeout: 20000,
//   }).then((contents) => {
//     console.log(contents)
//     var lines = contents.spltest('\n')
//     expect(lines[0]).to.contain('CCSDSVER')
//     expect(lines.length).to.eq(2) // header and a single value
//   })
// })

// Playwright Test Generator output:
//   // Click label:has-text("Command")
//   await page.locator('label:has-text("Command")').click();
//   // Click text=Day
//   await page.locator('text=Day').click();
//   // Click .v-input--radio-group__input div:nth-child(2) .v-input--selection-controls__input .v-input--selection-controls__ripple >> nth=0
//   await page.locator('.v-input--radio-group__input div:nth-child(2) .v-input--selection-controls__input .v-input--selection-controls__ripple').first().click();
//   // Click div[role="button"]:has-text("Select Item")
//   await page.locator('div[role="button"]:has-text("Select Item")').click();
//   // Click div:nth-child(4) .col .v-input .v-input__control .v-input__slot .v-input--radio-group__input div .v-input--selection-controls__input .v-input--selection-controls__ripple >> nth=0
//   await page.locator('div:nth-child(4) .col .v-input .v-input__control .v-input__slot .v-input--radio-group__input div .v-input--selection-controls__input .v-input--selection-controls__ripple').first().click();
//   // Click div[role="button"]:has-text("Select ItemTEMP1")
//   await page.locator('div[role="button"]:has-text("Select ItemTEMP1")').click();
//   // Click #list-item-293-13 div:has-text("TEMP2") >> nth=0
//   await page.locator('#list-item-293-13 div:has-text("TEMP2")').first().click();
//   // Click [data-test="select-send"]
//   await page.locator('[data-test="select-send"]').click();
//   // Click div[role="button"]:has-text("Select ItemTEMP2")
//   await page.locator('div[role="button"]:has-text("Select ItemTEMP2")').click();
//   // Click text=TEMP3
//   await page.locator('text=TEMP3').click();
//   // Click [data-test="select-send"]
//   await page.locator('[data-test="select-send"]').click();
//   // Click .v-icon.notranslate.v-icon--link >> nth=0
//   await page.locator('.v-icon.notranslate.v-icon--link').first().click();
//   // Click text=​Value TypeCONVERTED
//   await page.locator('text=​Value TypeCONVERTED').click();
//   // Click text=RAW
//   await page.locator('text=RAW').click();
//   // Click button:has-text("Ok")
//   await page.locator('button:has-text("Ok")').click();
//   // Click .v-list div:nth-child(2) .v-list-item div .v-icon >> nth=0
//   await page.locator('.v-list div:nth-child(2) .v-list-item div .v-icon').first().click();
//   // Click text=Edit INST - HEALTH_STATUS - TEMP2​Value TypeCONVERTED Ok >> button
//   await page.locator('text=Edit INST - HEALTH_STATUS - TEMP2​Value TypeCONVERTED Ok >> button').click();
//   // Click div:nth-child(3) .v-list-item div .v-icon >> nth=0
//   await page.locator('div:nth-child(3) .v-list-item div .v-icon').first().click();
//   // Click text=Edit INST - HEALTH_STATUS - TEMP3​Value TypeCONVERTED Ok >> button
//   await page.locator('text=Edit INST - HEALTH_STATUS - TEMP3​Value TypeCONVERTED Ok >> button').click();
// });