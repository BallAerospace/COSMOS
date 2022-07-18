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
  <div ref="container" class="d-flex flex-row">
    <label-widget
      :parameters="labelName"
      :settings="settings"
      :style="computedStyle"
      :widget-index="0"
    />
    <progressbar-widget
      :parameters="parameters"
      :settings="settings"
      :style="computedStyle"
      :widget-index="1"
    />
  </div>
</template>

<script>
import Widget from './Widget'
import LabelWidget from './LabelWidget.vue'
import ProgressbarWidget from './ProgressbarWidget.vue'

export default {
  mixins: [Widget],
  components: {
    LabelWidget,
    ProgressbarWidget,
  },
  computed: {
    labelName() {
      // LabelWidget uses index 0 from the parameters prop
      // so create an array with the label text in the first position
      return [this.parameters[2] + ':']
    },
  },
}
</script>
