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
  <g>
    <image
      v-for="image in images"
      :key="image.value"
      v-show="image.value == selectedValue"
      :href="image.url"
      :x="image.x"
      :y="image.y"
      :width="image.width"
      :height="image.height"
    />
    <image
      v-if="defaultImage"
      v-show="showDefault"
      :href="defaultImage.url"
      :x="defaultImage.x"
      :y="defaultImage.y"
      :width="defaultImage.width"
      :height="defaultImage.height"
    />
  </g>
</template>

<script>
import Widget from './Widget'
import ImageLoader from './ImageLoader'

export default {
  mixins: [Widget, ImageLoader],
  data: function () {
    return {
      images: [],
      defaultImage: null,
    }
  },
  computed: {
    valueId: function () {
      return `${this.parameters[0]}__${this.parameters[1]}__${
        this.parameters[2]
      }__${this.parameters[3] || 'RAW'}`
    },
    selectedValue: function () {
      return this.$store.state.tlmViewerValues[this.valueId][0]
    },
    showDefault: function () {
      return !this.images.some((image) => image.value == this.selectedValue)
    },
  },
  watch: {
    valueId: {
      immediate: true,
      handler: function (val) {
        this.$store.commit('tlmViewerAddItem', val)
      },
    },
  },
  created: function () {
    // Set value images data
    const promises = this.settings
      .filter((setting) => setting[0] === 'IMAGE')
      .map(async (setting) => {
        let url = setting[2]
        if (!url.startsWith('http')) {
          url = await this.getPresignedUrl(url)
        }

        return {
          url,
          value: setting[1],
          x: setting[3],
          y: setting[4],
          width: setting[5],
          height: setting[6],
        }
      })
    Promise.all(promises).then((images) => {
      this.images = images
    })

    // Set default image data
    if (this.parameters[4]) {
      const defaultImage = {
        x: this.parameters[5],
        y: this.parameters[6],
        width: this.parameters[7] ? `${this.parameters[7]}px` : '100%',
        height: this.parameters[8] ? `${this.parameters[8]}px` : '100%',
      }

      let url = this.parameters[4]
      if (!url.startsWith('http')) {
        this.getPresignedUrl(url).then((response) => {
          this.defaultImage = {
            ...defaultImage,
            url: response,
          }
        })
      } else {
        this.defaultImage = {
          ...defaultImage,
          url,
        }
      }
    }
  },
  destroyed: function () {
    this.$store.commit('tlmViewerDeleteItem', this.valueId)
  },
}
</script>
