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
  <div class="value-widget-container">
    <v-tooltip bottom>
      <template v-slot:activator="{ on, attrs }">
        <v-text-field
          solo
          dense
          readonly
          single-line
          hide-no-data
          hide-details
          placeholder="Value"
          :value="_value"
          :class="valueClass"
          :style="computedStyle"
          data-test="value"
          @contextmenu="showContextMenu"
          v-bind="attrs"
          v-on="on"
        />
      </template>
      <span>{{ fullName }}</span>
    </v-tooltip>
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
      :target-name="parameters[0]"
      :packet-name="parameters[1]"
      :item-name="parameters[2]"
      v-model="viewDetails"
    />
  </div>
</template>

<script>
import VWidget from '@openc3/tool-common/src/components/widgets/VWidget'
import DetailsDialog from '@openc3/tool-common/src/components/DetailsDialog'

export default {
  components: {
    DetailsDialog,
  },
  mixins: [VWidget],
  computed: {
    fullName() {
      return (
        this.parameters[0] + ' ' + this.parameters[1] + ' ' + this.parameters[2]
      )
    },
  },
}
</script>

<style lang="scss" scoped>
.value-widget-container {
  min-height: 100px;
}
.value ::v-deep div {
  min-height: 88px !important;
  display: flex !important;
  align-items: center !important;
}
.value-widget-container ::v-deep input {
  max-height: none !important;
  line-height: 70px !important;
  font-size: 60px !important;
}
// TODO: These openc3 styles are also defined in assets/stylesheets/layout/_overrides.scss
// Can they somehow be reused here? We need to force the style down into the input
.openc3-green ::v-deep input {
  color: rgb(0, 150, 0);
}
.openc3-yellow ::v-deep input {
  color: rgb(190, 135, 0);
}
.openc3-red ::v-deep input {
  color: red;
}
.openc3-blue ::v-deep input {
  color: rgb(0, 100, 255);
}
.openc3-purple ::v-deep input {
  color: rgb(200, 0, 200);
}
.openc3-black ::v-deep input {
  color: black;
}
.openc3-white ::v-deep input {
  color: white;
}
</style>
