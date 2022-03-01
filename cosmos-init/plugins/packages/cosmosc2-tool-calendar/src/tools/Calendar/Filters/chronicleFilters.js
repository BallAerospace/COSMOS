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

const makeCalendar = function (calendar, chronicles) {
  return {
    name: calendar.name,
    type: calendar.type,
    messages: calendar.messages,
    chronicles: chronicles[calendar.name] || [],
  }
}

const makeNarrationEvent = function (_calendar, event) {
  const name =
    event.description.length > 16
      ? `${event.description.substring(0, 16)}...`
      : event.description
  return {
    name: name,
    start: new Date(event.start * 1000),
    end: new Date(event.stop * 1000),
    color: event.color,
    type: event.type,
    timed: true,
    narrative: event,
  }
}

const makeMetadataEvent = function (calendar, event) {
  return {
    name: `${event.target} ${calendar.name}`,
    start: new Date(event.start),
    end: new Date(event.start),
    color: event.color,
    type: event.type,
    timed: true,
    metadata: event,
  }
}

const getChronicleEvents = function (selectedCalendars, chronicles) {
  return selectedCalendars
    .filter((calendar) => calendar.type === 'chronicle')
    .flatMap((calendarInfo) => {
      const calendar = makeCalendar(calendarInfo, chronicles)
      return calendar.chronicles.map((event) => {
        if (calendar.name === 'metadata') {
          return makeMetadataEvent(calendar, event)
        } else {
          return makeNarrationEvent(calendar, event)
        }
      })
    })
}

export { getChronicleEvents }
