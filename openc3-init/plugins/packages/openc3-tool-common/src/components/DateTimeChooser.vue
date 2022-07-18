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
    <v-row>
      <v-col>
        <v-menu
          close-on-content-click
          transition="scale-transition"
          offset-y
          max-width="290px"
          min-width="290px"
        >
          <template v-slot:activator="{ on }">
            <!-- We set the :name attribute to be unique to avoid auto-completion -->
            <v-text-field
              :label="dateLabel"
              :name="`date${Date.now()}`"
              :rules="dateRules"
              v-model="date"
              v-on="on"
              type="date"
              data-test="date-chooser"
            />
          </template>
        </v-menu>
      </v-col>
      <v-col>
        <!-- We set the :name attribute to be unique to avoid auto-completion -->
        <v-text-field
          :label="timeLabel"
          :name="`time${Date.now()}`"
          :rules="timeRules"
          v-model="time"
          type="time"
          step="1"
          @change="onChange"
          data-test="time-chooser"
        />
      </v-col>
    </v-row>
  </div>
</template>

<script>
import { isValid, parse, format, getTime } from 'date-fns'

export default {
  props: {
    required: {
      type: Boolean,
      default: true,
    },
    initialDate: {
      type: Date,
      default: null,
    },
    initialTime: {
      type: Date,
      default: null,
    },
    dateLabel: {
      type: String,
      default: 'Date',
    },
    timeLabel: {
      type: String,
      default: 'Time',
    },
  },
  data() {
    return {
      date: null,
      time: null,
      rules: {
        required: (value) => !!value || 'Required',
        date: (value) => {
          if (!value) return true
          try {
            return (
              isValid(parse(value, 'yyyy-MM-dd', new Date())) ||
              'Invalid date (YYYY-MM-DD)'
            )
          } catch (e) {
            return 'Invalid date (YYYY-MM-DD)'
          }
        },
        time: (value) => {
          if (!value) return true
          try {
            return (
              isValid(parse(value, 'HH:mm:ss', new Date())) ||
              'Invalid time (HH:MM:SS)'
            )
          } catch (e) {
            return 'Invalid time (HH:MM:SS)'
          }
        },
      },
    }
  },
  computed: {
    dateRules() {
      let result = [this.rules.date]
      if (this.time || this.required) {
        result.push(this.rules.required)
      }
      return result
    },
    timeRules() {
      let result = [this.rules.time]
      if (this.date || this.required) {
        result.push(this.rules.required)
      }
      return result
    },
  },
  methods: {
    onChange() {
      if (!!this.date && !!this.time) {
        this.$emit('date-time', this.date + ' ' + this.time)
      } else {
        this.$emit('date-time', null)
      }
    },
  },
}
</script>
