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
    <v-textarea
      :rows="rowCount"
      id="text"
      hide-details
      readonly
      class="pa-2"
      :value="value"
    >
    </v-textarea>
  </div>
</template>

<script>
import { format } from 'date-fns'
import debounce from 'lodash/debounce'
import floor from 'lodash/floor'
import Component from './Component'
export default {
  mixins: [Component],
  data() {
    return {
      rowCount: 5,
    }
  },
  created() {
    // TODO: Get actual data to put in here
    setInterval(() => {
      this.value +=
        '\n' +
        format(new Date(), 'yyyy-MM-dd HH:mm:ss') +
        ': More text to append'
      this.$nextTick(function () {
        let textarea = document.getElementById('text')
        textarea.scrollTop = textarea.scrollHeight
      })
    }, 1000)
  },
  mounted() {
    // Allow the output to dynamically resize when the window resizes
    window.addEventListener('resize', debounce(this.calcRows, 200))
    this.calcRows()
  },
  beforeDestroy() {
    window.removeEventListener('resize')
  },
  methods: {
    calcRows() {
      let height = Math.max(
        document.documentElement.clientHeight,
        window.innerHeight || 0
      )
      // TODO Fudget factor for header & footer, better way to calc this?
      height -= 200
      this.rowCount = floor(height / 24)
      if (this.rowCount < 5) {
        this.rowCount = 5
      }
    },
  },
}
</script>

<style lang="scss" scoped>
.v-textarea {
  font-family: 'Courier New', Courier, monospace;
}
</style>
