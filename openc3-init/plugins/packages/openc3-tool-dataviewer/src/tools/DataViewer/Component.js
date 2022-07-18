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
  props: {
    config: {
      type: Object,
    },
  },
  data: function () {
    return {
      currentConfig: {},
      lastReceived: null,
    }
  },
  computed: {
    mode: function () {
      return this.lastReceived &&
        this.lastReceived.length > 0 &&
        'buffer' in this.lastReceived[0]
        ? 'RAW'
        : 'DECOM'
    },
  },
  watch: {
    currentConfig: {
      deep: true,
      handler: function (val) {
        this.$emit('config-change', val)
      },
    },
  },
  created: function () {
    if (this.config) {
      this.currentConfig = {
        ...this.config,
      }
    }
  },
  methods: {
    receive: function (data) {
      // This is called by the parent to feed this component data. A function is used instead
      // of a prop to ensure each message gets handled, regardless of how fast they come in
      this.lastReceived = data
    },
  },
}
