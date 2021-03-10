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
  <graph :data="values" />
</template>

<script>
import VWidget from './VWidget'
import Graph from '@/components/Graph.vue'

export default {
  mixins: [VWidget],
  components: {
    Graph,
  },
  data: function () {
    return {
      values: [[]],
    }
  },
  watch: {
    _value: function (val) {
      this.values[0].push(parseFloat(val))
      if (this.values[0].length > 1000) {
        this.values[0].shift()
      }
    },
  },
  mounted: function () {

  },
  methods: {
    
  }
}
</script>
