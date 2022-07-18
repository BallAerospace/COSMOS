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
  <v-badge
    color="transparent"
    left
    :inline="inline"
    :offset-x="offsetX"
    :offset-y="offsetY + 12"
  >
    <template v-slot:badge>
      <astro-status-indicator :status="status" small />
    </template>
    <slot />
  </v-badge>
</template>

<script>
import AstroStatusIndicator from './AstroStatusIndicator.vue'
export default {
  components: {
    AstroStatusIndicator,
  },
  props: {
    status: {
      type: String,
      required: true,
    },
    offsetX: {
      type: [Number, String],
    },
    offsetY: {
      type: [Number, String],
      default: 0,
    },
    inline: {
      type: Boolean,
    },
  },
}
</script>
