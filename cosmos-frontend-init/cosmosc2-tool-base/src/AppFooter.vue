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
    <a :href="sourceUrl" class="white--text text-decoration-underline">
      Source
    </a>
    <v-spacer />
    <div class="justify-right"><clock-footer /></div>
  </v-footer>
</template>

<script>
import { CosmosApi } from '../../packages/cosmosc2-tool-common/src/services/cosmos-api'
import logo from '../public/img/logo.png'
import ClockFooter from './components/ClockFooter.vue'

export default {
  components: {
    ClockFooter,
  },
  data() {
    return {
      api: new CosmosApi(),
      logo: logo,
      sourceUrl: '',
    }
  },
  created: function () {
    this.getSourceUrl()
  },
  methods: {
    getSourceUrl: function () {
      this.api.get_setting('source_url').then((response) => {
        this.sourceUrl = response
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
