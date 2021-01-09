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
  <image
    :href="calcHref"
    :x="parameters[1]"
    :y="parameters[2]"
    :width="calcWidth"
    :height="calcHeight"
  />
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
  computed: {
    calcHref() {
      if (this.parameters[0].includes('http')) {
        return this.parameters[0]
      } else {
        return 'img/' + this.parameters[0]
      }
    },
    calcWidth() {
      if (this.parameters[3]) {
        return this.parameters[3] + 'px'
      }
      return '100%'
    },
    calcHeight() {
      if (this.parameters[4]) {
        return this.parameters[4] + 'px'
      }
      return '100%'
    },
  },
}
</script>
