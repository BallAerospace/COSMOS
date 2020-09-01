<template>
  <v-select
    hide-details
    dense
    :items="items"
    v-model="value"
    :style="computedStyle"
  >
  </v-select>
</template>

<script>
import Widget from './Widget'

export default {
  mixins: [Widget],
  data() {
    return {
      items: [],
      value: null
    }
  },
  created() {
    // Look through the settings and see if we're a NAMED_WIDGET
    this.settings.forEach(setting => {
      if (setting[0] === 'NAMED_WIDGET') {
        setting[2].setNamedWidget(setting[1], this)
      }
    })
    this.items = this.parameters
  },
  methods: {
    text() {
      return this.value
    }
  }
}
</script>

<style lang="scss" scoped></style>
