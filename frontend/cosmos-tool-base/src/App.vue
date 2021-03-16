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
  <v-app id="app" :style="classificationStyles">
    <!-- Sizes your content based upon application components -->
    <v-main>
      <!-- Provides the application the proper gutter -->
      <v-container fluid>
        <router-view />
      </v-container>
    </v-main>
    <app-footer app />
    <time-check />
  </v-app>
</template>

<script>
import AppFooter from '@/AppFooter'
import TimeCheck from '@/components/TimeCheck'
import ClassificationBanners from '@/components/ClassificationBanners'

export default {
  components: {
    AppFooter,
    TimeCheck,
  },
  mixins: [ClassificationBanners],
}
</script>
