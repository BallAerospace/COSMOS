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
  <rux-icon :icon="icon" class="astro-icon" />
</template>

<script>
import { RuxIcon } from '@astrouxds/rux-icon' // VSCode might falsely show this as an unused import
import { AstroIconLibrary } from '.'

// This component is a wrapper around the Astro UXDS RuxIcon to make it work with Vuetify
export default {
  props: {
    icon: {
      type: String,
      required: true,
      validator: (val) => {
        return (
          AstroIconLibrary.includes(val) &&
          (!val.startsWith('status-') ||
            ['settings-outline', 'notifications-outline'].includes(val)) // These were renamed
        )
      },
    },
  },
  created: function () {
    if (this.$parent.$options.name !== 'v-icon') {
      console.warn("AstroIcon shouldn't be used directly. Use v-icon instead.")
    }
  },
}
</script>

<style scoped>
.astro-icon {
  fill: currentColor;
}
</style>
