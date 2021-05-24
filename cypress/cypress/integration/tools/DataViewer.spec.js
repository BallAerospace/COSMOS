/*
# Copyright 2021 Ball Aerospace & Technologies Corp.
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

import { format } from 'date-fns'

describe('DataViewer', () => {
  beforeEach(() => {
    cy.task('clearDownloads')
    cy.visit('/tools/dataviewer')
    cy.hideNav()
  })

  it('adds a raw packet to a new tab', () => {
    cy.hideNav()
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').should('be.visible').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.wait(100) // wait for the first packet to come in
    cy.get('[data-test=dump-component-text-area]').should('not.have.value', '')
  })

  it('adds a decom packet to a new tab', () => {
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=new-packet-decom-radio]').check({ force: true })
    cy.get('[data-test=add-packet-value-type]').should('be.visible')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.wait(100) // wait for the first packet to come in
    // add another packet to the existing connection
    cy.get('[data-test=new-packet]').click()
    cy.selectTargetPacketItem('INST', 'HEALTH_STATUS')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=dump-component-text-area]').should('not.have.value', '')
  })

  it('renames a tab', () => {
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=tab').rightclick()
    cy.get('[data-test=context-menu-rename]').click()
    cy.get('[data-test=rename-tab-input]').clear().type('Testing tab name')
    cy.get('[data-test=rename]').click()
    cy.get('.v-tab').should('contain', 'Testing tab name')
    cy.get('[data-test=tab').rightclick()
    cy.get('[data-test=context-menu-rename]').click()
    cy.get('[data-test=rename-tab-input]').clear().type('Cancel this')
    cy.get('[data-test=cancel-rename]').click()
    cy.get('.v-tab').should('contain', 'Testing tab name')
  })

  it('deletes a component and tab', () => {
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('.v-window-item > .v-card > .v-card__title').should(
      'contain',
      'INST ADCS'
    )
    cy.get('[data-test=delete-packet').click()
    cy.get('.v-window-item > .v-card > .v-card__title').should(
      'contain',
      'This tab is empty'
    )
    cy.get('[data-test=tab').rightclick()
    cy.get('[data-test=context-menu-delete]').click()
    cy.get(':nth-child(4) > .v-card > .v-card__title').should(
      'contain',
      "You're not viewing any packets"
    )
  })

  it('controls playback', () => {
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.wait(100) // wait for the first packet to come in

    cy.get('[data-test=dump-component-play-pause]').click()
    cy.get('[data-test=dump-component-text-area]')
      .invoke('val')
      .then((val) => {
        // ensure it paused
        cy.wait(500)
        cy.get('[data-test=dump-component-text-area]').should('have.value', val)

        // check stepper buttons
        cy.get(
          '.container > :nth-child(2) > .col > .v-input > .v-input__prepend-outer > .v-input__icon > .v-icon'
        ).click() // step back
        cy.get('[data-test=dump-component-text-area]').should(
          'not.have.value',
          val
        )
        cy.get('.v-input__append-outer > .v-input__icon > .v-icon').click() // step forward
        cy.get('[data-test=dump-component-text-area]').should('have.value', val)

        // ensure it resumes
        cy.get('[data-test=dump-component-play-pause]').click()
        cy.get('[data-test=dump-component-text-area]').should(
          'not.have.value',
          val
        )

        cy.get('[data-test=stop-button]').click()
        cy.wait(200) // give it time to unsubscribe and stop receiving packets
        return cy.get('[data-test=dump-component-text-area]').invoke('val')
      })
      .then((val) => {
        // ensure it stopped
        cy.wait(500)
        cy.get('[data-test=dump-component-text-area]').should('have.value', val)
      })
  })

  it('changes display settings', () => {
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.wait(100) // wait for the first packet to come in

    cy.get('[data-test=dump-component-open-settings]').click()
    cy.wait(100) // give the dialog time to open
    cy.get('[data-test=display-settings-card]').should('be.visible')
    cy.get('[data-test=dump-component-settings-format-ascii]').check({
      force: true,
    })
    cy.get('[data-test=dump-component-settings-newest-top]').check({
      force: true,
    })
    cy.get('[data-test=dump-component-settings-show-address]').check({
      force: true,
    })
    cy.get('[data-test=dump-component-settings-show-timestamp]').check({
      force: true,
    })

    // check number input validation
    cy.get('[data-test=dump-component-settings-num-bytes]')
      .clear()
      .type('0{enter}')
    cy.get('[data-test=dump-component-settings-num-bytes]')
      .invoke('val')
      .then((val) => {
        expect(val).to.eq('1')
      })
    cy.get('[data-test=dump-component-settings-num-packets]')
      .clear()
      .type('0{enter}')
    cy.get('[data-test=dump-component-settings-num-packets]')
      .invoke('val')
      .then((val) => {
        expect(val).to.eq('1')
        cy.get('[data-test=dump-component-settings-num-packets]')
          .clear()
          .type('101{enter}') // bigger than HISTORY_MAX_SIZE
        return cy
          .get('[data-test=dump-component-settings-num-packets]')
          .invoke('val')
      })
      .then((val) => {
        expect(val).to.eq('100')
      })
  })

  it('downloads a file', () => {
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.wait(100) // wait for the first packet to come in

    cy.get('[data-test=dump-component-play-pause]').click()
    cy.get('[data-test=dump-component-download]').click()
    let fileContents
    cy.readFile(
      `cypress/downloads/${format(new Date(), 'yyyy_MM_dd_HH_mm')}.txt`
    )
      .then((contents) => {
        fileContents = contents
        return cy.get('[data-test=dump-component-text-area]').invoke('val')
      })
      .then((val) => {
        expect(val).to.eq(fileContents)
      })
  })

  it('validates start and end time inputs', () => {
    // validate start date
    cy.get('[data-test=startDate]').clear()
    cy.get('.container').should('contain', 'Required')
    cy.get('[data-test=startDate]').clear().type('2020-01-01')
    cy.get('.container').should('not.contain', 'Invalid')
    // validate start time
    cy.get('[data-test=startTime]').clear()
    cy.get('.container').should('contain', 'Required')
    cy.get('[data-test=startTime]').clear().type('12:15:15')
    cy.get('.container').should('not.contain', 'Invalid')

    // validate end date
    cy.get('[data-test=endDate]').clear().type('2020-01-01')
    cy.get('.container').should('not.contain', 'Invalid')
    // validate end time
    cy.get('[data-test=endTime]').clear().type('12:15:15')
    cy.get('.container').should('not.contain', 'Invalid')
  })

  it('validates start and end time values', () => {
    // validate future start date
    cy.get('[data-test=startDate]').clear().type('4000-01-01') // If this version of COSMOS is still used 2000 years from now, this test will need to be updated
    cy.get('[data-test=startTime]').clear().type('12:15:15')
    cy.get('[data-test=start-button]').click()
    cy.get('.warning').should('contain', 'Start date/time is in the future!')

    // validate start/end time equal to each other
    cy.get('[data-test=startDate]').clear().type('2020-01-01')
    cy.get('[data-test=startTime]').clear().type('12:15:15')
    cy.get('[data-test=endDate]').clear().type('2020-01-01')
    cy.get('[data-test=endTime]').clear().type('12:15:15')
    cy.get('[data-test=start-button]').click()
    cy.get('.warning').should(
      'contain',
      'Start date/time is equal to end date/time!'
    )

    // validate future end date
    cy.get('[data-test=startDate]').clear().type('2020-01-01')
    cy.get('[data-test=startTime]').clear().type('12:15:15')
    cy.get('[data-test=endDate]').clear().type('4000-01-01')
    cy.get('[data-test=endTime]').clear().type('12:15:15')
    cy.get('[data-test=start-button]').click()
    cy.get('.warning').should(
      'contain',
      'Note: End date/time is greater than current date/time. Data will continue to stream in real-time until 4000-01-01 12:15:15 is reached.'
    )
  })

  it('saves and loads the configuration', () => {
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=add-packet-button]').click()
    let config = 'spec' + Math.floor(Math.random() * 10000)
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save Configuration').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.get('input').clear().type(config)
      cy.contains('Ok').click()
    })
    cy.get('.v-dialog:visible').should('not.exist')
    // Verify we get a warning if trying to save over existing
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Save Configuration').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.get('input').clear().type(config)
      cy.contains('Ok').click()
      cy.contains("'" + config + "' already exists")
      cy.contains('Cancel').click()
    })
    cy.get('.v-dialog:visible').should('not.exist')
    // Totally refresh the page
    cy.visit('/tools/dataviewer')
    cy.hideNav()
    cy.wait(1000)
    // the last config should open automatically
    cy.get('.v-window-item > .v-card > .v-card__title').should(
      'contain',
      'INST ADCS'
    )

    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open Configuration').click()
    cy.get('.v-dialog:visible').within(() => {
      // Try to click OK without anything selected
      cy.contains('Ok').click()
      cy.contains('Select a configuration')
      cy.contains(config).click()
      cy.contains('Ok').click()
    })
    // Verify we're back
    cy.get('.v-window-item > .v-card > .v-card__title').should(
      'contain',
      'INST ADCS'
    )
    // Delete this test configuation
    cy.get('.v-toolbar').contains('File').click()
    cy.contains('Open Configuration').click()
    cy.get('.v-dialog:visible').within(() => {
      cy.contains(config)
        .parents('.v-list-item')
        .eq(0)
        .within(() => {
          cy.get('button').click()
        })
      cy.contains('Cancel').click()
    })
  })
})
