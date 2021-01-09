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

export default {
  props: {
    widgetIndex: {
      type: Number,
      default: null,
    },
    parameters: {
      type: Array,
      default: () => [],
    },
    settings: {
      type: Array,
      default: () => [],
    },
  },
  computed: {
    computedStyle() {
      let style = {}
      this.settings.forEach((setting) => {
        const index = parseInt(setting[0])
        if (this.widgetIndex !== null) {
          if (this.widgetIndex === index) {
            setting = setting.slice(1)
          } else {
            return
          }
        }
        switch (setting[0]) {
          case 'TEXTALIGN':
            style['text-align'] = setting[1].toLowerCase()
            break
          case 'PADDING':
            style['padding'] = setting[1] + 'px !important'
            break
          case 'MARGIN':
            style['margin'] = setting[1] + 'px !important'
            break
          case 'BACKCOLOR':
            style['background-color'] = this.getColor(setting.slice(1))
            break
          case 'TEXTCOLOR':
            style['color'] = this.getColor(setting.slice(1))
            break
          case 'BORDERCOLOR':
            style['border-width'] = '1px'
            style['border-style'] = 'solid'
            style['border-color'] = this.getColor(setting.slice(1))
            break
          case 'WIDTH':
            style['width'] = setting[1] + 'px !important'
            break
          case 'HEIGHT':
            style['height'] = setting[1] + 'px !important'
            break
          case 'RAW':
            style[setting[1].toLowerCase()] = setting[2]
            break
        }
      })
      return style
    },
  },
  methods: {
    // Expects an array, can either be a single color or 3 rgb values
    getColor(setting) {
      switch (setting.length) {
        case 1:
          return setting[0].toLowerCase()
        case 3:
          return `rgb(${setting[0]},${setting[1]},${setting[2]})`
      }
    },
  },
}
