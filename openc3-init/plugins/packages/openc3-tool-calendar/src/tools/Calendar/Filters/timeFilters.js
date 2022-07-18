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

export default {
  filters: {
    time: function (val, utc) {
      if (utc) {
        return val.toUTCString().split(' ')[4]
      } else {
        return val.toLocaleString().split(' ')[1] // TODO: support other locales besides en-US
      }
    },
    dateTime: function (val, utc) {
      if (utc) {
        return val.toISOString()
      } else {
        return val.toLocaleString() // TODO: support other locales besides en-US
      }
    },
  },
  methods: {
    generateDateTime(date, utc) {
      if (utc) {
        return date.toISOString()
      } else {
        return date.toLocaleString() // TODO: support other locales besides en-US
      }
    },
    toIsoString(nSeconds) {
      // convert the date object to
      const date = new Date(nSeconds)
      const tzo = -date.getTimezoneOffset()
      const dif = tzo >= 0 ? '+' : '-'
      function pad(num) {
        var norm = Math.floor(Math.abs(num))
        return (norm < 10 ? '0' : '') + norm
      }
      const year = date.getFullYear()
      const month = pad(date.getMonth() + 1)
      const day = pad(date.getDate())
      const hour = pad(date.getHours())
      const minute = pad(date.getMinutes())
      const second = pad(date.getSeconds())
      const mil = pad(date.getMilliseconds())
      const timeZone =
        this.utcOrLocal === 'utc'
          ? '00:00'
          : `${pad(tzo / 60)}:${pad(tzo % 60)}`
      return `${year}-${month}-${day}T${hour}:${minute}:${second}.${mil}${dif}${timeZone}`
    },
  },
}
