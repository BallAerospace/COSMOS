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
    <top-bar :menus="menus" :title="title" />
    <v-file-input
      show-size
      v-model="file"
      ref="fileInput"
      accept=".bin"
      data-test="file"
      style="position: fixed; top: -100%"
    />
    <v-text-field
      outlined
      dense
      readonly
      hide-details
      label="Filename"
      v-model="filename"
      id="filename"
      data-test="filename"
      @click="fileOpen"
    />
    <v-card>
      <v-card-title>
        Items
        <v-spacer />
        <v-text-field
          v-model="search"
          append-icon="$astro-search"
          label="Search"
          single-line
          hide-details
        />
      </v-card-title>
      <v-data-table
        :headers="headers"
        :items="rows"
        :search="search"
        calculate-widths
        disable-pagination
        hide-default-footer
        multi-sort
        dense
      >
        <template v-slot:item.index="{ item }">
          <span>
            {{
              rows
                .map(function (x) {
                  return x.name
                })
                .indexOf(item.name)
            }}
          </span>
        </template>
        <template v-slot:item.value="{ item }">
          <value-widget
            :value="item.value"
            :limits-state="item.limitsState"
            :parameters="[targetName, packetName, item.name]"
            :settings="['WIDTH', '50']"
          />
        </template>
      </v-data-table>
    </v-card>
  </div>
</template>

<script>
import { CosmosApi } from '@cosmosc2/tool-common/src/services/cosmos-api'
import ValueWidget from '@cosmosc2/tool-common/src/components/widgets/ValueWidget'
import TopBar from '@cosmosc2/tool-common/src/components/TopBar'

export default {
  components: {
    ValueWidget,
    TopBar,
  },
  data() {
    return {
      title: 'Table Manager',
      search: '',
      data: [],
      headers: [
        { text: 'Index', value: 'index' },
        { text: 'Name', value: 'name' },
        { text: 'Value', value: 'value' },
      ],
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Open',
              icon: 'mdi-cloud-upload',
              command: () => {
                this.fileOpen()
              },
            },
          ],
        },
      ],
      api: null,
      file: '',
      filename: null,
    }
  },
  created() {
    this.api = new CosmosApi()
  },

  methods: {
    async fileOpen() {
      this.file = ''
      this.$refs.fileInput.$refs.input.click()
      // Wait for the file to be set by the dialog so upload works
      while (this.file === '') {
        await new Promise((resolve) => setTimeout(resolve, 500))
      }
      this.upload()
    },
    async upload() {
      // console.log(this.file)
      this.filename = this.file.name

      const formData = new FormData()
      formData.append('table', this.file, this.file.name)
      Api.post('/cosmos-api/tables/upload', { data: formData }).then(
        (response) => {
          // console.log(response)
        }
      )
    },
  },
}
</script>
