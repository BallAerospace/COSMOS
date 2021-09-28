<!--
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
-->

<template>
  <v-select
    v-model="scope"
    :items="scopes"
    :disabled="scopes.length <= 1"
    label="Scope"
    dense
    hide-details
  />
</template>

<script>
import Scopes from '../util/scopes.js'

export default {
  mixins: [Scopes],
  data: function () {
    return {
      scopes: [], // gets set in the mixin
      scope: localStorage.scope,
    }
  },
  watch: {
    scope: function (val) {
      localStorage.scope = val
    },
    scopes: function (val) {
      if (val.length === 1 || (!this.scope && val.length)) this.scope = val[0]
    },
  },
}
</script>
