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
  <div>
    <v-container>
      <v-row no-gutters>
        <v-text-field
          width="200"
          dense
          outlined
          readonly
          label="Overall Limits State"
          :value="overallStateFormatted"
          :class="textFieldClass"
          data-test="overall-state"
        />
      </v-row>

      <div v-for="(item, index) in items" :key="item.key">
        <v-row data-test="limits-row" class="my-0">
          <v-col class="py-1">
            <labelvaluelimitsbar-widget
              v-if="item.limits"
              :parameters="item.parameters"
              :settings="[
                ['0', 'WIDTH', '150'],
                ['1', 'WIDTH', '200'],
                ['2', 'WIDTH', '200'],
              ]"
            />
            <labelvalue-widget
              v-else
              :parameters="item.parameters"
              :settings="[
                ['0', 'WIDTH', '150'],
                ['1', 'WIDTH', '200'],
              ]"
            />
          </v-col>
          <v-col cols="2" class="py-1">
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-btn
                  icon
                  class="mr-2"
                  @click="ignorePacket(item.key)"
                  v-bind="attrs"
                  v-on="on"
                >
                  <v-icon> mdi-close-circle-multiple </v-icon>
                </v-btn>
              </template>
              <span>Ignore Entire Packet</span>
            </v-tooltip>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-btn
                  icon
                  class="mr-2"
                  @click="ignoreItem(item.key)"
                  v-bind="attrs"
                  v-on="on"
                >
                  <v-icon> mdi-close-circle </v-icon>
                </v-btn>
              </template>
              <span>Ignore Item</span>
            </v-tooltip>
            <v-tooltip bottom>
              <template v-slot:activator="{ on, attrs }">
                <v-btn
                  icon
                  class="mr-2"
                  @click="removeItem(item.key)"
                  v-bind="attrs"
                  v-on="on"
                >
                  <v-icon> mdi-eye-off </v-icon>
                </v-btn>
              </template>
              <span>Temporarily Hide Item</span>
            </v-tooltip>
          </v-col>
        </v-row>
        <v-divider v-if="index < items.length - 1" :key="index" />
      </div>
    </v-container>
    <v-dialog v-model="ignoredItemsDialog" max-width="600">
      <v-card>
        <v-system-bar>
          <v-spacer />
          <span>Ignored Items</span>
          <v-spacer />
        </v-system-bar>
        <v-card-text>
          <div class="my-2">
            <div v-for="(item, index) in ignoredFormatted" :key="index">
              <v-row class="ma-1">
                <span class="font-weight-black"> {{ item }} </span>
                <v-spacer />
                <v-btn small icon @click="restoreItem(item, index)">
                  <v-icon> mdi-delete </v-icon>
                </v-btn>
              </v-row>
              <v-divider
                v-if="index < ignoredFormatted.length - 1"
                :key="index"
              />
            </div>
            <v-row class="mt-2">
              <v-spacer />
              <v-btn
                @click="ignoredItemsDialog = false"
                class="mx-2"
                color="primary"
              >
                Ok
              </v-btn>
            </v-row>
            <v-divider v-if="index < items.length - 1" :key="index" />
          </div>
        </v-card-text>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import LabelvalueWidget from '@cosmosc2/tool-common/src/components/widgets/LabelvalueWidget'
import LabelvaluelimitsbarWidget from '@cosmosc2/tool-common/src/components/widgets/LabelvaluelimitsbarWidget'

