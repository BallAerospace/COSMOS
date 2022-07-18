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
  <v-radio-group
    hide-details
    dense
    v-model="selectedIndex"
    :style="computedStyle"
  >
    <component
      v-for="(widget, index) in widgets"
      v-on="$listeners"
      :value="index"
      :key="index"
      :is="widget.type"
      :target="widget.target"
      :parameters="widget.parameters"
      :settings="widget.settings"
      :name="widget.name"
    />
  </v-radio-group>
</template>

<script>
import Layout from './Layout'

export default {
  mixins: [Layout],
  data() {
    return {
      selectedIndex: 0,
    }
  },
  created() {
    // Look through the settings and see if we're a NAMED_WIDGET
    this.settings.forEach((setting) => {
      if (setting[0] === 'NAMED_WIDGET') {
        setting[2].setNamedWidget(setting[1], this)
      }
    })
    if (this.parameters[0]) {
      this.selectedIndex = parseInt(this.parameters[0])
    }
  },
  methods: {
    selected() {
      return this.selectedIndex
    },
  },
}
</script>
