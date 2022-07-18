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
  <v-footer id="footer" app color="tertiary darken-3" height="33">
    <img :src="logo" alt="OpenC3" width="20" height="20" />
    <span class="footer-text" style="margin-left: 5px">
      OpenC3 {{ openc3Version }} &copy; 2022
    </span>
    <v-spacer />
    <a :href="sourceUrl" class="white--text text-decoration-underline">
      Source
    </a>
    <v-spacer />
    <div class="justify-right"><clock-footer /></div>
  </v-footer>
</template>

<script>
import ClockFooter from './components/ClockFooter.vue'
import { OpenC3Api } from '../../packages/openc3-tool-common/src/services/openc3-api'
import logo from '../public/img/logo.png'

export default {
  components: {
    ClockFooter,
  },
  data() {
    return {
      logo: logo,
      sourceUrl: '',
      openc3Version: '',
    }
  },
  created: function () {
    this.getSourceUrl()
  },
  methods: {
    getSourceUrl: function () {
      new OpenC3Api()
        .get_settings(['source_url', 'version'])
        .then((response) => {
          this.sourceUrl = response[0]
          this.openc3Version = `(${response[1]})`
        })
    },
  },
}
</script>

<style scoped>
#footer {
  z-index: 1000; /* On TOP! */
}
</style>
