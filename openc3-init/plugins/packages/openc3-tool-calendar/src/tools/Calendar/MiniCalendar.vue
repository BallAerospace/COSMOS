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
    <v-row dense class="px-2 pb-2">
      <v-toolbar-title>{{ title }}</v-toolbar-title>
      <v-spacer />
      <v-btn small icon data-test="mini-prev" @click="prev">
        <v-icon small> mdi-chevron-left </v-icon>
      </v-btn>
      <v-btn small icon data-test="mini-next" @click="next">
        <v-icon small> mdi-chevron-right </v-icon>
      </v-btn>
    </v-row>
    <v-calendar
      ref="sideCalendar"
      v-model="focus"
      :show-month-on-first="false"
      @click:date="viewDay"
    />
  </div>
</template>

<script>
export default {
  components: {},
  props: {
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      focus: '',
      title: '',
    }
  },
  mounted() {
    this.$refs.sideCalendar.checkChange()
    this.title = this.$refs.sideCalendar.title
  },
  computed: {
    calendarConfiguration: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
    monthNames: function () {
      return [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ]
    },
  },
  watch: {
    focus: function () {
      const d = new Date(this.focus)
      const month = this.monthNames[d.getUTCMonth()]
      const year = d.getUTCFullYear()
      this.title = `${month} ${year}`
    },
  },
  methods: {
    viewDay: function ({ date }) {
      this.calendarConfiguration = {
        ...this.calendarConfiguration,
        focus: date,
      }
    },
    prev: function () {
      this.$refs.sideCalendar.prev()
    },
    next: function () {
      this.$refs.sideCalendar.next()
    },
  },
}
</script>
