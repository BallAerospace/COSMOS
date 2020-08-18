<template>
  <v-row justify="center">
    <v-dialog v-model="show" width="550">
      <v-card>
        <v-card-title
          >{{ targetName }} {{ packetName }} {{ itemName }}</v-card-title
        >
        <v-card-subtitle>{{ details.description }}</v-card-subtitle>
        <v-card-text>
          <v-container fluid>
            <v-row no-gutters v-if="type === 'tlm'">
              <v-col cols="3">Item Values</v-col>
              <v-col />
              <v-container fluid class="ml-5 pa-0">
                <v-row no-gutters>
                  <v-col cols="4">Raw Value</v-col>
                  <v-col>{{ rawValue }}</v-col>
                </v-row>
                <v-row no-gutters>
                  <v-col cols="4">Converted Value</v-col>
                  <v-col>{{ convertedValue }}</v-col>
                </v-row>
                <v-row no-gutters>
                  <v-col cols="4">Formatted Value</v-col>
                  <v-col>{{ formattedValue }}</v-col>
                </v-row>
                <v-row no-gutters>
                  <v-col cols="4">With Units Value</v-col>
                  <v-col>{{ unitsValue }}</v-col>
                </v-row>
              </v-container>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3" class="font-weight-black">Bit Offset</v-col>
              <v-col>{{ details.bit_offset }}</v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3" class="font-weight-bold">Bit Size</v-col>
              <v-col>{{ details.bit_size }}</v-col>
            </v-row>
            <v-row v-if="details.array_size" no-gutters>
              <v-col cols="3" class="font-weight-medium">Array Size</v-col>
              <v-col>{{ details.array_size }}</v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3" class="font-weight-medium">Data Type</v-col>
              <v-col>{{ details.data_type }}</v-col>
            </v-row>
            <v-row no-gutters v-if="type === 'cmd'">
              <v-col cols="3">Minimum</v-col>
              <v-col>{{ details.minimum }}</v-col>
            </v-row>
            <v-row no-gutters v-if="type === 'cmd'">
              <v-col cols="3">Maximum</v-col>
              <v-col>{{ details.maximum }}</v-col>
            </v-row>
            <v-row no-gutters v-if="type === 'cmd'">
              <v-col cols="3">Default</v-col>
              <v-col>{{ details.default }}</v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3">Format String</v-col>
              <v-col>{{ details.format_string }}</v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3">Read Conversion</v-col>
              <v-col v-if="details.read_conversion">
                Class: {{ details.read_conversion.class }}
                <br />
                Params:
                {{ details.read_conversion.params }}
              </v-col>
              <v-col v-else></v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3">Write Conversion</v-col>
              <v-col v-if="details.write_conversion">
                Class: {{ details.write_conversion.class }}
                <br />
                Params:
                {{ details.write_conversion.params }}
              </v-col>
              <v-col v-else></v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3">Id Value</v-col>
              <v-col>{{ details.id_value }}</v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3">Units Full</v-col>
              <v-col>{{ details.units_full }}</v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3">Units Abbr</v-col>
              <v-col>{{ details.units }}</v-col>
            </v-row>
            <v-row no-gutters>
              <v-col cols="3">Endianness</v-col>
              <v-col>{{ details.endianness }}</v-col>
            </v-row>
            <v-row no-gutters v-if="details.states">
              <v-col cols="3">States</v-col>
              <v-col />
              <v-container fluid class="ml-5 pa-0">
                <v-row
                  no-gutters
                  v-for="(state, key) in details.states"
                  :key="key"
                >
                  <v-col cols="4">{{ key }}</v-col>
                  <v-col>{{ state.value }}</v-col>
                </v-row>
              </v-container>
            </v-row>
            <v-row no-gutters v-else>
              <v-col cols="3">States</v-col>
              <v-col>None</v-col>
            </v-row>
            <v-row no-gutters v-if="details.limits">
              <v-col cols="3">Limits</v-col>
              <v-col></v-col>
              <v-container fluid class="ml-5 pa-0">
                <v-row
                  no-gutters
                  v-for="(limit, key) in details.limits"
                  :key="key"
                >
                  <v-col cols="4">{{ key }}</v-col>
                  {{ formatLimit(limit) }}
                  <v-col></v-col>
                </v-row>
              </v-container>
            </v-row>
            <v-row no-gutters v-else>
              <v-col cols="3">Limits</v-col>
              <v-col>None</v-col>
            </v-row>
            <v-row no-gutters v-if="details.meta">
              <v-col cols="3">Meta</v-col>
              <v-col></v-col>
              <v-container fluid class="ml-5 pa-0">
                <v-row
                  no-gutters
                  v-for="(value, key) in details.meta"
                  :key="key"
                >
                  <v-col cols="4">{{ key }}</v-col>
                  <v-col>{{ value }}</v-col>
                </v-row>
              </v-container>
            </v-row>
            <v-row v-else no-gutters>
              <v-col cols="3">Meta</v-col>
              <v-col>None</v-col>
            </v-row>
          </v-container>
        </v-card-text>
      </v-card>
    </v-dialog>
  </v-row>
