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
  <div
    ref="container"
    class="d-flex flex-row"
    :style="[defaultStyle, computedStyle]"
  >
    <value-widget :parameters="parameters" :settings="settings" />
    <limitsbar-widget
      :parameters="limitsBarParameters"
      :settings="settings.filter((x) => x[0] == 1).map((x) => x.slice(1))"
    />
  </div>
</template>

<script>
import ValueWidget from './ValueWidget.vue'
import LimitsbarWidget from './LimitsbarWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    ValueWidget,
    LimitsbarWidget,
  },
  computed: {
    limitsBarParameters() {
      return [
        this.parameters[0],
        this.parameters[1],
        this.parameters[2],
        'CONVERTED',
      ]
    },
    defaultStyle() {
      return {
        width: '300px',
      }
    },
  },
}
</script>
