/*
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
*/

import Vue from 'vue'
import Router from 'vue-router'

Vue.use(Router)

export default new Router({
  mode: 'history',
  base: process.env.BASE_URL,
  routes: [
    {
      path: '/:target?/:packet?/:item?',
      name: 'TlmGrapher',
      component: () => import('./tools/TlmGrapher/TlmGrapher.vue'),
      meta: { title: 'Telemetry Grapher', icon: 'mdi-chart-line' },
    },
    // TODO: Create NotFoundComponent since we're doing history browser mode
    // See: https://router.vuejs.org/guide/essentials/history-mode.html#example-server-configurations
    // {
    //   path: '*',
    //   component: NotFoundComponent
    // }
  ],
})
