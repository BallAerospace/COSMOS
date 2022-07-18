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
  <image
    v-if="imageUrl"
    :href="imageUrl"
    :x="parameters[1]"
    :y="parameters[2]"
    :width="width"
    :height="height"
  />
</template>

<script>
import Widget from './Widget'
import ImageLoader from './ImageLoader'

export default {
  mixins: [Widget, ImageLoader],
  data: function () {
    return {
      imageUrl: null,
    }
  },
  computed: {
    width: function () {
      if (this.parameters[3]) {
        return `${this.parameters[3]}px`
      }
      return '100%'
    },
    height: function () {
      if (this.parameters[4]) {
        return `${this.parameters[4]}px`
      }
      return '100%'
    },
  },
  created: function () {
    if (!this.parameters[0].startsWith('http')) {
      this.getPresignedUrl(this.parameters[0]).then((response) => {
        this.imageUrl = response
      })
    } else {
      this.imageUrl = this.parameters[0]
    }
  },
}
</script>
