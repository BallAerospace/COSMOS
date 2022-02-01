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

import { format, add } from 'date-fns'

function formatTime(date) {
  return format(date, 'HH:mm:ss')
}
function formatDate(date) {
  return format(date, 'yyyy-MM-dd')
}

describe('Timeline', () => {
  beforeEach(() => {
    cy.visit('/tools/timeline')
    cy.hideNav()
    cy.wait(1000)
  })

  afterEach(() => {
    //
  })

  it('create new timeline', function () {
    cy.get('[data-test=createTimeline]').click({ force: true })
    cy.get('[data-test=inputTimelineName]').type('Alpha')
    cy.get('[data-test=create-cancel-btn]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test=createTimeline]').click({ force: true })
    cy.get('[data-test=inputTimelineName]').type('Alpha')
    cy.get('[data-test=create-submit-btn]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test=Timeline-Options]').click({ force: true })
    cy.get('[data-test=Timeline-Options-Refresh]').click({ force: true })
    cy.contains('Alpha')
    cy.wait(500)
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('div.v-sheet > .v-sheet > .v-toolbar__content').contains('Alpha')
    cy.wait(500)
  })

  it('check menus', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('[data-test=Timeline-Options]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test=Timeline-Options-Calendar]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test=Timeline-Options]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test=Timeline-Options-List]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test=Timeline-Options]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test="Timeline-Options-UTC (UTC)"]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test=Timeline-Options]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test="Timeline-Options-Local (LST)"]').click({ force: true })
    cy.wait(1000)
  })

  it('check calendar', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('[data-test=Timeline-Options]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test=Timeline-Options-Calendar]').click({ force: true })
    cy.get('.col-9').contains('Alpha')
    cy.get('.vue-portal-target > .v-toolbar__content > :nth-child(1)').click({
      force: true,
    })
    cy.get('[data-test=changeType]').contains('4 Days').click({ force: true })
    cy.get('[data-test=typeDay]').click({ force: true })
    cy.get('[data-test=changeType]').contains('Day').click({ force: true })
    cy.get('[data-test=type4day]').click({ force: true })
    cy.get('[data-test=searchDate]').click({ force: true })
    const dateTime = add(new Date(), { days: 14 })
    cy.get('.v-text-field__slot > [data-test=searchDate]').type(
      formatDate(dateTime),
      { force: true }
    )
    cy.get('.ml-2').click({ force: true })
    cy.wait(500)
    cy.get('[data-test=next]').click({ force: true })
    cy.get('[data-test=prev]').click({ force: true })
    cy.get('[data-test=today]').click({ force: true })
    cy.wait(1000)
  })

  it('color timeline', function () {
    cy.get('[data-test=openTimelineColorDialog-Alpha]').click({ force: true })
    cy.wait(500)
    cy.get('.v-system-bar').contains('Timeline: Alpha')
    cy.get('.pa-4').contains('#')
    cy.get(
      '.v-color-picker__swatches > :nth-child(1) > :nth-child(1) > :nth-child(1) > div'
    ).click({ force: true })
    cy.get('[data-test=color-cancel-btn]').click({ force: true })
    cy.wait(500)
    // One more time
    cy.get('[data-test=openTimelineColorDialog-Alpha]').click({ force: true })
    cy.get(
      '.v-color-picker__swatches > :nth-child(1) > :nth-child(1) > :nth-child(1) > div'
    ).click({ force: true })
    cy.get('[data-test=color-submit-btn]').click({ force: true })
    cy.wait(500)
  })

  it('click add activity to timeline and cancel', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('[data-test=createActivity]').click({ force: true })
    const startDateTime = add(new Date(), { minutes: 10 })
    const stopDateTime = add(new Date(), { minutes: 20 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get(
      ':nth-child(2) > .v-input--selection-controls__input > .v-input--selection-controls__ripple'
    ).click({ force: true })
    cy.get(
      '.v-input--radio-group__input > :nth-child(1) > .v-input--selection-controls__input > .v-input--selection-controls__ripple'
    ).click({ force: true })
    cy.get('[data-test=create-activity-step-two-btn]').click({ force: true })
    cy.get('[data-test=activityKind]')
      .contains('COMMAND')
      .click({ force: true })
    cy.get('[data-test=reserve]').click({ force: true })
    cy.get('[data-test=activityKind]')
      .contains('RESERVE')
      .click({ force: true })
    cy.get('[data-test=script]').click({ force: true })
    cy.get('[data-test=activityKind]').contains('SCRIPT')
    cy.get('[data-test=create-cancel-btn]').click({ force: true }) // cancel
    cy.wait(1000)
    cy.get('.v-data-footer__pagination').contains('–')
  })

  it('click add activity to timeline and success', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('[data-test=createActivity]').click({ force: true })
    const startDateTime = add(new Date(), { minutes: 10 })
    const stopDateTime = add(new Date(), { minutes: 20 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get('[data-test=create-activity-step-two-btn]').click({ force: true })
    cy.get('[data-test=activityKind]').contains('COMMAND')
    cy.get('[data-test=cmd]').type('Update this later')
    cy.get('[data-test=create-submit-btn]').click({ force: true })
    cy.wait(3000)
    cy.contains('cmd')
    cy.get('.v-data-footer__pagination').contains('1')
  })

  it('view activity from timeline', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('[data-test=activityActions]').click({ force: true })
    cy.get('[data-test=viewActivity]').click({ force: true })
    cy.get('.v-system-bar').contains('Timeline: Alpha')
    cy.get('#footer > img').click({ force: true })
    cy.get(':nth-child(8) > .v-icon').click({ force: true })
    cy.get('.v-data-table__expanded__content > td').contains('created')
    cy.get(':nth-child(8) > .v-icon').click({ force: true })
    cy.wait(1000)
  })

  it('cancel update activity from timeline', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('[data-test=activityActions]').click({ force: true })
    cy.get('[data-test=updateActivity]').click({ force: true })
    cy.get('.v-system-bar').contains('Update activity: Alpha/')
    cy.get('[data-test=update-cancel-btn]').click({ force: true })
    cy.wait(500)
    cy.get('[data-test=updateActivity]').click({ force: true })
    cy.get('.v-system-bar').contains('Update activity: Alpha/')
    const startDateTime = add(new Date(), { minutes: 20 })
    const stopDateTime = add(new Date(), { minutes: 30 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get('[data-test=update-activity-step-two-btn]').click({ force: true })
    cy.get('[data-test=activityKind]').contains('COMMAND')
    cy.get('[data-test=cmd]').clear()
    cy.get('[data-test=cmd]').type('Update again in calendar view')
    cy.get('[data-test=update-submit-btn]').click({ force: true })
    cy.wait(1000)
  })

  it('view activity on calendar view', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('[data-test=Timeline-Options]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test=Timeline-Options-Calendar]').click({ force: true })
    cy.wait(500)
    cy.get('.v-event-timed').click({ force: true })
    cy.get('.menuable__content__active > .v-card > .v-card__text').contains(
      'Update'
    )
    cy.get('[data-test=viewActivityIcon]').click({ force: true })
    cy.get('.v-system-bar').contains('Timeline: Alpha')
    cy.get('#footer > img').click({ force: true })
    cy.wait(1000)
  })

  it('update activity on calendar view', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get('[data-test=Timeline-Options]').click({ force: true })
    cy.wait(100)
    cy.get('[data-test=Timeline-Options-Calendar]').click({ force: true })
    cy.wait(500)
    cy.get('.v-event-timed').click({ force: true })
    cy.get('.menuable__content__active > .v-card > .v-card__text').contains(
      'Update'
    )
    cy.get('[data-test=updateActivityIcon]').click({ force: true })
    cy.get('.v-system-bar').contains('Update activity: Alpha/')
    const startDateTime = add(new Date(), { minutes: 20 })
    const stopDateTime = add(new Date(), { minutes: 30 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get('[data-test=update-activity-step-two-btn]').click({ force: true })
    cy.get('[data-test=cmd]').clear()
    cy.get('[data-test=cmd]').type(
      'INST COLLECT with TYPE 0, DURATION 1, OPCODE 171, TEMP 0'
    )
    cy.get('[data-test=update-submit-btn]').click({ force: true })
    cy.wait(500)
  })

  it('remove activity from timeline', function () {
    cy.get('[data-test=selectItem-Alpha]').click({ force: true })
    cy.get(
      ':nth-child(1) > :nth-child(7) > .row > .mt-1 > .v-btn__content > .v-icon'
    ).click({ force: true })
    cy.get('[data-test=deleteActivity]').click({ force: true })
    cy.get('.dg-content').contains('from timeline: Alpha')
    cy.get('.dg-btn--cancel').click({ force: true })
    cy.wait(500)
    cy.get(
      ':nth-child(1) > :nth-child(7) > .row > .mt-1 > .v-btn__content > .v-icon'
    ).click({ force: true })
    cy.get('[data-test=deleteActivity]').click({ force: true })
    cy.get('.dg-btn--ok').click({ force: true })
    cy.wait(500)
  })

  it('delete timeline', function () {
    cy.get(' [data-test=deleteTimeline-Alpha]').click({ force: true })
    cy.get('.dg-content').contains('remove: Alpha')
    cy.get('.dg-btn--cancel').click({ force: true })
    cy.wait(500)
    cy.get('[data-test=deleteTimeline-Alpha]').click({ force: true })
    cy.get('.dg-content').contains('remove: Alpha')
    cy.get('.dg-btn--ok').click({ force: true })
    cy.wait(500)
  })

  it('create two new timelines', function () {
    cy.get('[data-test=createTimeline]').click({ force: true })
    cy.get('[data-test=inputTimelineName]').type('Beta')
    cy.get('[data-test=create-submit-btn]').click({ force: true })
    cy.contains('Beta')
    cy.get('[data-test=createTimeline]').click({ force: true })
    cy.get('[data-test=inputTimelineName]').type('Gamma')
    cy.get('[data-test=create-submit-btn]').click({ force: true })
    cy.contains('Gamma')
  })

  it('click add first activity to Beta timeline and success', function () {
    cy.get('[data-test=selectItem-Beta]').first().click({ force: true })
    cy.get('.v-data-footer__pagination').contains('–')
    cy.get('[data-test=createActivity]').click({ force: true })
    const startDateTime = add(new Date(), { minutes: 10 })
    const stopDateTime = add(new Date(), { minutes: 20 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get('[data-test=create-activity-step-two-btn]').click({ force: true })
    cy.get('[data-test=activityKind]').contains('COMMAND')
    cy.get('[data-test=cmd]').type('Test')
    cy.get('[data-test=create-submit-btn]').click({ force: true })
    cy.wait(2000)
    cy.get('.v-data-footer__pagination').contains('of 1')
  })

  it('click add second activity to Beta timeline and success', function () {
    cy.get('[data-test=selectItem-Beta]').first().click({ force: true })
    cy.get('.v-data-footer__pagination').contains('1')
    cy.get('[data-test=createActivity]').click({ force: true })
    const startDateTime = add(new Date(), { minutes: 30 })
    const stopDateTime = add(new Date(), { minutes: 40 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get('[data-test=create-activity-step-two-btn]').click({ force: true })
    cy.get('[data-test=activityKind]').contains('COMMAND')
    cy.get('[data-test=cmd]').type('Test')
    cy.get('[data-test=create-submit-btn]').click({ force: true })
    cy.wait(2000)
    cy.get('.v-data-footer__pagination').contains('of 2')
  })

  it('click add activity to Gamma timeline and success', function () {
    cy.get('[data-test=selectItem-Gamma]').last().click({ force: true })
    cy.get('.v-data-footer__pagination').contains('–')
    cy.get('[data-test=createActivity]').click({ force: true })
    const startDateTime = add(new Date(), { minutes: 10 })
    const stopDateTime = add(new Date(), { minutes: 20 })
    cy.get('[data-test=startDate]').type(formatDate(startDateTime))
    cy.get('[data-test=startTime]').type(formatTime(startDateTime))
    cy.get('[data-test=stopDate]').type(formatDate(stopDateTime))
    cy.get('[data-test=stopTime]').type(formatTime(stopDateTime))
    cy.get('[data-test=create-activity-step-two-btn]').click({ force: true })
    cy.get('[data-test=activityKind]').contains('COMMAND')
    cy.get('[data-test=cmd]').type('Test')
    cy.get('[data-test=create-submit-btn]').click({ force: true })
    cy.wait(2000)
    cy.contains('cmd')
    cy.get('.v-data-footer__pagination').contains('of 1')
  })

  it('view multiple from Beta and Gamma timeline', function () {
    cy.get('[data-test=setSelectedActivities]').click({ force: true })
    cy.get('[data-test=selectItem-Beta]').last().click({ force: true })
    cy.get('[data-test=selectItem-Gamma]').last().click({ force: true })
    cy.get(
      'div.v-sheet > .v-sheet > .v-toolbar__content > .v-toolbar__title'
    ).contains('Beta, Gamma')
    cy.get('.v-data-footer__pagination').contains('of 3')
  })

  it('remove multiple from Beta and Gamma timeline', function () {
    cy.get('[data-test=setSelectedActivities]').click({ force: true })
    cy.get('[data-test=selectItem-Beta]').last().click({ force: true })
    cy.get('[data-test=selectItem-Gamma]').last().click({ force: true })
    cy.get(
      'div.v-sheet > .v-sheet > .v-toolbar__content > .v-toolbar__title'
    ).contains('Beta, Gamma')
    cy.get('.v-data-footer__pagination').contains('of 3')
    cy.get(
      '.v-data-table-header > tr > :nth-child(1) > .v-data-table__checkbox > .v-input--selection-controls__input > .v-input--selection-controls__ripple'
    ).click({ force: true })
    cy.get('.v-data-footer__pagination').contains('of 3')
    cy.get('.ma-2 > .v-btn__content > .v-icon').click({ force: true })
    cy.get('.dg-btn--cancel').click({ force: true })
    cy.get('.ma-2 > .v-btn__content > .v-icon').click({ force: true })
    cy.wait(1000)
    cy.get('#dg-input-elem').type('delete')
    cy.get('.dg-btn--ok').click({ force: true })
    cy.wait(1000)
    cy.get('.v-data-footer__pagination').contains('–')
  })

  it('removes timeline', function () {
    cy.get('[data-test=setSelectedActivities]').click({ force: true })
    cy.get('[data-test=setSelectedActivities]').click({ force: true })
    cy.get('[data-test=setSelectedActivities]').click({ force: true })
    cy.get('[data-test=selectItem-Beta]').last().click({ force: true })
    cy.get('[data-test=selectItem-Gamma]').last().click({ force: true })
    cy.get('[data-test=deleteSelectedTimelines]').click({ force: true })
    cy.wait(1000)
    cy.get('#dg-input-elem').type('delete')
    cy.get('.dg-btn--ok').click({ force: true })
    cy.wait(1000)
  })
})
