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
  <v-container class="pa-0">
    <v-row
      no-gutters
      v-for="(chunk, rindex) in widgetChunks"
      :key="'r' + rindex"
    >
      <v-col v-for="(widget, cindex) in chunk" :key="'c' + cindex">
        <component
          v-on="$listeners"
          :is="widget.type"
          :target="widget.target"
          :parameters="widget.parameters"
          :settings="widget.settings"
          :widgets="widget.widgets"
          :name="widget.name"
        />
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import Layout from './Layout'
import _ from 'lodash'
export default {
  mixins: [Layout],
  computed: {
    columns() {
      return parseInt(this.parameters[0])
    },
    widgetChunks() {
      return _.chunk(this.widgets, this.columns)
    },
  },
}
</script>
