import { format, sub } from 'date-fns'

function formatDate(date) {
  return format(date, 'yyyy-MM-dd')
}
function formatTime(date) {
  return format(date, 'HH:mm:ss')
}
function formatFilename(date) {
  return format(date, 'yyyy_MM_dd_HH_mm_ss')
}

describe('TlmExtractor', () => {
  it('loads and saves the configuration', function() {
    const now = new Date()
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()

    let config = 'spec' + Math.floor(Math.random() * 10000)
    cy.get('.v-toolbar')
      .contains('File')
      .click()
    cy.contains('Save Configuration').click()
    cy.get('.v-dialog').within(() => {
      cy.get('input')
        .clear()
        .type(config)
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog').should('not.be.visible')

    cy.get('[data-test=itemList]')
      .find('.v-list-item')
      .should('have.length', 2)
    cy.get('[data-test=deleteAll]').click()
    cy.get('[data-test=itemList]')
      .find('.v-list-item')
      .should('have.length', 0)

    cy.get('.v-toolbar')
      .contains('File')
      .click()
    cy.contains('Open Configuration').click()
    cy.get('.v-dialog').within(() => {
      cy.contains(config).click()
      cy.contains('Ok').click()
    })
    cy.get('[data-test=itemList]')
      .find('.v-list-item')
      .should('have.length', 2)

    // Delete this test configuation
    cy.get('.v-toolbar')
      .contains('File')
      .click()
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

  it('triggers warning with duplicate item', function() {
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.contains('Add Item').click()
    cy.contains('Add Item').click()
    cy.contains('This item has already been added').should('be.visible')
  })

  it('creates CSV output', function() {
    const start = sub(new Date(), { minutes: 5 })
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('[data-test=startTime]')
      .clear()
      .type(formatTime(start))
    cy.focused().click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      contents => {
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

  it('creates tab delimited output', function() {
    const start = sub(new Date(), { minutes: 5 })
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('.v-toolbar')
      .contains('File')
      .click()
    cy.contains(/Tab Delimited/).click()
    cy.get('[data-test=startTime]')
      .clear()
      .type(formatTime(start))
    cy.focused().click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.txt').then(
      contents => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('TEMP1')
        expect(lines[0]).to.contain('TEMP2')
        expect(lines[0]).to.contain('\t')
        expect(lines.length).to.be.greaterThan(300) // 5 min at 60Hz is 300 samples
      }
    )
  })

  it('outputs full column names', function() {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('.v-toolbar')
      .contains('Mode')
      .click()
    cy.contains(/Full Column Names/).click()
    cy.get('[data-test=startTime]')
      .clear()
      .type(formatTime(start))
    cy.focused().click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'TEMP2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      contents => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('INST HEALTH_STATUS TEMP1')
        expect(lines[0]).to.contain('INST HEALTH_STATUS TEMP2')
      }
    )
  })

  it('outputs Matlab headers', function() {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('.v-toolbar')
      .contains('Mode')
      .click()
    cy.contains(/Matlab Header/).click()
    cy.get('[data-test=startTime]')
      .clear()
      .type(formatTime(start))
    cy.focused().click({ force: true })
    cy.selectTargetPacketItem('INST', 'ADCS', 'Q1')
    cy.contains('Add Item').click()
    cy.selectTargetPacketItem('INST', 'ADCS', 'Q2')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      contents => {
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('% TARGET,PACKET,Q1,Q2')
      }
    )
  })

  it('outputs unique values only', function() {
    const start = sub(new Date(), { minutes: 1 })
    cy.visit('/telemetry-extractor')
    cy.hideNav()
    cy.get('.v-toolbar')
      .contains('Mode')
      .click()
    cy.contains(/Unique Only/).click()
    cy.get('[data-test=startTime]')
      .clear()
      .type(formatTime(start))
    cy.focused().click({ force: true })
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS', 'CCSDSVER')
    cy.contains('Add Item').click()
    cy.contains('Process').click()
    cy.readFile('cypress/downloads/' + formatFilename(start) + '.csv').then(
      contents => {
        console.log(contents)
        var lines = contents.split('\n')
        expect(lines[0]).to.contain('CCSDSVER')
        expect(lines.length).to.eq(3) // header and a single value plus a newline
      }
    )
  })
})
