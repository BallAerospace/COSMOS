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
  <text :x="parameters[0]" :y="parameters[1]" :fill="fillColor">
    {{ parameters[2] }}
  </text>
</template>

<script>
import Widget from './Widget'
export default {
  mixins: [Widget],
  computed: {
    fillColor() {
      if (this.parameters[3]) {
        return this.parameters[3]
      }
      return 'black'
    },
  },
}
</script>
