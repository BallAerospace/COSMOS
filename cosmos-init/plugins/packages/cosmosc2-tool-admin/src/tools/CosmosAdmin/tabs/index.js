/*
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
*/

const TabsList = [
  {
    displayName: 'Plugins',
    path: 'plugins',
    component: () => import('@/tools/CosmosAdmin/tabs/PluginsTab'),
  },
  {
    displayName: 'Targets',
    path: 'targets',
    component: () => import('@/tools/CosmosAdmin/tabs/TargetsTab'),
  },
  {
    displayName: 'Interfaces',
    path: 'interfaces',
    component: () => import('@/tools/CosmosAdmin/tabs/InterfacesTab'),
  },
  {
    displayName: 'Routers',
    path: 'routers',
    component: () => import('@/tools/CosmosAdmin/tabs/RoutersTab'),
  },
  {
    displayName: 'Microservices',
    path: 'microservices',
    component: () => import('@/tools/CosmosAdmin/tabs/MicroservicesTab'),
  },
  {
    displayName: 'Gems',
    path: 'gems',
    component: () => import('@/tools/CosmosAdmin/tabs/GemsTab'),
  },
  {
    displayName: 'Tools',
    path: 'tools',
    component: () => import('@/tools/CosmosAdmin/tabs/ToolsTab'),
  },
  {
    displayName: 'Redis',
    path: 'redis',
    component: () => import('@/tools/CosmosAdmin/tabs/RedisTab'),
  },
  {
    displayName: 'Settings',
    path: 'settings',
    component: () => import('@/tools/CosmosAdmin/tabs/SettingsTab'),
  },
]

export { TabsList }
