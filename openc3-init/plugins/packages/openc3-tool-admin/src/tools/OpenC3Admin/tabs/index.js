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

const TabsList = [
  {
    displayName: 'Plugins',
    path: 'plugins',
    component: () => import('@/tools/OpenC3Admin/tabs/PluginsTab'),
  },
  {
    displayName: 'Targets',
    path: 'targets',
    component: () => import('@/tools/OpenC3Admin/tabs/TargetsTab'),
  },
  {
    displayName: 'Interfaces',
    path: 'interfaces',
    component: () => import('@/tools/OpenC3Admin/tabs/InterfacesTab'),
  },
  {
    displayName: 'Routers',
    path: 'routers',
    component: () => import('@/tools/OpenC3Admin/tabs/RoutersTab'),
  },
  {
    displayName: 'Microservices',
    path: 'microservices',
    component: () => import('@/tools/OpenC3Admin/tabs/MicroservicesTab'),
  },
  {
    displayName: 'Gems',
    path: 'gems',
    component: () => import('@/tools/OpenC3Admin/tabs/GemsTab'),
  },
  {
    displayName: 'Tools',
    path: 'tools',
    component: () => import('@/tools/OpenC3Admin/tabs/ToolsTab'),
  },
  {
    displayName: 'Redis',
    path: 'redis',
    component: () => import('@/tools/OpenC3Admin/tabs/RedisTab'),
  },
  {
    displayName: 'Settings',
    path: 'settings',
    component: () => import('@/tools/OpenC3Admin/tabs/SettingsTab'),
  },
]

export { TabsList }
