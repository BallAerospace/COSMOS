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
    <v-tooltip top v-if="validOffset">
      <template v-slot:activator="{ on, attrs }">
        <span v-bind="attrs" v-on="on" v-text="localTime" class="clock-text" />
      </template>
      <span> Local Time </span>
    </v-tooltip>
    <v-tooltip top>
      <template v-slot:activator="{ on, attrs }">
        <span v-bind="attrs" v-on="on" v-text="utcTime" class="clock-text" />
      </template>
      <span> UTC Time </span>
    </v-tooltip>
  </div>
</template>

<script>
export default {
  data: function () {
    return {
      date: new Date(),
      intervalCount: 0,
    }
  },
  created: function () {
    setInterval(
      () => {
        this.intervalCount++
        this.date = new Date()
      },
      this.intervalCount < 10 ? 100 : 1000 // get the seconds to about 100ms accuracy
    )
  },
  computed: {
    validOffset: function () {
      return this.date.getTimezoneOffset() !== 0
    },
    localTime: function () {
      const year = this.date.getFullYear()
      const month = this.pad(this.date.getMonth() + 1)
      const day = this.pad(this.date.getDate())
      const hour = this.pad(this.date.getHours())
      const minute = this.pad(this.date.getMinutes())
      const second = this.pad(this.date.getSeconds())
      return `${year}-${month}-${day}T${hour}:${minute}:${second}`
    },
    utcTime: function () {
      const year = this.date.getUTCFullYear()
      const month = this.pad(this.date.getUTCMonth() + 1)
      const day = this.pad(this.date.getUTCDate())
      const hour = this.pad(this.date.getUTCHours())
      const minute = this.pad(this.date.getUTCMinutes())
      const second = this.pad(this.date.getUTCSeconds())
      return `${year}-${month}-${day}T${hour}:${minute}:${second}Z`
    },
  },
  methods: {
    pad: function (num) {
      var norm = Math.floor(Math.abs(num))
      return (norm < 10 ? '0' : '') + norm
    },
  },
}
</script>

<style scoped>
.clock-text {
  margin-left: 1em;
}
</style>
