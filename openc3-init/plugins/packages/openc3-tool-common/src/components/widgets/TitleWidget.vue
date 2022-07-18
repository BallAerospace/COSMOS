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
  <span class="text-h5 text-center pa-1 mt-1 label" :style="computedStyle">
    {{ labelText }}
  </span>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  computed: {
    labelText() {
      return this.parameters[0]
    },
  },
  created() {
    if (this.parameters.length < 1) {
      throw new Error('Not enough parameters for TITLE.')
    }
  },
}
</script>
