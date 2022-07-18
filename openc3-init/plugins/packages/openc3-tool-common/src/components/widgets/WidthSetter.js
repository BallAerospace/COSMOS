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

export default {
  data: function () {
    return {
      originalWidthSetting: null,
    }
  },
  created: function () {
    this.originalWidthSetting = ['WIDTH', this.width]
    this.resetWidth()
  },
  beforeUpdate: function () {
    this.resetWidth()
  },
  methods: {
    resetWidth: function () {
      // This sets 'WIDTH' when it gets created, but that is lost if it gets
      // re-rendered by OpenC3Screen.vue parsing the config string again
      if (!this.settings.some((setting) => setting[0] === 'WIDTH')) {
        this.settings.unshift(this.originalWidthSetting)
      }
    },
  },
}
