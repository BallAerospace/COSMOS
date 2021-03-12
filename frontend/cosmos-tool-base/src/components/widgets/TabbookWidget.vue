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
    <v-tabs v-model="curTab">
      <v-tab v-for="(tab, index) in widgets" :key="index">
        {{ tab.parameters[0] }}
      </v-tab>
    </v-tabs>
    <v-tabs-items v-model="curTab">
      <v-tab-item v-for="(tab, tabIndex) in widgets" :key="tabIndex">
        <component
          v-for="(widget, widgetIndex) in tab.widgets"
          :key="`${tabIndex}-${widgetIndex}`"
          :is="widget.type"
          :parameters="widget.parameters"
          :settings="widget.settings"
          :widgets="widget.widgets"
        />
      </v-tab-item>
    </v-tabs-items>
  </div>
</template>

<script>
import Layout from './Layout'
export default {
  mixins: [Layout],
  data: function () {
    return {
      curTab: null,
    }
  },
  watch: {
    curTab: function () {
      this.$emit('min-max-screen')
    },
  },
}
</script>
