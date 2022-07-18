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
  <span id="rux-icon" :title="label" :style="style" :size="size">
    <!-- Camel case props becase svg -->
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 128 128"
      preserveAspectRatio="xMidYMid meet"
      focusable="false"
    >
      <use :href="getIcon(this.library, this.icon)" />
    </svg>
  </span>
</template>

<script>
// This component is a rewrite of the Astro UXDS RuxIcon into Vue
// Prevents multiple customElement problem with single-spa
export default {
  props: {
    icon: {
      type: String,
    },
    size: {
      type: String,
      default: 'extra-small',
    },
    color: {
      type: String,
    },
    library: {
      type: String,
      default: '/icons/astro.svg',
    },
    label: {
      type: String,
      default: 'icon',
    },
  },
  computed: {
    style: function () {
      return '--iconColor=' + this.propscolor
    },
  },
  methods: {
    getIcon() {
      return this.library + '#' + this.icon
    },
  },
}
</script>
