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
  <component :is="widgetType" v-bind="{ ...$props, ...$attrs }"></component>
</template>

<script>
export default {
  data() {
    return {
      widgetType: null,
    }
  },
  props: {
    name: { default: null },
  },
  computed: {
    url: function () {
      let path =
        window.location.origin +
        '/tools/widgets/' +
        this.name +
        '/' +
        this.name +
        '.umd.min.js'
      return path
    },
  },
  mounted() {
    const self = this

    /* eslint-disable-next-line */
    System.import(/* webpackIgnore: true */ this.url).then(function (widget) {
      self.widgetType = widget
    })
  },
}
</script>
