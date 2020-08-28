<template>
  <v-row justify="center">
    <v-dialog v-model="show" @keydown.esc="show = false" width="300">
      <v-card>
        <v-card-title>Save Configuration</v-card-title>
        <v-card-text>
          <v-text-field
            hide-details
            label="Name"
            v-model="configName"
          ></v-text-field>
          <v-alert dense type="warning" v-if="warning">
            '{{ configName }}'' already exists! Click "OK" to overwrite.
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-btn color="primary" text @click="success()">OK</v-btn>
          <v-spacer></v-spacer>
          <v-btn color="primary" text @click="show = false">Cancel</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-row>
</template>

<script>
import { CosmosApi } from '@/services/cosmos-api'

export default {
  props: {
    tool: String,
    value: Boolean // value is the default prop when using v-model
  },
  data() {
    return {
      api: null,
      configName: '',
      warning: false
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
  methods: {
    async success() {
      let config = await this.api.load_config(this.tool, this.configName)
      if (config !== null && this.warning === false) {
        this.warning = true
        return
      }
      this.warning = false
      this.show = false
      this.$emit('success', this.configName)
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
