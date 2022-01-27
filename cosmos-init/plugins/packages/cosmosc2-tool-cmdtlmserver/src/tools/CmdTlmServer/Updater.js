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

import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'

export default {
  props: {
    refreshInterval: {
      default: 1000,
    },
  },
  data() {
    return {
      updater: null,
      api: null,
    }
  },
  created() {
    this.api = new CosmosApi()
  },
  mounted() {
    this.changeUpdater()
  },
  beforeDestroy() {
    if (this.updater != null) {
      clearInterval(this.updater)
      this.updater = null
    }
  },
  watch: {
    // eslint-disable-next-line no-unused-vars
    refreshInterval: function (newVal, oldVal) {
      this.changeUpdater()
    },
  },
  methods: {
    changeUpdater() {
      if (this.updater != null) {
        clearInterval(this.updater)
        this.updater = null
      }
      this.updater = setInterval(() => {
        this.update()
      }, this.refreshInterval)
    },
  },
}
