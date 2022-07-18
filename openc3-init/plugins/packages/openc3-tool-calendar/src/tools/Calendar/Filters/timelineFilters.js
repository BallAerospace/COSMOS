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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
*/
const makeTimeline = function (timeline, activities) {
  return {
    name: timeline.name,
    color: timeline.color,
    messages: timeline.messages,
    activities: activities[timeline.name] || [],
  }
}

const makeActivity = function (timeline, activity) {
  return {
    name: `${activity.name} ${activity.kind}`,
    start: new Date(activity.start * 1000),
    end: new Date(activity.stop * 1000),
    color: timeline.color,
    type: 'activity',
    timed: true,
    activity,
  }
}

const getTimelineEvents = function (selectedCalendars, activities) {
  return selectedCalendars
    .filter((calendar) => calendar.type === 'timeline')
    .flatMap((calendarInfo) => {
      const timeline = makeTimeline(calendarInfo, activities)
      return timeline.activities.map((activity) => {
        return makeActivity(timeline, activity)
      })
    })
}

export { getTimelineEvents }
