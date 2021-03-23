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
  <astro-badge :status="status" offset-x="10">
    <v-icon :color="color || statusColor"> {{ icon }} </v-icon>
  </astro-badge>
</template>

<script>
import AstroBadge from './AstroBadge.vue'

export default {
  components: { AstroBadge },
  props: {
    status: {
      type: String,
      required: true,
      validator: (val) =>
        ['emergency', 'caution', 'error', 'ok', 'standby', 'off'].includes(val),
    },
    icon: {
      type: String,
      required: true,
    },
    color: {
      type: String,
    },
  },
  computed: {
    statusColor: function () {
      // These are from the fill colors in Astro's icons.svg: https://github.com/RocketCommunicationsInc/astro-components/blob/master/static/img/icons.svg
      const dictionary = {
        emergency: '#F72501',
        caution: '#F8E81C',
        error: '#C05846',
        ok: '#7ED321',
        standby: '#A1DCFB',
        off: '#C6CCD1',
      }
      return dictionary[this.status]
    },
  },
}
</script>
