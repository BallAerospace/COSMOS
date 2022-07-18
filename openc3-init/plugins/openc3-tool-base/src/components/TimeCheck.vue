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
  <v-dialog v-model="dialog" width="500">
    <v-card>
      <v-card-title> Clock out of sync </v-card-title>
      <v-card-text>
        We've detected that your clock is approximately
        {{ Math.abs(approximateDiscrepancySec) }} seconds
        {{ approximateDiscrepancySec > 0 ? 'behind' : 'ahead of' }} server time.
        This can cause issues and might have unknown side effects.
        <v-checkbox v-model="suppress" label="Don't show this again" />
      </v-card-text>
      <v-divider />
      <v-card-actions>
        <v-btn color="primary" text @click="dismiss"> Dismiss </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script>
// Directly use axios since we need no authentication or scope
import axios from 'axios'

const ALLOWABLE_DISCREPANCY_MS = 3000

export default {
  data: function () {
    return {
      dismissed: false,
      suppress: false,
      discrepancy: 0,
    }
  },
  created: function () {
    this.suppress =
      localStorage['suppresswarning__clock_out_of_sync_with_server'] === 'true'
    if (!this.suppress) {
      axios
        .get('/openc3-api/time')
        .then((response) => {
          this.discrepancy = response.data.now_nsec / 1_000_000 - Date.now()
        })
        .catch((error) => {
          // Silently fail
          this.dismissed = true
        })
    }
  },
  methods: {
    dismiss: function () {
      localStorage['suppresswarning__clock_out_of_sync_with_server'] =
        this.suppress
      this.dismissed = true
    },
  },
  computed: {
    approximateDiscrepancySec: function () {
      return (this.discrepancy / 1000).toFixed()
    },
    dialog: function () {
      return (
        !this.dismissed &&
        Math.abs(this.discrepancy) >= ALLOWABLE_DISCREPANCY_MS
      )
    },
  },
}
</script>
