<template>
  <div>
    <app-nav :menus="menus" />
    <v-container>
      <v-row no-gutters>
        <v-col>
          <TargetPacketItemChooser
            :initialTargetName="this.$route.params.target"
            :initialPacketName="this.$route.params.packet"
            @on-set="packetChanged($event)"
          />
        </v-col>
      </v-row>
      <v-row no-gutters>
        <v-col>
          <v-card>
            <v-card-title>
              Items
              <v-spacer></v-spacer>
              <v-text-field
                v-model="search"
                append-icon="mdi-magnify"
                label="Search"
                single-line
                hide-details
              ></v-text-field>
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
                  .map(function(x) {
                  return x.name
                  })
                  .indexOf(item.name)
                  }}
                </span>
              </template>
              <template v-slot:item.value="{ item }">
                <ValueWidget
                  :value="item.value"
                  :limitsState="item.limitsState"
                  :parameters="[targetName, packetName, item.name]"
                  :settings="['WIDTH', '50']"
                ></ValueWidget>
              </template>
            </v-data-table>
          </v-card>
        </v-col>
      </v-row>
    </v-container>

    <v-dialog v-model="optionsDialog" @keydown.esc="optionsDialog = false" max-width="300">
      <v-card class="pa-3">
        <v-card-title class="headline">Options</v-card-title>
        <v-text-field
          min="0"
          max="10000"
          step="100"
          type="number"
          label="Refresh Interval (ms)"
          :value="refreshInterval"
          @change="refreshInterval = $event"
        ></v-text-field>
      </v-card>
    </v-dialog>
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import { CosmosApi } from '@/services/cosmos-api'
import ValueWidget from '@/components/widgets/ValueWidget'
import TargetPacketItemChooser from '@/components/TargetPacketItemChooser'

export default {
  components: {
    AppNav,
    TargetPacketItemChooser,
    ValueWidget
  },
  data() {
    return {
      search: '',
      data: [],
      headers: [
        { text: 'Index', value: 'index' },
        { text: 'Name', value: 'name' },
        { text: 'Value', value: 'value' }
      ],
      optionsDialog: false,
      hideIgnored: false,
      derivedLast: false,
      ignoredItems: [],
      derivedItems: [],
      menus: [
        {
          label: 'File',
          items: [
            {
              label: 'Options',
              command: () => {
                this.optionsDialog = true
              }
            }
          ]
        },
        {
          label: 'View',
          radioGroup: 'Formatted Items with Units', // Default radio selected
          items: [
            {
              label: 'Hide Ignored Items',
              checkbox: true,
              command: () => {
                this.hideIgnored = !this.hideIgnored
              }
            },
            {
              label: 'Display Derived Last',
              checkbox: true,
              command: () => {
                this.derivedLast = !this.derivedLast
              }
            },
            {
              divider: true
            },
            {
              label: 'Formatted Items with Units',
              radio: true,
              command: () => {
                this.valueType = 'WITH_UNITS'
              }
            },
            {
              label: 'Formatted Items',
              radio: true,
              command: () => {
                this.valueType = 'FORMATTED'
              }
            },
            {
              label: 'Converted Items',
              radio: true,
              command: () => {
                this.valueType = 'CONVERTED'
              }
            },
            {
              label: 'Raw Items',
              radio: true,
              command: () => {
                this.valueType = 'RAW'
              }
            }
          ]
        }
      ],
      updater: null,
      targetName: '',
      packetName: '',
      valueType: 'WITH_UNITS',
      refreshInterval: 1000,
      rows: [],
      menuItems: [],
      api: null
    }
  },
  watch: {
    // Create a watcher on refreshInterval so we can change the updater
    refreshInterval: function(newValue, oldValue) {
      this.changeUpdater(false)
    }
  },
  methods: {
    packetChanged(event) {
      if (
        this.targetName === event.targetName &&
        this.packetName === event.packetName
      ) {
        return
      }
      this.api.get_target_ignored_items(event.targetName).then(ignored => {
        this.ignoredItems = ignored
      })
      this.api
        .get_packet_derived_items(event.targetName, event.packetName)
        .then(derived => {
          this.derivedItems = derived
        })

      this.targetName = event.targetName
      this.packetName = event.packetName
      if (
        this.$route.params.target !== event.targetName ||
        this.$route.params.packet !== event.packetName
      ) {
        this.$router.push({
          name: 'PackerViewer',
          params: {
            target: this.targetName,
            packet: this.packetName
          }
        })
      }
      this.changeUpdater(true)
    },

    changeUpdater(clearExisting) {
      if (this.updater != null) {
        clearInterval(this.updater)
        this.updater = null
      }

      if (clearExisting) {
        this.rows = []
      }

      this.updater = setInterval(() => {
        this.api
          .get_tlm_packet(this.targetName, this.packetName, this.valueType)
          .then(data => {
            let derived = []
            let other = []
            data.forEach(value => {
              if (this.hideIgnored && this.ignoredItems.includes(value[0])) {
                return
              }
              if (this.derivedItems.includes(value[0])) {
                derived.push({
                  name: value[0],
                  value: value[1],
                  limitsState: value[2]
                })
              } else {
                other.push({
                  name: value[0],
                  value: value[1],
                  limitsState: value[2]
                })
              }
            })
            if (this.derivedLast) {
              this.rows = other.concat(derived)
            } else {
              this.rows = derived.concat(other)
            }
          })
      }, this.refreshInterval)
    }
  },
  created() {
    this.api = new CosmosApi()
  },
  // TODO: This doesn't seem to be called / covered when running cypress tests?
  beforeDestroy() {
    if (this.updater != null) {
      clearInterval(this.updater)
      this.updater = null
    }
  }
}
</script>

<style scoped>
.container {
  background-color: var(--v-tertiary-darken2);
}
</style>