export default {
  components: {
    LabelvalueWidget,
    LabelvaluelimitsbarWidget,
  },
  data() {
    return {
      api: null,
      ignored: [],
      ignoredItemsDialog: false,
      overallState: 'GREEN',
      items: [],
      itemList: [],
    }
  },
  computed: {
    textFieldClass() {
      if (this.overallState) {
        return `textfield-${this.overallState.toLowerCase()}`
      } else {
        return ''
      }
    },
    overallStateFormatted() {
      if (this.ignored.length === 0) {
        return this.overallState
      } else {
        return `${this.overallState} (Some items ignored)`
      }
    },
    ignoredFormatted() {
      return this.ignored.map((x) => x.split('__').join(' '))
    },
  },
  created() {
    this.api = new CosmosApi()
    this.updateOutOfLimits()
  },
  mounted() {
    this.updater = setInterval(() => {
      this.update()
    }, 1000)
  },
  destroyed() {
    if (this.updater != null) {
      clearInterval(this.updater)
      this.updater = null
    }
  },
  methods: {
    updateOutOfLimits() {
      this.api.get_out_of_limits().then((items) => {
        for (const item of items) {
          let itemName = item.join('__')
          // Skip ignored and existing items
          if (
            this.itemList.includes(itemName) ||
            this.ignored.find((ignored) => itemName.includes(ignored))
          ) {
            continue
          }

          this.itemList.push(itemName)
          let itemInfo = {
            key: item.slice(0, 3).join('__'),
            parameters: item.slice(0, 3),
          }
          if (item[3].includes('YELLOW') && this.overallState !== 'RED') {
            this.overallState = 'YELLOW'
          }
          if (item[3].includes('RED')) {
            this.overallState = 'RED'
          }
          if (item[3] == 'YELLOW' || item[3] == 'RED') {
            itemInfo['limits'] = false
          } else {
            itemInfo['limits'] = true
          }
          this.items.push(itemInfo)
        }
        this.calcOverallState()
      })
    },
    calcOverallState() {
      let overall = 'GREEN'
      for (let item of this.itemList) {
        if (this.ignored.find((ignored) => item.includes(ignored))) {
          continue
        }

        if (item.includes('YELLOW') && overall !== 'RED') {
          overall = 'YELLOW'
        }
        if (item.includes('RED')) {
          overall = 'RED'
          break
        }
      }
      this.overallState = overall
    },
    ignorePacket(item) {
      let [target_name, packet_name, item_name] = item.split('__')
      let newIgnored = `${target_name}__${packet_name}`
      this.ignored.push(newIgnored)

      while (true) {
        let index = this.itemList.findIndex((item) => item.includes(newIgnored))
        if (index === -1) {
          break
        } else {
          let underIndex = this.itemList[index].lastIndexOf('__')
          this.removeItem(this.itemList[index].substring(0, underIndex))
        }
      }
      this.calcOverallState()
    },
    ignoreItem(item) {
      this.ignored.push(item)
      this.removeItem(item)
      this.calcOverallState()
    },
    restoreItem(item, index) {
      this.ignored.splice(index, 1)
      this.updateOutOfLimits()
    },
    removeItem(item) {
      const index = this.itemList.findIndex((arrayItem) =>
        arrayItem.includes(item)
      )
      this.items.splice(index, 1)
      this.itemList.splice(index, 1)
    },
    update() {
      if (this.$store.state.tlmViewerItems.length !== 0) {
        this.api
          .get_tlm_values(this.$store.state.tlmViewerItems)
          .then((data) => {
            this.$store.commit('tlmViewerUpdateValues', data)
          })
      }
    },
    handleMessages(messages) {
      for (let message of messages) {
        let itemName =
          message.target_name +
          '__' +
          message.packet_name +
          '__' +
          message.item_name
        const index = this.itemList.findIndex((arrayItem) =>
          arrayItem.includes(itemName)
        )
        // If we find an existing item we update the state and re-calc overall state
        if (index !== -1) {
          this.itemList[index] = `${itemName}__${message.new_limits_state}`
          this.calcOverallState()
          continue
        }
        // Skip ignored items
        if (this.ignored.find((ignored) => itemName.includes(ignored))) {
          continue
        }
        // Only process items who have gone out of limits
        if (
          !(
            message.new_limits_state.includes('YELLOW') ||
            message.new_limits_state.includes('RED')
          )
        ) {
          continue
        }
        let itemInfo = {
          key: itemName,
          parameters: [
            message.target_name,
            message.packet_name,
            message.item_name,
          ],
        }
        if (
          message.new_limits_state == 'YELLOW' ||
          message.new_limits_state == 'RED'
        ) {
          itemInfo['limits'] = false
        } else {
          itemInfo['limits'] = true
        }
        this.itemList.push(`${itemName}__${message.new_limits_state}`)
        this.items.push(itemInfo)
        this.calcOverallState()
      }
    },

    // Menu options
    showIgnored() {
      this.ignoredItemsDialog = true
    },
  },
}
</script>

<style scoped>
/* TODO: Color the border */
.textfield-green >>> .v-text-field__slot input,
.textfield-green >>> .v-text-field__slot label {
  color: green;
}
.textfield-yellow >>> .v-text-field__slot input,
.textfield-yellow >>> .v-text-field__slot label {
  color: yellow;
}
.textfield-red >>> .v-text-field__slot input,
.textfield-red >>> .v-text-field__slot label {
  color: red;
}
</style>
