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
  <img
    :src="src"
    :alt="itemFullName"
    :width="parameters[4]"
    :height="parameters[5]"
  />
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import Widget from '@cosmosc2/tool-common/src/components/widgets/Widget'
import Cable from '@cosmosc2/tool-common/src/services/cable.js'

export default {
  mixins: [Widget],
  data: function () {
    return {
      api: new CosmosApi(),
      cable: new Cable(),
      subscription: null,
      imageData: '',
    }
  },
  computed: {
    src: function () {
      return `data:image/${this.parameters[3]};base64, ${this.imageData}`
    },
    itemFullName: function () {
      return `TLM__${this.targetName}__${this.packetName}__${this.itemName}__${this.valueType}`
    },
    targetName: function () {
      return this.parameters[0]
    },
    packetName: function () {
      return this.parameters[1]
    },
    itemName: function () {
      return this.parameters[2]
    },
    valueType: function () {
      return 'CONVERTED'
    },
  },
  created: function () {
    this.api
      .get_tlm_packet(this.targetName, this.packetName, this.valueType)
      .then((packetItems) => {
        this.imageData = packetItems.find(
          (item) => item[0] === this.itemName
        )[1]
      })
      .finally(() => {
        this.subscribe()
      })
  },
  destroyed: function () {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.cable.disconnect()
  },
  methods: {
    received: function (json_data) {
      if (json_data['error']) {
        this.$notify.serious({
          body: json_data['error'],
        })
      } else {
        const parsed = JSON.parse(json_data)
        if (parsed.length) {
          const packet = parsed[parsed.length - 1]
          this.imageData = packet[this.itemFullName]
        }
      }
    },
    subscribe: function () {
      this.cable
        .createSubscription('StreamingChannel', localStorage.scope, {
          received: (data) => this.received(data),
          connected: () => {
            this.subscription.perform('add', {
              scope: localStorage.scope,
              mode: 'DECOM',
              token: localStorage.token,
              items: [this.itemFullName],
            })
          },
          disconnected: () => {
            this.$notify.caution({
              body: 'COSMOS backend connection disconnected.',
            })
          },
          rejected: () => {
            this.$notify.caution({
              body: 'COSMOS backend connection rejected.',
            })
          },
        })
        .then((subscription) => {
          this.subscription = subscription
        })
    },
  },
}
</script>
