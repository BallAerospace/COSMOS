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
  <v-app id="app" :style="classificationStyleVariables">
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

export default {
  components: {
    AppFooter,
    TimeCheck,
  },
  data: function () {
    return {
      classification: {
        text: '',
        backgroundColor: 'red',
        topHeight: 0,
        bottomHeight: 0,
      },
    }
  },
  computed: {
    classificationStyleVariables: function () {
      // JavaScript can't access CSS psudo-elements (::before and ::after).
      // This string sets these JS values to CSS variables, accessible to
      // the style sheet via the style attribute on #app
      return [
        `--classification-text:"${this.classification.text}";`,
        `--classification-color:${this.classification.backgroundColor};`,
        `--classification-height-top:${this.classification.topHeight}px;`,
        `--classification-height-bottom:${this.classification.bottomHeight}px;`,
      ].join('')
    },
  },
}
</script>

<style>
/* push things up and down to make room for the classification banners */
#app,
#cosmos-nav-drawer {
  margin-top: var(--classification-height-top);
}
#cosmos-app-toolbar {
  top: var(--classification-height-top);
}
#cosmos-nav-drawer .v-navigation-drawer__content {
  /* this hardcoded 44px will need to be changed if more
  buttons are added to the nav drawer append section */
  height: calc(
    100% - var(--classification-height-top) -
      var(--classification-height-bottom) - 44px
  );
}
#footer {
  margin-bottom: var(--classification-height-bottom);
}

/* make the classification banners */
#app::before,
#app::after {
  z-index: 99;
  position: fixed;
  left: 0;
  right: 0;
  text-align: center;
  content: var(--classification-text);
  background-color: var(--classification-color);
}
#app::before {
  top: 0;
  font-size: calc(var(--classification-height-top) * 0.7);
  height: var(--classification-height-top);
}
#app::after {
  bottom: 0;
  font-size: calc(var(--classification-height-bottom) * 0.7);
  height: var(--classification-height-bottom);
}
</style>
