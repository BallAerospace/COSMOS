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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
*/

import Vue from 'vue'
import Router from 'vue-router'

Vue.use(Router)

export default new Router({
  mode: 'history',
  base: process.env.BASE_URL,
  routes: [
    {
      path: '/',
      component: () => import('./tools/CmdTlmServer/CmdTlmServer.vue'),
      children: [
        {
          component: () => import('./tools/CmdTlmServer/InterfacesTab'),
          path: '',
        },
        {
          component: () => import('./tools/CmdTlmServer/InterfacesTab'),
          path: 'interfaces',
        },
        {
          component: () => import('./tools/CmdTlmServer/TargetsTab'),
          path: 'targets',
        },
        {
          component: () => import('./tools/CmdTlmServer/CmdPacketsTab'),
          path: 'cmd-packets',
        },
        {
          component: () => import('./tools/CmdTlmServer/TlmPacketsTab'),
          path: 'tlm-packets',
        },
        {
          component: () => import('./tools/CmdTlmServer/RoutersTab'),
          path: 'routers',
        },
        {
          component: () => import('./tools/CmdTlmServer/StatusTab'),
          path: 'status',
        },
      ],
    },

    // TODO: Create NotFoundComponent since we're doing history browser mode
    // See: https://router.vuejs.org/guide/essentials/history-mode.html#example-server-configurations
    // {
    //   path: '*',
    //   component: NotFoundComponent
    // }
  ],
})
