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
      solo
      dense
      readonly
      hide-details
      placeholder="Value"
      :height="height"
      :value="_value"
      :class="valueClass"
      :style="computedStyle"
      data-test="array-widget"
      @contextmenu="showContextMenu"
    />
    <v-menu
      v-model="contextMenuShown"
      :position-x="x"
      :position-y="y"
      absolute
      offset-y
    >
      <v-list>
        <v-list-item
          v-for="(item, index) in contextMenuOptions"
          :key="index"
          @click.stop="item.action"
        >
          <v-list-item-title>{{ item.title }}</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>

    <details-dialog
      :targetName="parameters[0]"
      :packetName="parameters[1]"
      :itemName="parameters[2]"
      v-model="viewDetails"
    />
  </div>
</template>

<script>
import VWidget from './VWidget'
import DetailsDialog from '../../components/DetailsDialog'
import 'sprintf-js'
export default {
  components: {
    DetailsDialog,
  },
  data() {
    return {
      height: 100,
      itemsPerRow: 4,
      formatter: null,
    }
  },
  mixins: [VWidget],
  created() {
    if (this.parameters[3]) {
      this.width = parseInt(this.parameters[3])
    }
    this.settings.unshift(['WIDTH', this.width])
    if (this.parameters[4]) {
      this.height = parseInt(this.parameters[4])
    }
    if (this.parameters[5]) {
      this.formatter = this.parameters[5]
    }
    if (this.parameters[6]) {
      this.itemsPerRow = parseInt(this.parameters[6])
    }
  },
  methods: {
    getType() {
      var type = 'CONVERTED'
      if (this.parameters[7]) {
        type = this.parameters[7]
      }
      return type
    },
    formatValue(data) {
      var text = ''
      var space = ' '
      var newLine = '\n'
      var count = 0

      if (Array.isArray(data)) {
        for (const value of data) {
          if (this.formatter) {
            text += sprintf(this.formatter, value)
          } else {
            text += value
          }
          count += 1
          if (count % this.itemsPerRow === 0) {
            count = 0
            text += newLine
          } else {
            text += space
          }
        }
        return text.trim()
      } else {
        return data
      }
    },
  },
}
</script>

<style scoped>
.value >>> div {
  min-height: 24px !important;
  display: flex !important;
  align-items: center !important;
}
.cosmos-green >>> input {
  color: rgb(0, 150, 0);
}
.cosmos-yellow >>> input {
  color: rgb(190, 135, 0);
}
.cosmos-red >>> input {
  color: red;
}
.cosmos-blue >>> input {
  color: rgb(0, 100, 255);
}
.cosmos-purple >>> input {
  color: rgb(200, 0, 200);
}
.cosmos-black >>> input {
  color: black;
}
.cosmos-white >>> input {
  color: white;
}
</style>
