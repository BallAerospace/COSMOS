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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <div>
    <v-banner single-line>{{ parameters.join(' ') }}</v-banner>
    <horizontal-widget
      v-on="$listeners"
      :parameters="parameters"
      :settings="settings"
      :widgets="widgets"
    />
  </div>
</template>

<script>
import HorizontalWidget from './HorizontalWidget'
import Layout from './Layout'
export default {
  mixins: [Layout],
  components: {
    HorizontalWidget,
  },
}
</script>

<style scoped>
.v-banner >>> div {
  background-color: var(--v-tertiary-darken2) !important;
}
</style>
