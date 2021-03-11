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
  <graph
    :ref="'graph' + id"
    :id="id"
    :state="'start'"
    :selectedGraphId="id"
    :secondsGraphed="1000"
    :pointsSaved="1000000"
    :pointsGraphed="1000"
    :initialItems="items"
    :height="300"
    :width="400"
    hide-system-bar
    hide-overview
  />
</template>

<script>
import Widget from './Widget'
import Graph from '../Graph.vue'
export default {
  components: {
    Graph,
  },
  mixins: [Widget],
  data: function () {
    return {
      id: Math.floor(Math.random() * 100000000000), // Unique-ish
      items: [
        {
          targetName: this.parameters[0],
          packetName: this.parameters[1],
          itemName: this.parameters[2],
          valueType: 'CONVERTED',
        },
      ],
    }
  },
}
</script>
