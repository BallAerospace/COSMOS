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
  <div ref="container" class="d-flex flex-row" :style="computedStyle">
    <value-widget
      :parameters="getParameters"
      :settings="settings"
      :format-string="parameters[3]"
    />
  </div>
</template>

<script>
import Widget from './Widget'
import ValueWidget from './ValueWidget.vue'

export default {
  mixins: [Widget],
  components: {
    ValueWidget,
  },
  computed: {
    getParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        this.parameters[4],
      ]
    },
  },
}
</script>
