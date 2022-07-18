<!--
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
-->

<template>
  <div>
    <span
      v-bind="attrs"
      v-on="on"
      style="cursor: context-menu"
      class="font-weight-bold"
      @contextmenu="openMenu"
    >
      {{ (displayLocal ? localDate : utcDate) | date(formatString) }}
      ({{ displayLocal ? 'local' : 'UTC' }})
    </span>
    <v-menu
      v-model="showMenu"
      :position-x="menuX"
      :position-y="menuY"
      absolute
      offset-y
    >
      <v-list>
        <v-list-item>
          <v-list-item-title
            style="cursor: pointer"
            @click="toggleDisplayLocal"
          >
            Display {{ displayLocal ? 'UTC' : 'local time' }}
          </v-list-item-title>
        </v-list-item>
        <v-divider />
        <v-list-item>
          <v-list-item-title style="cursor: pointer" @click="toggleDisplay24h">
            Display {{ display24h ? 12 : 24 }} hour clock
          </v-list-item-title>
        </v-list-item>
        <v-divider />
        <v-list-item v-if="dateMode !== 'monthFirst'">
          <v-list-item-title style="cursor: pointer" @click="setMonthFirst">
            Display mm/dd/yyyy
          </v-list-item-title>
        </v-list-item>
        <v-list-item v-if="dateMode !== 'dayFirst'">
          <v-list-item-title style="cursor: pointer" @click="setDayFirst">
            Display dd/mm/yyyy
          </v-list-item-title>
        </v-list-item>
        <v-list-item v-if="dateMode !== 'number'">
          <v-list-item-title style="cursor: pointer" @click="setNumber">
            Display day of year
          </v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>
  </div>
</template>

<script>
import { format } from 'date-fns'

export default {
  data: function () {
    return {
      localDate: new Date(),
      displayLocal: localStorage.clock_zone === 'local',
      display24h: !localStorage.clock_12h,
      dateMode: localStorage.clock_dateMode || 'monthFirst',
      intervalCount: 0,
      showMenu: false,
      menuX: 0,
      menuY: 0,
    }
  },
  computed: {
    utcDate: function () {
      return new Date(
        this.localDate.getTime() + this.localDate.getTimezoneOffset() * 60000
      )
    },
    formatString: function () {
      let dateFormat
      switch (this.dateMode) {
        case 'monthFirst':
          dateFormat = 'LL/dd/yyy'
          break
        case 'dayFirst':
          dateFormat = 'dd/LL/yyy'
          break
        case 'number':
          dateFormat = 'D'
          break
      }

      let timeFormat
      if (this.display24h) {
        timeFormat = 'HH:mm:ss'
      } else {
        timeFormat = 'hh:mm:ss a'
      }

      return `${dateFormat} ${timeFormat}`
    },
  },
  watch: {
    displayLocal: function (val) {
      localStorage.clock_zone = val ? 'local' : 'utc'
    },
    display24h: function (val) {
      // store opposite because it makes default value (true) easier
      if (val) {
        delete localStorage.clock_12h
      } else {
        localStorage.clock_12h = true
      }
    },
    dateMode: function (val) {
      if (val.match(/^monthFirst$|^dayFirst$|^number$/)) {
        localStorage.clock_dateMode = val
      }
    },
  },
  created: function () {
    setInterval(
      () => {
        this.intervalCount++
        this.localDate = new Date()
      },
      this.intervalCount < 10 ? 100 : 1000 // get the seconds to about 100ms accuracy
    )
  },
  methods: {
    openMenu: function (event) {
      event.preventDefault()
      this.showMenu = false
      this.menuX = event.clientX
      this.menuY = event.clientY
      this.$nextTick(() => {
        this.showMenu = true
      })
    },
    toggleDisplayLocal: function () {
      this.displayLocal = !this.displayLocal
    },
    toggleDisplay24h: function () {
      this.display24h = !this.display24h
    },
    setMonthFirst: function () {
      this.dateMode = 'monthFirst'
    },
    setDayFirst: function () {
      this.dateMode = 'dayFirst'
    },
    setNumber: function () {
      this.dateMode = 'number'
    },
  },
  filters: {
    date: function (val, formatString) {
      return format(val, formatString, { useAdditionalDayOfYearTokens: true })
    },
  },
}
</script>
