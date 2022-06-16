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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <v-app :style="classificationStyles">
    <app-nav class="d-print-none" />

    <!-- Sizes your content based upon application components -->
    <v-main>
      <v-container fluid>
        <div id="cosmos-tool"></div>
        <div><router-view /></div>
      </v-container>
    </v-main>
    <app-footer app class="d-print-none" />
    <time-check />
  </v-app>
</template>

<script>
import AppFooter from './AppFooter'
import AppNav from './AppNav'
import TimeCheck from './components/TimeCheck'
import ClassificationBanners from './components/ClassificationBanners'
export default {
  components: {
    AppFooter,
    AppNav,
    TimeCheck,
  },
  mixins: [ClassificationBanners],
}
</script>
