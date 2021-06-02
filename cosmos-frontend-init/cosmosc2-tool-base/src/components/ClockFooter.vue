<!--
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
-->

<template>
  <div>
    <v-tooltip top v-if="localTime !== utcTime">
      <template>
        <div v-show="localTime" v-text="localTime" />
      </template>
      <span> Local Time </span>
    </v-tooltip>
    <v-tooltip top>
      <template>
        <div v-show="utcTime" v-text="utcTime" />
      </template>
      <span> UTC Time </span>
    </v-tooltip>
  </div>
</template>

<script>
export default {
  computed: {
    localTime: function () {
      // convert the date object to
      const date = new Date()
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
      return `${year}-${month}-${day}T${hour}:${minute}:${second}`
    },
    utcTime: function () {
      // convert the date object to
      const date = new Date()
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
      return `${year}-${month}-${day}T${hour}:${minute}:${second}Z`
    },
  },
}
</script>
