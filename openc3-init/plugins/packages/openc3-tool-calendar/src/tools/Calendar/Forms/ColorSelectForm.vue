<!--
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
-->

<template>
  <div>
    <v-select v-model="color" :items="swatches" label="Color">
      <template v-slot:selection="{ item }">
        <div>
          <v-badge inline :color="item">
            <span v-text="item" />
          </v-badge>
        </div>
      </template>
      <template v-slot:item="{ item }">
        <div>
          <v-badge inline :color="item">
            <span v-text="item" />
          </v-badge>
        </div>
      </template>
    </v-select>
  </div>
</template>

<script>
export default {
  components: {},
  props: {
    value: {
      type: String,
      required: true,
    },
  },
  data() {
    return {}
  },
  computed: {
    color: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
    swatches: function () {
      return [
        '#005a8f',
        '#003784',
        '#8F3400',
        '#df1368',
        '#ff5252',
        '#df323b',
        '#9f0010',
        '#2d9437',
        '#004700',
        '#db7200',
        '#802700',
        '#0f2941',
      ]
    },
  },
  methods: {},
}
</script>
