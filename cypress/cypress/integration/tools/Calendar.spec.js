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

import { format, add, sub } from 'date-fns'

function formatTime(date) {
  return format(date, 'HH:mm:ss')
}
function formatDate(date) {
  return format(date, 'yyyy-MM-dd')
}

describe('Calendar', () => {
  beforeEach(() => {
    cy.visit('/tools/calendar')
    cy.hideNav()
    cy.wait(1000)
  })

  afterEach(() => {
    //
  })

  it('check settings', function () {
    cy.get('[data-test="settings"]').click({ force: true })
    cy.wait(50)
    cy.get('[data-test="refresh"]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test="settings"]').click({ force: true })
    cy.wait(50)
    cy.get('[data-test="display-utc-time"]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test="settings"]').click({ force: true })
    cy.wait(50)
    cy.get('[data-test="view-event-list"]').click({ force: true })
    cy.wait(50)
    cy.get('[data-test="settings"]').click({ force: true })
    cy.wait(50)
    cy.get('[data-test="show-table"]').click({ force: true })
    cy.wait(500)
  })

  it('check calendar config', function () {
    cy.get('[data-test=changeType]').contains('4 Days').click({ force: true })
    cy.get('[data-test=typeDay]').click({ force: true })
    cy.get('[data-test=changeType]').contains('Day').click({ force: true })
    cy.get('[data-test="typeFourDay"]').click({ force: true })
    cy.get('[data-test=next]').click({ force: true })
    cy.get('[data-test=prev]').click({ force: true })
    cy.get('[data-test=today]').click({ force: true })
    cy.get('[data-test="mini-next"]').click({ force: true })
    cy.get('[data-test="mini-prev"]').click({ force: true })
    cy.wait(500)
  })

  it('click add metadata and cancel', function () {
    cy.get('[data-test="createEvent"]').click({ force: true })
    cy.get('[data-test="metadata"]').click({ force: true })
    const startDateTime = sub(new Date(), { minutes: 30 })
    cy.get(
      '.pa-2 > :nth-child(3) > .v-input > .v-input__control > .v-input__slot'
    ).click({ force: true })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('.v-input--radio-group__input > :nth-child(2)').click({
      force: true,
    })
    cy.get('.v-input--radio-group__input > :nth-child(1)').click({
      force: true,
    })
    cy.get('.v-stepper__step--inactive').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="new-metadata-icon"]').click({ force: true })
    cy.get('[data-test="key-0"]').type('version')
    cy.get('[data-test="value-0"]').type('1')
    cy.get('[data-test="create-cancel-btn"]').click({ force: true }) // cancel
    cy.wait(1000)
  })

  it('click add narrative and cancel', function () {
    cy.get('[data-test="createEvent"]').click({ force: true })
    cy.get('[data-test="narrative"]').click({ force: true })
    const startDateTime = sub(new Date(), { minutes: 30 })
    const stopDateTime = add(new Date(), { minutes: 40 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get('.v-input--radio-group__input > :nth-child(2)').click({
      force: true,
    })
    cy.get('.v-input--radio-group__input > :nth-child(1)').click({
      force: true,
    })
    cy.get('.v-stepper__step--inactive').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="create-narrative-description"]').type(
      'Test the narrative create dialog'
    )
    cy.get('[data-test=create-cancel-btn]').click({ force: true }) // cancel
    cy.wait(1000)
  })

  it('create new timeline', function () {
    cy.get('[data-test="create-timeline"]').click({ force: true })
    cy.get('[data-test="input-timeline-name"]').type('Alpha')
    cy.get('[data-test="create-cancel-btn"]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="create-timeline"]').click({ force: true })
    cy.get('[data-test="input-timeline-name"]').type('Alpha')
    cy.get('[data-test="create-submit-btn"]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="create-timeline"]').click({ force: true })
    cy.get('[data-test="input-timeline-name"]').type('Alpha')
    cy.get('.pa-3').contains('Duplicate timeline name found, Alpha')
    cy.get('[data-test="create-cancel-btn"]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="settings"]').click({ force: true })
    cy.get('[data-test="refresh"]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="select-timeline-Alpha"]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="Alpha-options"]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="Alpha-color-#9f0010"]').click({ force: true })
    cy.wait(1000)
  })

  it('click add activity and cancel', function () {
    cy.get('[data-test="createEvent"]').click({ force: true })
    cy.get('[data-test="activity"]').click({ force: true })
    const startDateTime = add(new Date(), { minutes: 30 })
    const stopDateTime = add(new Date(), { minutes: 40 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get('.v-input--radio-group__input > :nth-child(2)').click({
      force: true,
    })
    cy.get('.v-input--radio-group__input > :nth-child(1)').click({
      force: true,
    })
    cy.get('.v-stepper__step--inactive').click({ force: true })
    cy.get('[data-test=create-cancel-btn]').click({ force: true }) // cancel
    cy.wait(1000)
  })

  it('delete timeline', function () {
    cy.get('[data-test="Alpha-options"] > .v-btn__content').click({
      force: true,
    })
    cy.get('[data-test="Alpha-delete"]').click({ force: true })
    cy.get('.dg-content').contains('remove: Alpha')
    cy.get('.dg-btn--cancel').click({ force: true })
    cy.wait(500)
    cy.get('[data-test="Alpha-options"] > .v-btn__content').click({
      force: true,
    })
    cy.get('[data-test="Alpha-delete"]').click({ force: true })
    cy.get('.dg-content').contains('remove: Alpha')
    cy.get('.dg-btn--ok').click({ force: true })
    cy.wait(500)
  })
})
