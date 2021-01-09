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
  <v-footer id="footer" app color="tertiary darken-3">
    <img src="/img/logo.png" alt="COSMOS" width="20" />
    <span class="footer-text" style="margin-left: 5px">COSMOS &copy; 2020</span>
    <v-spacer />
    <!-- <v-btn color="primary" small rounded @click="toggleTheme"
      >Toggle Theme</v-btn
    > -->
  </v-footer>
</template>

<script>
export default {
  // TODO: Disable this until we can provide better CSS support throughout
  // methods: {
  //   toggleTheme() {
  //     this.$vuetify.theme.dark = !this.$vuetify.theme.dark
  //   },
  // },
}
</script>

<style scoped>
#footer {
  z-index: 1000; /* On TOP! */
}
</style>
