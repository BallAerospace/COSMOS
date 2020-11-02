import { format, add, sub } from 'date-fns'

function formatTime(date) {
  return format(date, 'HH:mm:ss')
}
function formatFilename(date) {
  return format(date, 'yyyy_MM_dd_HH_mm_ss')
}

describe('DataExtractor', () => {
  it('loads and saves the configuration', function () {
    const now = new Date()
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()

    let config = 'spec' + Math.floor(Math.random() * 10000)
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save Configuration').click()
    cy.get('.v-dialog').within(() => {
      cy.get('input').clear().type(config)
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')

    cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 2)
    cy.get('[data-test=deleteAll]').click()
    cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 0)

    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open Configuration').click()
    cy.get('.v-dialog').within(() => {
      cy.contains(config).click()
      cy.contains('Ok').click()
    })
    cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 2)

    // Delete this test configuation
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open Configuration').click()
    cy.get('.v-dialog').within(() => {
      cy.contains(config)
        .parents('.v-list-item')
        .eq(0)
        .within(() => {
          cy.get('button').click()
        })
      cy.contains('Cancel').click()
    })
  })

  it('validates dates and times', function () {
    cy.visit('/data-extractor')
    cy.hideNav()
    // Date validation
    cy.get('[data-test=startDate]').clear()
    cy.get('.container').should('contain', 'Required')
    cy.get('[data-test=startDate]').type('2020/01/01') // Must use '-' separator
    cy.get('.container').should('contain', 'Invalid date')
    cy.get('[data-test=startDate]').clear().type('2020-01-32') // Format valid but impossible date
    cy.get('.container').should('contain', 'Invalid date')
    cy.get('[data-test=startDate]').clear().type('2020-01-01') // Valid!
    cy.get('.container').should('not.contain', 'Invalid')
    // Time validation
    cy.get('[data-test=startTime]').clear()
    cy.get('.container').should('contain', 'Required')
    cy.get('[data-test=startTime]').type('12-15-15') // Must use ':' separator
    cy.get('.container').should('contain', 'Invalid time')
    cy.get('[data-test=startTime]').clear().type('12:15:61') // Format valid but impossible time
    cy.get('.container').should('contain', 'Invalid time')
    cy.get('[data-test=startTime]').clear().type('12:15:15')
    cy.get('.container').should('not.contain', 'Invalid')
  })

  it('warns with no items', function () {
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.contains('Process').click()
    cy.contains('No items to process').should('be.visible')
  })

  it('warns with duplicate item', function () {
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Add Item').click()
    cy.contains('This item has already been added').should('be.visible')
  })

  it('warns with no time delta', function () {
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.contains('Start date/time is equal to end date/time').should(
      'be.visible'
    )
  })

  it('warns with no data', function () {
    const start = sub(new Date(), { seconds: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.get('[data-test=cmd-radio]').click({ force: true })
    cy.selectTargetPacketItem('INST', 'ABORT', 'RECEIVED_TIMEFORMATTED')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.contains('No data found').should('be.visible')
  })

  it('cancels a process', function () {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.get('[data-test=endTime]')
      .clear()
      .type(formatTime(add(start, { hours: 1 })))
    cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSVER')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.contains('End date/time is greater than current date/time').should(
      'be.visible'
    )
    cy.wait(1000)
    cy.contains('Cancel').click()
    // Verify the Cancel button goes back to Process
    cy.contains('Process')
    // Verify we still get a file
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv')
  })

  it('adds an entire target', function () {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.contains('Add Target').click()
    cy.get('[data-test=itemList]')
      .find('.v-list-item')
      .should(($items) => {
        expect($items.length).to.be.greaterThan(50) // Anything bigger than below
      })
  })

  it('adds an entire packet', function () {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS')
    cy.contains('Add Packet').click()
    cy.get('[data-test=itemList]')
      .find('.v-list-item')
      .should(($items) => {
        expect($items.length).to.be.greaterThan(20)
        expect($items.length).to.be.lessThan(50) // Less than the full target
      })
  })

  it('add, edits, deletes items', function () {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSVER')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSTYPE')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSSHF')
    cy.contains('Add Item').click()
    cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 3)
    // Delete CCSDSVER
    cy.get('[data-test=itemList]')
      .find('.v-list-item')
      .first()
      .find('button')
      .eq(1)
      .click()
    cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 2)
    // Delete CCSDSTYPE
    cy.get('[data-test=itemList]')
      .find('.v-list-item')
      .first()
      .find('button')
      .eq(1)
      .click()
    cy.get('[data-test=itemList]').find('.v-list-item').should('have.length', 1)
    // Edit CCSDSSHF
    cy.get('[data-test=itemList]')
      .find('.v-list-item')
      .first()
      .find('button')
      .first()
      .click()
    cy.get('.v-dialog').within(() => {
      cy.get('label').contains('Value Type').click({ force: true })
    })
    cy.get('.v-list-item__title').contains('RAW').click()
    cy.contains('INST - ADCS - CCSDSSHF (RAW)')
    // TODO: Hack to close the dialog ... shouldn't be necessary if Vuetify focuses the dialog
    // see https://github.com/vuetifyjs/vuetify/issues/11257
    cy.get('.v-dialog').within(() => {
      cy.get('input').first().focus().type('{esc}', { force: true })
    })
    cy.contains('Process').click({ force: true })
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      (contents) => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('CCSDSSHF (RAW)')
        expect(lines[1]).to.not.contain('FALSE')
        expect(lines[1]).to.contain('0')
      }
    )
  })

  it('processes commands', function () {
    // Preload an ABORT command
    cy.visit('/command-sender/INST/ABORT')
    cy.hideNav()
    cy.get('button').contains('Send').click()
    cy.contains('cmd("INST ABORT") sent')

    const start = sub(new Date(), { minutes: 5 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.get('[data-test=cmd-radio]').click({ force: true })
    cy.selectTargetPacketItem('INST', 'ABORT', 'RECEIVED_TIMEFORMATTED')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      (contents) => {
        var lines = contents.split('\n')
        expect(lines[1]).to.contain('INST')
        expect(lines[1]).to.contain('ABORT')
      }
    )
  })

  it('creates CSV output', function () {
    const start = sub(new Date(), { minutes: 5 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('.v-toolbar').contains('File').click()
    cy.contains(/Comma Delimited/).click()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      (contents) => {
        // Check that we handle raw value types set by the demo
        expect(contents).to.contain('NaN')
        expect(contents).to.contain('Infinity')
        expect(contents).to.contain('-Infinity')
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('TEMP1')
        expect(lines[0]).to.contain('TEMP2')
        expect(lines[0]).to.contain(',') // csv
        expect(lines.length).to.be.greaterThan(300) // 5 min at 60Hz is 300 samples
      }
    )
  })

  it('creates tab delimited output', function () {
    const start = sub(new Date(), { minutes: 5 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('.v-toolbar').contains('File').click()
    cy.contains(/Tab Delimited/).click()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.txt').then(
      (contents) => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('TEMP1')
        expect(lines[0]).to.contain('TEMP2')
        expect(lines[0]).to.contain('\t')
        expect(lines.length).to.be.greaterThan(300) // 5 min at 60Hz is 300 samples
      }
    )
  })

  it('outputs full column names', function () {
    let start = sub(new Date(), { minutes: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('.v-toolbar').contains('Mode').click()
    cy.contains(/Full Column Names/).click()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      (contents) => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('INST HEALTH_STATUS TEMP1')
        expect(lines[0]).to.contain('INST HEALTH_STATUS TEMP2')
      }
    )
    // Switch back and verify
    cy.get('.v-toolbar').contains('Mode').click()
    cy.contains(/Normal Columns/).click()
    // Create a new end time so we get a new filename
    start = sub(new Date(), { minutes: 2 })
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      (contents) => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('TARGET,PACKET,TEMP1,TEMP2')
      }
    )
  })

  it('fills values', function () {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('.v-toolbar').contains('Mode').click()
    cy.contains(/Fill Down/).click()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    // Deliberately test with two different packets
    cy.selectTargetPacketItem('INST', 'ADCS', 'CCSDSSEQCNT')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSSEQCNT')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      (contents) => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('CCSDSSEQCNT')
        var firstHS = -1
        for (let i = 1; i < lines.length; i++) {
          if (firstHS !== -1) {
            var [tgt1, pkt1, hs1, adcs1] = lines[firstHS].split(',')
            var [tgt2, pkt2, hs2, adcs2] = lines[i].split(',')
            expect(tgt1).to.eq(tgt2) // Both INST
            expect(pkt1).to.eq('HEALTH_STATUS')
            expect(pkt2).to.eq('ADCS')
            expect(parseInt(adcs1) + 1).to.eq(parseInt(adcs2)) // ADCS goes up by one each time
            expect(parseInt(hs1)).to.be.greaterThan(1) // Double check for a value
            expect(hs1).to.eq(hs2) // HEALTH_STATUS should be the same
            break
          }
          // Look for the first line containing HEALTH_STATUS
          if (lines[i].includes('HEALTH_STATUS')) {
            firstHS = i
          }
        }
      }
    )
  })

  it('adds Matlab headers', function () {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('.v-toolbar').contains('Mode').click()
    cy.contains(/Matlab Header/).click()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.selectTargetPacketItem('INST', 'ADCS', 'Q1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'Q2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      (contents) => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('% TARGET,PACKET,Q1,Q2')
      }
    )
  })

  it('outputs unique values only', function () {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/data-extractor')
    cy.hideNav()
    cy.get('.v-toolbar').contains('Mode').click()
    cy.contains(/Unique Only/).click()
    cy.get('[data-test=startTime]').clear().type(formatTime(start))
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSVER')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      (contents) => {
        console.log(contents)
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('CCSDSVER')
        expect(lines.length).to.eq(2) // header and a single value
      }
    )
  })
})
