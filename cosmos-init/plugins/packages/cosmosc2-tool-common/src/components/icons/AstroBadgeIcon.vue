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
  <astro-badge :status="status">
    <v-icon :color="color || statusColor">
      <slot v-if="$slots.default" />
      <template v-else> {{ icon }} </template>
    </v-icon>
  </astro-badge>
</template>

<script>
import { AstroStatusColors } from '.'
import AstroBadge from './AstroBadge.vue'

export default {
  components: { AstroBadge },
  props: {
    status: {
      type: String,
      required: true,
    },
    icon: {
      type: String,
    },
    color: {
      type: String,
    },
  },
  computed: {
    statusColor: function () {
      return AstroStatusColors[this.status]
    },
  },
}
</script>
