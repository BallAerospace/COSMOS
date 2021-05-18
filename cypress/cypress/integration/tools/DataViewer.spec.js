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
  it('adds a raw packet to a new tab', () => {
    cy.visit('/tools/dataviewer')
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
    cy.visit('/tools/dataviewer')
    cy.hideNav()
    cy.get('[data-test=new-tab]').click()
    cy.get('[data-test=new-packet]').should('be.visible').click()
    cy.selectTargetPacketItem('INST', 'ADCS')
    cy.get('[data-test=new-packet-decom-radio]').check({ force: true })
    cy.get('[data-test=add-packet-value-type]').should('be.visible')
    cy.get('[data-test=add-packet-button]').click()
    cy.get('[data-test=start-button]').click()
    cy.wait(100) // wait for the first packet to come in
    cy.get('[data-test=dump-component-text-area]').should('not.have.value', '')
  })

  it('controls playback', () => {
    cy.visit('/tools/dataviewer')
    cy.hideNav()
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
      })
  })

  it('changes display settings', () => {
    cy.visit('/tools/dataviewer')
    cy.hideNav()
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
    cy.visit('/tools/dataviewer')
    cy.hideNav()
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
})
