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
  <v-textarea disabled filled :value="hexText"></v-textarea>
</template>

<script>
export default {
  props: {
    packet: {
      type: Object,
    },
  },
  data: function () {
    return {
      history: [],
    }
  },
  watch: {
    packet: function (val) {
      this.history.push(val)
    },
  },
  computed: {
    hexBytes: function () {
      if (!this.packet) return ['No data']
      return this.packet.raw.map((byte) => byte.toString(16).padStart(2, '0'))
    },
    hexText: function () {
      return this.hexBytes.join(' ')
    },
  },
}
</script>

<style lang="scss" scoped>
.v-textarea {
  font-family: 'Courier New', Courier, monospace;
}
</style>
