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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
-->

<template>
  <div>
    <top-bar :menus="menus" :title="title" />
    <v-container>
      <v-row dense>
        <v-col>
          <v-select
            class="ma-0 pa-0"
            label="Select Target(s)"
            :items="targetNames"
            v-model="selectedTargetNames"
            @change="targetSelect"
            multiple
          >
            <template v-slot:prepend-item>
              <v-list-item ripple @mousedown.prevent @click="toggleTargets">
                <v-list-item-action>
                  <v-icon>
                    {{ icon }}
                  </v-icon>
                </v-list-item-action>
                <v-list-item-content>
                  <v-list-item-title> Select All </v-list-item-title>
                </v-list-item-content>
              </v-list-item>
              <v-divider class="mt-2"></v-divider>
            </template>
          </v-select>
        </v-col>
        <v-col>
          <v-btn
            class="primary"
            @click="renderedTargetNames = selectedTargetNames"
          >
            Display
          </v-btn>
        </v-col>
        <v-col>
          <v-select
            label="Item Columns"
            v-model="columns"
            :items="columnItems"
            dense
          ></v-select>
        </v-col>
      </v-row>
    </v-container>
    <div v-for="target in renderedTargetNames" :key="target">
      <target
        :target="target"
        :columns="columns"
        :hideIgnored="hideIgnored"
        :hideDerived="hideDerived"
      ></target>
    </div>
  </div>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'
import Target from './Target'

export default {
  components: {
    TopBar,
    Target,
  },
  data() {
    return {
      title: 'Handbooks',
      targetNames: [],
      selectedTargetNames: [],
      renderedTargetNames: [],
      api: null,
      columns: 3,
      columnItems: [
        { text: '1', value: 12 },
        { text: '2', value: 6 },
        { text: '3', value: 4 },
        { text: '4', value: 3 },
        { text: '6', value: 2 },
        { text: '12', value: 1 },
      ],
      hideIgnored: false,
      hideDerived: false,
      menus: [
        {
          label: 'View',
          items: [
            {
              label: 'Hide Ignored Items',
              checkbox: true,
              command: () => {
                this.hideIgnored = !this.hideIgnored
              },
            },
            {
              label: 'Hide Derived Items',
              checkbox: true,
              command: () => {
                this.hideDerived = !this.hideDerived
              },
            },
          ],
        },
      ],
    }
  },
  computed: {
    allTargetsSelected() {
      return this.targetNames.length === this.selectedTargetNames.length
    },
    someTargetsSelected() {
      return this.selectedTargetNames.length > 0 && !this.allTargetsSelected
    },
    icon() {
      if (this.allTargetsSelected) return 'mdi-close-box'
      if (this.someTargetsSelected) return 'mdi-minus-box'
      return 'mdi-checkbox-blank-outline'
    },
  },
  created() {
    this.api = new CosmosApi()
    this.api
      .get_target_list({ params: { scope: localStorage.scope } })
      .then((targets) => {
        this.targetNames = targets
      })
  },
  methods: {
    toggleTargets() {
      this.$nextTick(() => {
        if (this.allTargetsSelected) {
          this.selectedTargetNames = []
        } else {
          this.selectedTargetNames = this.targetNames.slice()
        }
      })
    },
  },
}
</script>
