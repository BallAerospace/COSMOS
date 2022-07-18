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
    <labelvalue-widget :parameters="parameters" :settings="settings" />
    <limitsbar-widget
      :parameters="limitsBarParameters"
      :settings="settings.filter((x) => x[0] == 1).map((x) => x.slice(1))"
      :widget-index="3"
    />
  </div>
</template>

<script>
import LabelvalueWidget from './LabelvalueWidget.vue'
import LimitsbarWidget from './LimitsbarWidget.vue'
import Widget from './Widget'

export default {
  mixins: [Widget],
  components: {
    LabelvalueWidget,
    LimitsbarWidget,
  },
  data() {
    return {
      overallWidth: '300px',
    }
  },
  created() {
    // Determine if any sub-setting widths have been given
    // If so calculate the overall width, if not the default will be used
    let width = 0
    this.settings.forEach((setting) => {
      if (setting[1] === 'WIDTH') {
        width += parseInt(setting[2])
      }
    })
    if (width != 0) {
      this.overallWidth = width + 'px'
    }
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
        width: this.overallWidth,
      }
    },
  },
}
</script>
