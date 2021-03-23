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

import AstroIcon from './AstroIcon'
import AstroStatusIcon from './AstroStatusIcon'

const _statusIconLibrary = [
  // These are from the IDs in the Astro icons.svg: https://github.com/RocketCommunicationsInc/astro-components/blob/master/static/img/icons.svg
  'emergency',
  'caution',
  'error',
  'ok',
  'standby',
  'off',
  'null', // transparent #C6CCD1 square
  'checkmark',

  // These were renamed for consistency:
  // 'fpo',
  // 'notifications',
  // 'settings',

  // These are duplicated in the default RuxIcon library. Use AstroIcon instead
  // 'caution', // duplicate
  // 'antenna',
  // 'antenna-transmit',
  // 'antenna-receive',
  // 'satellite',
  // 'satellite-transmit',
  // 'satellite-receive',
  // 'mission',
  // 'antenna', // duplicate
  // 'payload',
  // 'altitude',
  // 'propulsion-power',
  // 'netcom',
  // 'thermal',
  // 'equipment',
  // 'processor',
  // 'close',
  // 'close-small',
]

const _defaultIconLibrary = [
  // These are from the IDs in the default RuxIcon library: https://github.com/RocketCommunicationsInc/astro-components/blob/master/static/icons/astro.svg
  'altitude',
  'antenna',
  'antenna-off',
  'antenna-receive',
  'antenna-transmit',
  'equipment',
  'mission',
  'payload',
  'processor',
  'processor-alt',
  'netcom',
  'propulsion-power',
  'thermal',
  'satellite-off',
  'satellite-receive',
  'satellite-transmit',
  'add-large',
  'add-small',
  'close-large',
  'close-small',
  'collapse',
  'expand',
  'lock',
  'unlock',
  'search',
  'caution',
  'maintenance',

  // These were renamed for consistency:
  // 'notifications',
  // 'settings',

  // These are in that SVG file, but they're broken in RuxIcon:
  // 'twitter', // the twitter logo
  // 'progress', // circle
  // 'resources', // filing cabinet
  // 'solar', // grid
]

const _renamedIcons = {
  ['astro-fpo']: {
    component: AstroStatusIcon,
    props: {
      icon: 'fpo',
    },
  },
  ['astro-settings']: {
    component: AstroStatusIcon,
    props: {
      icon: 'settings',
    },
  },
  ['astro-settings-outline']: {
    component: AstroIcon,
    props: {
      icon: 'settings',
    },
  },
  ['astro-notifications']: {
    component: AstroStatusIcon,
    props: {
      icon: 'notifications',
    },
  },
  ['astro-notifications-outline']: {
    component: AstroIcon,
    props: {
      icon: 'notifications',
    },
  },
}

const _providedIconLibrary = _statusIconLibrary
  .map((icon) => `status-${icon}`)
  .concat(_defaultIconLibrary)

const _renamedIconLibrary = Object.keys(_renamedIcons).map((icon) =>
  icon.replace(/^astro\-/, '')
)

const AstroIconLibrary = _providedIconLibrary.concat(_renamedIconLibrary)

const AstroIconVuetifyValues = _providedIconLibrary.reduce(
  (values, icon) => {
    return {
      [`astro-${icon}`]: {
        component: icon.startsWith('status-') ? AstroStatusIcon : AstroIcon,
        props: {
          icon,
        },
      },
      ...values,
    }
  },
  {
    ..._renamedIcons,
  }
)

export { AstroIconLibrary, AstroIconVuetifyValues }