</template>

<script>
import { CosmosApi } from '@/services/cosmos-api.js'

export default {
  props: {
    type: {
      default: 'tlm',
      validator: function(value) {
        // The value must match one of these strings
        return ['cmd', 'tlm'].indexOf(value) !== -1
      }
    },
    targetName: String,
    packetName: String,
    itemName: String,
    value: Boolean // value is the default prop when using v-model
  },
  data() {
    return {
      details: Object,
      updater: null,
      rawValue: null,
      convertedValue: null,
      formattedValue: null,
      unitsValue: null
    }
  },
  computed: {
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      }
    }
  },
  created() {
    this.api = new CosmosApi()
  },
  beforeDestroy() {
    clearInterval(this.updater)
    this.updater = null
  },
  watch: {
    // Create a watcher on value which is the indicator to display the dialog
    // If value is true we request the details from the server
    // If this is a tlm dialog we setup an interval to get the telemetry values
    value: function(newValue, oldValue) {
      if (newValue) {
        this.requestDetails()
        if (this.type === 'tlm') {
          this.updater = setInterval(() => {
            this.api
              .get_tlm_values(
                [
                  [this.targetName, this.packetName, this.itemName],
                  [this.targetName, this.packetName, this.itemName],
                  [this.targetName, this.packetName, this.itemName],
                  [this.targetName, this.packetName, this.itemName]
                ],
                ['RAW', 'CONVERTED', 'FORMATTED', 'WITH_UNITS']
              )
              .then(values => {
                this.rawValue = values[0][0]
                this.convertedValue = values[0][1]
                this.formattedValue = values[0][2]
                this.unitsValue = values[0][3]
              })
          }, 1000)
        }
      } else {
        clearInterval(this.updater)
        this.updater = null
      }
    }
  },
  methods: {
    requestDetails() {
      if (this.type === 'tlm') {
        this.api
          .get_item(this.targetName, this.packetName, this.itemName)
          .then(details => {
            this.details = details
          })
      } else {
        this.api
          .get_parameter(this.targetName, this.packetName, this.itemName)
          .then(details => {
            this.details = details
          })
      }
    },
    formatLimit(limit) {
      if (limit.green_low) {
        return (
          'RL/' +
          limit.red_low +
          ' YL/' +
          limit.yellow_low +
          ' YH/' +
          limit.yellow_high +
          ' RH/' +
          limit.red_high +
          ' GL/' +
          limit.green_low +
          ' GH/' +
          limit.green_high
        )
      } else if (limit.red_low) {
        return (
          'RL/' +
          limit.red_low +
          ' YL/' +
          limit.yellow_low +
          ' YH/' +
          limit.yellow_high +
          ' RH/' +
          limit.red_high
        )
      } else {
        return limit
      }
    }
  }
}
</script>

<style scoped>
.v-card,
.v-card__title {
  background-color: var(--v-secondary-darken3);
}
</style>
