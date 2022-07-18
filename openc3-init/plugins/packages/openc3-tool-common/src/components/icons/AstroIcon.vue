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
  <rux-icon :icon="icon" class="astro-icon" />
</template>

<script>
import RuxIcon from './RuxIcon.vue'
import { AstroIconLibrary } from '.'

// This component is a wrapper around the Astro UXDS RuxIcon to make it work with Vuetify
export default {
  components: {
    RuxIcon,
  },
  props: {
    icon: {
      type: String,
      required: true,
      validator: (val) => {
        return AstroIconLibrary.includes(val)
      },
    },
  },
}
</script>

<style scoped>
.astro-icon {
  fill: currentColor;
}
</style>
