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

const AstroIconLibrary = [
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
  'notifications',
  'settings',
  'caution',
  'maintenance',
  // These are in that SVG file, but they're broken in RuxIcon:
  // 'twitter', // the twitter logo
  // 'progress', // circle
  // 'resources', // filing cabinet
  // 'solar', // grid
]

const AstroIconVuetifyValues = AstroIconLibrary.reduce((values, icon) => {
  return {
    [`astro-${icon}`]: {
      component: AstroIcon,
      props: {
        icon,
      },
    },
    ...values,
  }
}, {})

export { AstroIcon, AstroIconLibrary, AstroIconVuetifyValues }
