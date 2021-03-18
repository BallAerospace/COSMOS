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
  <svg :viewBox="viewBox" class="astro-icon">
    <!-- These defs are from Astro's icons.svg, but icons that were duplicated in astro.svg have been removed -->
    <defs>
      <g id="emergency">
        <path fill="#F72501" d="M12 12H0L6 0z" />
      </g>
      <g id="caution">
        <path fill="#F8E81C" d="M1 1h10v10H1z" />
      </g>
      <g id="error">
        <circle fill="#C05846" cx="6" cy="6" r="6" />
      </g>
      <g id="ok">
        <path fill="#7ED321" d="M1 3h10v5H1z" />
      </g>
      <g id="standby">
        <path
          fill="#A1DCFB"
          d="M6 12A6 6 0 1 1 6 0a6 6 0 0 1 0 12zm0-2a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"
        />
      </g>
      <g id="off">
        <path fill="#C6CCD1" d="M3 3h6v6H3z" />
      </g>
      <g id="null">
        <path fill="#C6CCD1" d="M3 3h6v6H3z" opacity="0" />
      </g>
      <path
        id="checkmark"
        fill="#329FFF"
        d="M46.837 94.562L95.153 5H114L57.46 109.806H38l-38-57h19z"
        fill-rule="evenodd"
      />
      <g id="close" fill-rule="evenodd">
        <path
          d="M57.5 115C25.744 115 0 89.256 0 57.5S25.744 0 57.5 0 115 25.744 115 57.5 89.256 115 57.5 115zm0-9.583c26.464 0 47.917-21.453 47.917-47.917 0-26.464-21.453-47.917-47.917-47.917-26.464 0-47.917 21.453-47.917 47.917 0 26.464 21.453 47.917 47.917 47.917z"
        />
        <path
          d="M62.545 58L83 78.455 78.455 83 58 62.545 37.545 83 33 78.455 53.455 58 33 37.545 37.545 33 58 53.455 78.455 33 83 37.545 62.545 58z"
        />
      </g>
      <g id="fpo">
        <path
          d="M96.153 26.162A13.074 13.074 0 0 1 84.07 18.09a13.085 13.085 0 0 1 2.831-14.257 13.07 13.07 0 0 1 14.25-2.837 13.08 13.08 0 0 1 8.071 12.085c0 7.223-5.85 13.079-13.07 13.08zM82.38 33.578a29.15 29.15 0 0 1 .693 6.588v52.708c0 14.084-7.205 21.126-21.613 21.126H29.652c-6.442 0-11.327-1.965-14.655-5.895-3.329-3.93-4.994-9.28-4.997-16.049V40.158a33.38 33.38 0 0 1 .342-4.888l1.732-6.165c2.89-6.83 9.184-9.928 19.205-9.928h31.807c4.502 0 8.35 1.112 11.548 3.151L49.929 38.171H38.2a6.983 6.983 0 0 0-4.995 2.046 6.994 6.994 0 0 0-2.047 4.998v43.114a6.994 6.994 0 0 0 2.047 4.997 6.983 6.983 0 0 0 4.995 2.046h16.665a6.987 6.987 0 0 0 5.157-2.047 6.607 6.607 0 0 0 2.05-4.835V53.032L82.38 33.578z"
        />
      </g>
      <g id="notifications">
        <path
          d="M20.667 60.167v-19c0-15.527 12.291-28.444 28.511-31.147a11.58 11.58 0 0 1-.011-.52c0-5.247 3.544-9.5 7.916-9.5C61.456 0 65 4.253 65 9.5c0 .398-.02.791-.06 1.177 14.651 3.74 25.393 15.975 25.393 30.49v19c0 12.242 5.671 22.166 12.667 22.166v15.834H8V82.333c6.996 0 12.667-9.924 12.667-22.166zM70.835 104.5c-1.758 5.463-7.957 9.5-15.335 9.5-7.378 0-13.577-4.037-15.335-9.5h30.67z"
        />
      </g>
      <g id="caution">
        <path
          d="M57.03 4c7.535 0 61.347 95.516 56.688 101.698-4.66 6.182-107.595 4.878-113.302 0C-5.291 100.82 49.494 4 57.03 4zm3.072 67.595l1.622-31.077H50.718l1.623 31.077h7.761zm-9.51 10.879c0 1.717.487 3.048 1.462 3.992.976.943 2.354 1.415 4.136 1.415 1.738 0 3.096-.482 4.071-1.447.976-.965 1.463-2.285 1.463-3.96 0-1.74-.482-3.075-1.447-4.008-.965-.933-2.327-1.4-4.087-1.4-1.824 0-3.213.456-4.167 1.368-.955.912-1.432 2.258-1.432 4.04z"
        />
      </g>
      <g id="settings">
        <path
          d="M42.384 114a58.481 58.481 0 0 1-16.12-6.821 14.654 14.654 0 0 0 1.303-6.06c0-8.123-6.584-14.707-14.705-14.707-2.16 0-4.212.466-6.06 1.303A58.49 58.49 0 0 1 0 71.669c7.63-.54 13.653-6.9 13.653-14.669 0-7.768-6.023-14.13-13.653-14.67a58.49 58.49 0 0 1 6.802-16.045c1.848.837 3.9 1.303 6.06 1.303 8.121 0 14.705-6.584 14.705-14.706 0-2.16-.466-4.213-1.303-6.06A58.481 58.481 0 0 1 42.384 0c.898 7.261 7.09 12.882 14.593 12.882C64.481 12.882 70.672 7.26 71.57 0a58.481 58.481 0 0 1 16.12 6.821 14.654 14.654 0 0 0-1.303 6.06c0 8.123 6.584 14.707 14.705 14.707 2.16 0 4.213-.466 6.06-1.303A58.488 58.488 0 0 1 114 42.511c-6.914 1.2-12.172 7.23-12.172 14.489 0 7.258 5.258 13.288 12.172 14.489a58.488 58.488 0 0 1-6.848 16.226 14.651 14.651 0 0 0-6.06-1.303c-8.121 0-14.705 6.584-14.705 14.706 0 2.16.466 4.213 1.303 6.06A58.481 58.481 0 0 1 71.57 114c-.898-7.261-7.09-12.882-14.593-12.882-7.504 0-13.695 5.621-14.593 12.882zm14.593-27.588c16.243 0 29.41-13.168 29.41-29.412S73.22 27.588 56.977 27.588c-16.243 0-29.41 13.168-29.41 29.412s13.167 29.412 29.41 29.412z"
        />
      </g>
    </defs>
    <use :xlink:href="`#${name}`" />
  </svg>
</template>

<script>
import { AstroIconLibrary } from '.'

export default {
  props: {
    icon: {
      type: String,
      required: true,
      validator: (val) => {
        return (
          AstroIconLibrary.includes(val) &&
          (val.startsWith('status-') ||
            ['fpo', 'settings', 'notifications'].includes(val)) // These were renamed
        )
      },
    },
  },
  computed: {
    name: function () {
      return this.icon.replace(/^status\-/, '')
    },
    viewBox: function () {
      return ['checkmark', 'fpo', 'notifications', 'settings'].includes(
        this.name
      )
        ? '0 0 114 114' // Display these how RuxIcon would display them
        : '-12 -10 35 35' // Compensate for the offset in the SVG paths to make the rest easier to use
    },
  },
  created: function () {
    if (this.$parent.$options.name !== 'v-icon') {
      console.warn(
        "AstroStatusIcon shouldn't be used directly. Use v-icon instead."
      )
    }
  },
}
</script>

<style scoped>
.astro-icon {
  fill: currentColor;
}
</style>
