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

<script>
import { OpenC3Api } from '../../../packages/openc3-tool-common/src/services/openc3-api'

export default {
  data: function () {
    return {
      api: null,
      classification: {
        text: '',
        fontColor: 'white',
        backgroundColor: 'red',
        topHeight: 0,
        bottomHeight: 0,
      },
    }
  },
  computed: {
    classificationStyles: function () {
      // JavaScript can't access CSS psudo-elements (::before and ::after).
      // This string sets these JS values to CSS variables, accessible to
      // the style sheet via the style attribute on #app
      return [
        `--classification-text:"${this.classification.text}";`,
        `--classification-font-color:${this.classification.fontColor};`,
        `--classification-background-color:${this.classification.backgroundColor};`,
        `--classification-height-top:${this.classification.topHeight}px;`,
        `--classification-height-bottom:${this.classification.bottomHeight}px;`,
      ].join('')
    },
  },
  created: function () {
    this.api = new OpenC3Api()
    this.load()
  },
  methods: {
    load: function () {
      this.api.get_setting('classification_banner').then((response) => {
        if (response) {
          this.classification = JSON.parse(response)
        }
      })
    },
  },
}
</script>

<style>
/* push things up and down to make room for the classification banners */
#app,
#openc3-nav-drawer {
  margin-top: var(--classification-height-top);
}
#openc3-app-toolbar {
  top: var(--classification-height-top);
}
#openc3-nav-drawer .v-navigation-drawer__content {
  height: calc(
    100% - var(--classification-height-top) -
      var(--classification-height-bottom)
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
  color: var(--classification-font-color);
  background-color: var(--classification-background-color);
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
