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
  <v-footer id="footer" app color="tertiary darken-3" height="33">
    <img :src="logo" alt="COSMOS" width="20" height="20" />
    <span class="footer-text" style="margin-left: 5px">COSMOS &copy; 2021</span>
    <v-spacer />
  </v-footer>
</template>

<script>
import logo from '../public/img/logo.png'
export default {
  data() {
    return {
      logo: logo,
    }
  },
}
</script>

<style scoped>
#footer {
  z-index: 1000; /* On TOP! */
}
</style>
