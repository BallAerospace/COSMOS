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
  'caution',
  'maintenance',
  'notifications',
  'settings',

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

const AstroStatusColors = {
  critical: '#ff3838',
  serious: '#ffb302',
  caution: '#fce83a',
  normal: '#56f000',
  standby: '#2dccff',
  off: '#9ea7ad',
}

const getStatusColorContrast = function (severity) {
  const black = '#000000'
  const white = '#ffffff'

  const statusColor = AstroStatusColors[severity]
  if (statusColor) {
    const r = Number(`0x${statusColor.slice(1, 3)}`)
    const g = Number(`0x${statusColor.slice(3, 5)}`)
    const b = Number(`0x${statusColor.slice(5, 7)}`)
    const brightness = (r * 299 + g * 587 + b * 114) / 1000 // https://www.w3.org/TR/AERT/#color-contrast

    if (brightness > 128) return black
  }
  return white
}

const AstroStatuses = Object.keys(AstroStatusColors)

export {
  AstroIconLibrary,
  AstroIconVuetifyValues,
  AstroStatuses,
  AstroStatusColors,
  getStatusColorContrast,
}
