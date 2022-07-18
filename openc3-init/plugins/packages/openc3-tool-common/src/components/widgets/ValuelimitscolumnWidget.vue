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
  <div ref="container" class="d-flex flex-column" :style="computedStyle">
    <limitscolumn-widget
      :parameters="limitsColumnParameters"
      :settings="settings"
      :widget-index="0"
    />
    <value-widget
      :parameters="parameters"
      :settings="settings"
      :widget-index="1"
    />
  </div>
</template>

<script>
import ValueWidget from './ValueWidget.vue'
import LimitscolumnWidget from './LimitscolumnWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    ValueWidget,
    LimitscolumnWidget,
  },
  created() {
    this.settings.push(['WIDTH', '100'])
  },
  computed: {
    limitsColumnParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        'CONVERTED',
      ]
    },
  },
}
</script>
